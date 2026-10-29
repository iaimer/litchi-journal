import {
  constants,
  fstatSync,
  lstatSync,
  existsSync,
  closeSync,
  fsyncSync,
  mkdirSync,
  openSync,
  readdirSync,
  readFileSync,
  realpathSync,
  renameSync,
  statSync,
  unlinkSync,
  writeFileSync,
} from 'fs';
import { randomUUID } from 'crypto';
import { isAbsolute, join, relative, resolve, dirname } from 'path';
import config from '../config/index.js';
import { getShanghaiDateParts, getShanghaiDateString } from '../utils/date.js';

const monthNames = ['January', 'February', 'March', 'April', 'May', 'June',
                    'July', 'August', 'September', 'October', 'November', 'December'];
const SAFE_IMAGE_NAME_PATTERN = /^[^/\\\u0000-\u001F\u007F]+\.(jpg|jpeg|png|gif|webp|heic|heif)$/i;

export function getDiaryPath(date: Date): string {
  const { year, month } = getShanghaiDateParts(date);
  const day = getDateString(date);

  return join(
    config.vaultPath,
    '01.日记',
    year.toString(),
    `${month.toString().padStart(2, '0')}.${monthNames[month - 1]}`,
    `${day}.md`
  );
}

export function getDateString(date: Date): string {
  return getShanghaiDateString(date);
}

export class DiaryNotFoundError extends Error {
  constructor() {
    super('Diary not found');
    this.name = 'DiaryNotFoundError';
  }
}

function assertDiaryParent(path: string): void {
  const root = resolve(config.vaultPath);
  if (!existsSync(root)) {
    try { lstatSync(root); throw new Error('日记根目录不可用'); }
    catch (error) { if ((error as NodeJS.ErrnoException).code !== 'ENOENT') throw error; }
    return;
  }
  const realRoot = realpathSync(root);
  let parent = dirname(path);
  while (!existsSync(parent)) {
    // 失效链接不是可自动创建的目录。
    try { lstatSync(parent); throw new Error('日记目录不可用'); }
    catch (error) { if ((error as NodeJS.ErrnoException).code !== 'ENOENT') throw error; }
    if (parent === root) return;
    parent = dirname(parent);
  }
  const within = relative(realRoot, realpathSync(parent));
  if (within.startsWith('..') || isAbsolute(within) || !statSync(parent).isDirectory()) {
    throw new Error('日记目录不安全');
  }
}

export function readDiary(date: Date): string {
  try {
    const path = getDiaryPath(date);
    // 先区分真正缺档与已有但失效的链接，避免错误触发自动创建。
    assertDiaryParent(path);
    const entry = lstatSync(path);
    const root = realpathSync(config.vaultPath);
    let resolved: string;
    try { resolved = realpathSync(path); } catch { throw new Error('日记路径不可用'); }
    const within = relative(root, resolved);
    if (!within || within.startsWith('..') || isAbsolute(within) ||
        (!entry.isFile() && !entry.isSymbolicLink()) || !statSync(resolved).isFile()) {
      throw new Error('日记路径不安全');
    }
    const descriptor = openSync(resolved, constants.O_RDONLY | constants.O_NONBLOCK | constants.O_NOFOLLOW);
    try {
      if (!fstatSync(descriptor).isFile()) throw new Error('日记不是普通文件');
      return readFileSync(descriptor, 'utf-8');
    } finally { closeSync(descriptor); }
  } catch (error) {
    // 只将明确缺失转换为 404，权限及其他读取错误不能触发客户端创建。
    if ((error as NodeJS.ErrnoException).code === 'ENOENT') {
      throw new DiaryNotFoundError();
    }
    throw error;
  }
}

export function writeDiary(date: Date, content: string): void {
  const path = getDiaryPath(date);
  const dir = join(path, '..');

  if (!existsSync(dir)) {
    mkdirSync(dir, { recursive: true });
  }

  const temporaryPath = `${path}.${randomUUID()}.tmp`;
  const mode = existsSync(path) ? statSync(path).mode & 0o777 : 0o600;
  let descriptor: number | undefined;
  try {
    descriptor = openSync(temporaryPath, 'wx', mode);
    writeFileSync(descriptor, content, 'utf-8');
    fsyncSync(descriptor);
    closeSync(descriptor);
    descriptor = undefined;
    renameSync(temporaryPath, path);
  } finally {
    try {
      if (descriptor !== undefined) closeSync(descriptor);
    } finally {
      if (existsSync(temporaryPath)) unlinkSync(temporaryPath);
    }
  }

  // rename 已提交后，目录同步失败不能再向调用方报告“未保存”并触发重试。
  try {
    const directoryDescriptor = openSync(dir, 'r');
    try {
      fsyncSync(directoryDescriptor);
    } finally {
      closeSync(directoryDescriptor);
    }
  } catch {
    // 部分文件系统不支持目录 fsync；文件本身已在替换前同步。
  }
}

export function listMonthDiaries(year: number, month: number): string[] {
  const dir = join(
    config.vaultPath,
    '01.日记',
    year.toString(),
    `${month.toString().padStart(2, '0')}.${monthNames[month - 1]}`
  );

  if (!existsSync(dir)) {
    return [];
  }

  return readdirSync(dir)
    .filter(f => f.endsWith('.md'))
    .map(f => f.replace('.md', ''));
}

/**
 * 返回 Vault 中实际存在日记文件的月份，按时间倒序排列。
 * 画廊分页需要跳过不存在的月份，但不应为了浏览而创建目录或文件。
 */
export function listDiaryMonths(): Array<{ year: number; month: number }> {
  const diaryRoot = join(config.vaultPath, '01.日记');
  if (!existsSync(diaryRoot)) return [];

  const months: Array<{ year: number; month: number }> = [];
  for (const yearEntry of readdirSync(diaryRoot, { withFileTypes: true })) {
    if (!yearEntry.isDirectory() || !/^\d{4}$/.test(yearEntry.name)) continue;
    const year = Number(yearEntry.name);
    const yearDir = join(diaryRoot, yearEntry.name);
    for (const monthEntry of readdirSync(yearDir, { withFileTypes: true })) {
      if (!monthEntry.isDirectory()) continue;
      const match = monthEntry.name.match(/^(\d{2})\./);
      if (!match) continue;
      const month = Number(match[1]);
      if (month >= 1 && month <= 12) months.push({ year, month });
    }
  }

  return months.sort((a, b) =>
    b.year - a.year || b.month - a.month
  );
}

export function existsDiary(date: Date): boolean {
  const path = getDiaryPath(date);
  return existsSync(path);
}

export function getAssetsDir(date: Date): string {
  const { year, month } = getShanghaiDateParts(date);

  return join(
    config.vaultPath,
    '01.日记',
    year.toString(),
    `${month.toString().padStart(2, '0')}.${monthNames[month - 1]}`,
    'assets'
  );
}

/**
 * 查找日记图片的实体文件，优先使用月份 assets，兼容旧的年份级 assets。
 * 只返回 Vault 内的普通文件，避免画廊索引出不存在或越界的图片链接。
 */
export function resolveImagePath(
  year: number,
  imageName: string,
  month: number | null,
): string | null {
  if (!SAFE_IMAGE_NAME_PATTERN.test(imageName)) return null;

  const assetDirs = month === null
    ? []
    : [
        join(
          config.vaultPath,
          '01.日记',
          year.toString(),
          `${month.toString().padStart(2, '0')}.${monthNames[month - 1]}`,
          'assets',
        ),
      ];
  assetDirs.push(join(config.vaultPath, '01.日记', year.toString(), 'assets'));

  for (const assetsDir of assetDirs) {
    const imagePath = resolveSafeImagePath(assetsDir, imageName);
    if (imagePath) return imagePath;
  }
  return null;
}

function resolveSafeImagePath(assetsDir: string, imageName: string): string | null {
  const resolvedAssetsDir = resolve(assetsDir);
  const imagePath = resolve(resolvedAssetsDir, imageName);
  const relativePath = relative(resolvedAssetsDir, imagePath);
  if (!relativePath || relativePath.startsWith('..') || isAbsolute(relativePath)) {
    return null;
  }
  if (!existsSync(imagePath)) return null;

  try {
    const realVaultPath = realpathSync(resolve(config.vaultPath));
    const realAssetsDir = realpathSync(resolvedAssetsDir);
    const realImagePath = realpathSync(imagePath);
    const vaultRelativePath = relative(realVaultPath, realAssetsDir);
    const realRelativePath = relative(realAssetsDir, realImagePath);
    if (
      !vaultRelativePath ||
      vaultRelativePath.startsWith('..') ||
      isAbsolute(vaultRelativePath) ||
      !realRelativePath ||
      realRelativePath.startsWith('..') ||
      isAbsolute(realRelativePath) ||
      !statSync(realImagePath).isFile()
    ) {
      return null;
    }
  } catch {
    return null;
  }

  return imagePath;
}
