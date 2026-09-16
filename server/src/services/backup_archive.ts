import { ZipArchive } from 'archiver';
import { once } from 'events';
import {
  createReadStream,
  createWriteStream,
  existsSync,
  lstatSync,
  mkdirSync,
  readdirSync,
  unlinkSync,
} from 'fs';
import { createHash, randomUUID } from 'crypto';
import { join, relative, sep } from 'path';
import { tmpdir } from 'os';
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

interface SourceFile {
  fullPath: string;
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
  tempDirectory = tmpdir(),
): Promise<CreatedBackupArchive> {
  mkdirSync(tempDirectory, { recursive: true });
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
  removeFile(path);
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
  await validateZip(tempPath, manifest);
  return manifest;
}

async function collectSourceFiles(diaryRoot: string): Promise<SourceFile[]> {
  const signatures = collectSourceSignatures(diaryRoot);
  const files: SourceFile[] = [];
  for (const signature of signatures) {
    const relativePath = signature.archivePath.slice('01.日记/'.length);
    const fullPath = join(diaryRoot, ...relativePath.split('/'));
    files.push({
      fullPath,
      archivePath: signature.archivePath,
      sizeBytes: signature.sizeBytes,
      mtimeMs: signature.mtimeMs,
      sha256: await hashFile(fullPath),
    });
  }
  return files;
}

function collectSourceSignatures(diaryRoot: string): SourceSignature[] {
  const files: SourceSignature[] = [];
  if (existsSync(diaryRoot) && lstatSync(diaryRoot).isSymbolicLink()) {
    throw new Error('日记目录不能是符号链接');
  }
  walkDirectory(diaryRoot, filePath => {
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

function walkDirectory(directory: string, onFile: (path: string) => void): void {
  if (!existsSync(directory)) return;
  const entries = readdirSync(directory, { withFileTypes: true });
  for (const entry of entries) {
    if (entry.name === '.DS_Store' || entry.isSymbolicLink()) continue;
    const path = join(directory, entry.name);
    if (entry.isDirectory()) {
      walkDirectory(path, onFile);
      continue;
    }
    if (entry.isFile()) onFile(path);
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
  const output = createWriteStream(tempPath, { flags: 'wx' });
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
    archive.file(file.fullPath, {
      name: file.archivePath,
      date: new Date(file.mtimeMs),
    });
  }

  const finalized = archive.finalize();
  await Promise.race([Promise.all([finalized, outputClosed]), error]);
}

async function validateZip(
  path: string,
  expectedManifest: BackupManifest,
): Promise<void> {
  const directory = await unzipper.Open.file(path);
  const entries = directory.files.filter(file => file.type === 'File');
  const manifestEntry = entries.find(file => file.path === 'backup-manifest.json');
  if (!manifestEntry) throw new Error('ZIP 缺少备份清单');

  const parsed = JSON.parse((await manifestEntry.buffer()).toString('utf-8')) as BackupManifest;
  if (parsed.schemaVersion !== expectedManifest.schemaVersion) {
    throw new Error('ZIP 备份清单版本无效');
  }

  const expected = new Map(expectedManifest.files.map(file => [file.path, file]));
  const actual = new Map(entries.filter(file => file.path !== 'backup-manifest.json').map(file => [file.path, file]));
  if (expected.size !== actual.size) throw new Error('ZIP 文件清单不完整');

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
    if (existsSync(path)) unlinkSync(path);
  } catch {
    // 失败清理不会覆盖原始错误，也不会向用户暴露路径。
  }
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
