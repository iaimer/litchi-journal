import {
  existsSync,
  mkdirSync,
  readdirSync,
  readFileSync,
  realpathSync,
  statSync,
  writeFileSync,
} from 'fs';
import { isAbsolute, join, relative, resolve } from 'path';
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

export function readDiary(date: Date): string {
  const path = getDiaryPath(date);
  if (!existsSync(path)) {
    throw new Error('Diary not found');
  }
  return readFileSync(path, 'utf-8');
}

export function writeDiary(date: Date, content: string): void {
  const path = getDiaryPath(date);
  const dir = join(path, '..');

  if (!existsSync(dir)) {
    mkdirSync(dir, { recursive: true });
  }

  writeFileSync(path, content, 'utf-8');
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
