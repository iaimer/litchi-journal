import { ZipArchive } from 'archiver';
import { once } from 'events';
import {
  chmodSync,
  constants,
  createReadStream,
  createWriteStream,
  existsSync,
  lstatSync,
  mkdirSync,
  readdirSync,
  realpathSync,
  unlinkSync,
} from 'fs';
import { open } from 'fs/promises';
import { createHash, randomUUID } from 'crypto';
import { join, relative, sep } from 'path';
import { tmpdir } from 'os';
import { Readable } from 'stream';
import * as unzipper from 'unzipper';

export interface BackupManifestFile {
  path: string;
  sizeBytes: number;
  sha256: string;
}

export interface BackupManifest {
  schemaVersion: 1;
  createdAt: string;
  source: '01.日记';
  files: BackupManifestFile[];
}

export interface CreatedBackupArchive {
  path: string;
  fileName: string;
  sizeBytes: number;
  sha256: string;
  manifest: BackupManifest;
}

export class BackupSourceChangedError extends Error {
  constructor() {
    super('备份源文件在打包期间发生变化');
    this.name = 'BackupSourceChangedError';
  }
}

export class BackupSourceUnavailableError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'BackupSourceUnavailableError';
  }
}

interface SourceFile {
  fullPath: string;
  sourceRoot: string;
  archivePath: string;
  sizeBytes: number;
  mtimeMs: number;
  sha256: string;
}

interface SourceSignature {
  archivePath: string;
  sizeBytes: number;
  mtimeMs: number;
}

export async function createBackupArchive(
  vaultPath: string,
  now = new Date(),
  tempRoot = tmpdir(),
): Promise<CreatedBackupArchive> {
  const tempDirectory = ensurePrivateTempDirectory(tempRoot);
  const fileName = `litchi-journal-diary-${formatShanghaiTimestamp(now)}.zip`;

  for (let attempt = 0; attempt < 2; attempt += 1) {
    const tempPath = join(
      tempDirectory,
      `.litchi-journal-${randomUUID()}.zip.partial`,
    );
    try {
      const manifest = await buildArchiveAttempt(vaultPath, tempPath, now);
      const stats = lstatSync(tempPath);
      return {
        path: tempPath,
        fileName,
        sizeBytes: stats.size,
        sha256: await hashFile(tempPath),
        manifest,
      };
    } catch (error) {
      removeFile(tempPath);
      if (error instanceof BackupSourceChangedError && attempt === 0) {
        continue;
      }
      throw error;
    }
  }

  throw new Error('无法创建备份');
}

export function removeBackupArchive(path: string): void {
  try {
    unlinkSync(path);
  } catch (error) {
    if (isMissingFileError(error)) return;
    throw new Error('备份临时文件清理失败');
  }
}

export function cleanupStaleBackupArchives(tempRoot = tmpdir()): number {
  const tempDirectory = ensurePrivateTempDirectory(tempRoot);
  let removed = 0;
  for (const entry of readdirSync(tempDirectory, { withFileTypes: true })) {
    if (!entry.isFile() || !/^\.litchi-journal-[\w-]+\.zip\.partial$/.test(entry.name)) {
      continue;
    }
    removeBackupArchive(join(tempDirectory, entry.name));
    removed += 1;
  }
  return removed;
}

async function buildArchiveAttempt(
  vaultPath: string,
  tempPath: string,
  now: Date,
): Promise<BackupManifest> {
  const diaryRoot = join(vaultPath, '01.日记');
  const files = await collectSourceFiles(diaryRoot);
  const manifest: BackupManifest = {
    schemaVersion: 1,
    createdAt: now.toISOString(),
    source: '01.日记',
    files: files.map(file => ({
      path: file.archivePath,
      sizeBytes: file.sizeBytes,
      sha256: file.sha256,
    })),
  };

  await writeZip(tempPath, files, manifest);
  const currentSignatures = collectSourceSignatures(diaryRoot);
  if (!sameSignatures(files, currentSignatures)) {
    throw new BackupSourceChangedError();
  }
  await validateBackupArchive(tempPath, manifest);
  return manifest;
}

async function collectSourceFiles(diaryRoot: string): Promise<SourceFile[]> {
  assertDiaryRoot(diaryRoot);
  const sourceRoot = realpathSync(diaryRoot);
  const signatures = collectSourceSignatures(diaryRoot);
  const files: SourceFile[] = [];
  for (const signature of signatures) {
    const relativePath = signature.archivePath.slice('01.日记/'.length);
    const fullPath = join(diaryRoot, ...relativePath.split('/'));
    files.push({
      fullPath,
      sourceRoot,
      archivePath: signature.archivePath,
      sizeBytes: signature.sizeBytes,
      mtimeMs: signature.mtimeMs,
      sha256: await hashSourceFile(fullPath, sourceRoot),
    });
  }
  return files;
}

function collectSourceSignatures(diaryRoot: string): SourceSignature[] {
  const files: SourceSignature[] = [];
  assertDiaryRoot(diaryRoot);
  const sourceRoot = realpathSync(diaryRoot);
  walkDirectory(diaryRoot, sourceRoot, filePath => {
    const stats = lstatSync(filePath);
    const relativePath = relative(diaryRoot, filePath).split(sep).join('/');
    files.push({
      archivePath: `01.日记/${relativePath}`,
      sizeBytes: stats.size,
      mtimeMs: stats.mtimeMs,
    });
  });
  files.sort((a, b) => a.archivePath.localeCompare(b.archivePath));
  return files;
}

function walkDirectory(
  directory: string,
  sourceRoot: string,
  onFile: (path: string) => void,
): void {
  if (!existsSync(directory)) throw new BackupSourceChangedError();
  const entries = readdirSync(directory, { withFileTypes: true });
  for (const entry of entries) {
    if (entry.name === '.DS_Store') continue;
    const path = join(directory, entry.name);
    const stats = lstatSync(path);
    if (stats.isSymbolicLink()) continue;
    assertPathInsideRoot(sourceRoot, path);
    if (stats.isDirectory()) {
      walkDirectory(path, sourceRoot, onFile);
      continue;
    }
    if (stats.isFile()) onFile(path);
  }
}

function sameSignatures(
  expected: SourceFile[],
  actual: SourceSignature[],
): boolean {
  if (expected.length !== actual.length) return false;
  return expected.every((file, index) => {
    const current = actual[index];
    return (
      current?.archivePath === file.archivePath &&
      current.sizeBytes === file.sizeBytes &&
      current.mtimeMs === file.mtimeMs
    );
  });
}

async function writeZip(
  tempPath: string,
  files: SourceFile[],
  manifest: BackupManifest,
): Promise<void> {
  const archive = new ZipArchive({
    forceZip64: true,
    zlib: { level: 6 },
  });
  const output = createWriteStream(tempPath, { flags: 'wx', mode: 0o600 });
  const error = new Promise<never>((_, reject) => {
    archive.once('error', reject);
    output.once('error', reject);
  });
  const outputClosed = once(output, 'close');

  archive.pipe(output);
  archive.append(JSON.stringify(manifest, null, 2), {
    name: 'backup-manifest.json',
  });
  // 即使当前没有日记文件，也保留明确的顶层目录，便于解压后直接得到原有结构。
  archive.append('', { name: '01.日记/' });
  for (const file of files) {
    archive.append(Readable.from(readVerifiedSourceFile(file)), {
      name: file.archivePath,
      date: new Date(file.mtimeMs),
    });
  }

  const finalized = archive.finalize();
  await Promise.race([Promise.all([finalized, outputClosed]), error]);
}

export async function validateBackupArchive(
  path: string,
  expectedManifest: BackupManifest,
): Promise<void> {
  const directory = await unzipper.Open.file(path);
  const entries = directory.files.filter(file => file.type === 'File');
  const manifestEntry = entries.find(file => file.path === 'backup-manifest.json');
  if (!manifestEntry) throw new Error('ZIP 缺少备份清单');

  const manifestBuffer = await manifestEntry.buffer();
  if (crc32(manifestBuffer) !== (manifestEntry.crc32 >>> 0)) {
    throw new Error('ZIP 备份清单完整性校验失败');
  }
  const parsed = JSON.parse(manifestBuffer.toString('utf-8')) as BackupManifest;
  if (!sameManifest(parsed, expectedManifest)) {
    throw new Error('ZIP 备份清单内容无效');
  }

  const expected = new Map(parsed.files.map(file => [file.path, file]));
  const actualEntries = entries.filter(file => file.path !== 'backup-manifest.json');
  const actual = new Map(actualEntries.map(file => [file.path, file]));
  if (expected.size !== actual.size || actual.size !== actualEntries.length) {
    throw new Error('ZIP 文件清单不完整');
  }

  for (const [pathName, file] of expected) {
    const entry = actual.get(pathName);
    if (!entry || entry.uncompressedSize !== file.sizeBytes) {
      throw new Error('ZIP 文件大小校验失败');
    }
    const hash = createHash('sha256');
    let bytes = 0;
    let crc = 0xffffffff;
    for await (const chunk of entry.stream()) {
      const buffer = Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk);
      bytes += buffer.length;
      hash.update(buffer);
      crc = updateCrc32(crc, buffer);
    }
    const actualCrc = (crc ^ 0xffffffff) >>> 0;
    if (
      bytes !== file.sizeBytes ||
      hash.digest('hex') !== file.sha256 ||
      actualCrc !== (entry.crc32 >>> 0)
    ) {
      throw new Error('ZIP 文件完整性校验失败');
    }
  }
}

const CRC32_TABLE = Array.from({ length: 256 }, (_, index) => {
  let value = index;
  for (let bit = 0; bit < 8; bit += 1) {
    value = (value & 1) === 1 ? 0xedb88320 ^ (value >>> 1) : value >>> 1;
  }
  return value >>> 0;
});

function updateCrc32(current: number, buffer: Buffer): number {
  let value = current >>> 0;
  for (const byte of buffer) {
    value = CRC32_TABLE[(value ^ byte) & 0xff] ^ (value >>> 8);
  }
  return value >>> 0;
}

function crc32(buffer: Buffer): number {
  return (updateCrc32(0xffffffff, buffer) ^ 0xffffffff) >>> 0;
}

function sameManifest(actual: BackupManifest, expected: BackupManifest): boolean {
  if (
    actual.schemaVersion !== expected.schemaVersion ||
    actual.createdAt !== expected.createdAt ||
    actual.source !== expected.source ||
    !Array.isArray(actual.files) ||
    actual.files.length !== expected.files.length
  ) {
    return false;
  }
  return actual.files.every((file, index) => {
    const expectedFile = expected.files[index];
    return (
      file?.path === expectedFile?.path &&
      file.sizeBytes === expectedFile.sizeBytes &&
      file.sha256 === expectedFile.sha256
    );
  });
}

async function* readVerifiedSourceFile(file: SourceFile): AsyncGenerator<Buffer> {
  assertPathInsideRoot(file.sourceRoot, file.fullPath);
  const handle = await open(
    file.fullPath,
    constants.O_RDONLY | (constants.O_NOFOLLOW ?? 0),
  );
  try {
    const stats = await handle.stat();
    if (
      !stats.isFile() ||
      stats.size !== file.sizeBytes ||
      stats.mtimeMs !== file.mtimeMs
    ) {
      throw new BackupSourceChangedError();
    }
    for await (const chunk of handle.createReadStream({ autoClose: false })) {
      yield Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk);
    }
  } finally {
    await handle.close();
  }
}

async function hashSourceFile(path: string, sourceRoot: string): Promise<string> {
  assertPathInsideRoot(sourceRoot, path);
  const handle = await open(path, constants.O_RDONLY | (constants.O_NOFOLLOW ?? 0));
  const hash = createHash('sha256');
  try {
    const stats = await handle.stat();
    if (!stats.isFile()) throw new BackupSourceChangedError();
    for await (const chunk of handle.createReadStream({ autoClose: false })) {
      hash.update(chunk as Buffer);
    }
  } finally {
    await handle.close();
  }
  return hash.digest('hex');
}

async function hashFile(path: string): Promise<string> {
  const hash = createHash('sha256');
  const stream = createReadStream(path);
  for await (const chunk of stream) {
    hash.update(chunk as Buffer);
  }
  return hash.digest('hex');
}

function removeFile(path: string): void {
  try {
    unlinkSync(path);
  } catch (error) {
    if (!isMissingFileError(error)) {
      console.warn('备份临时文件清理失败');
    }
  }
}

function ensurePrivateTempDirectory(tempRoot: string): string {
  const directory = join(tempRoot, 'litchi-journal-backups');
  mkdirSync(directory, { recursive: true, mode: 0o700 });
  chmodSync(directory, 0o700);
  return directory;
}

function assertDiaryRoot(diaryRoot: string): void {
  if (!existsSync(diaryRoot)) {
    throw new BackupSourceUnavailableError('日记目录不存在，已停止备份');
  }
  const stats = lstatSync(diaryRoot);
  if (stats.isSymbolicLink()) {
    throw new BackupSourceUnavailableError('日记目录不能是符号链接');
  }
  if (!stats.isDirectory()) {
    throw new BackupSourceUnavailableError('日记目录不是文件夹');
  }
}

function assertPathInsideRoot(sourceRoot: string, path: string): void {
  const resolved = realpathSync(path);
  const relativePath = relative(sourceRoot, resolved);
  if (relativePath === '' || (!relativePath.startsWith(`..${sep}`) && relativePath !== '..')) {
    return;
  }
  throw new BackupSourceUnavailableError('日记文件越过 Vault 边界');
}

function isMissingFileError(error: unknown): boolean {
  return error instanceof Error && 'code' in error && error.code === 'ENOENT';
}

function formatShanghaiTimestamp(date: Date): string {
  const formatter = new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Asia/Shanghai',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
    hourCycle: 'h23',
  });
  const parts = Object.fromEntries(
    formatter.formatToParts(date).map(part => [part.type, part.value]),
  );
  return `${parts.year}${parts.month}${parts.day}-${parts.hour}${parts.minute}${parts.second}`;
}
