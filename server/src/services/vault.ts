import { readFileSync, writeFileSync, existsSync, mkdirSync, readdirSync } from 'fs';
import { join } from 'path';
import config from '../config/index.js';
import { getShanghaiDateParts, getShanghaiDateString } from '../utils/date.js';

const monthNames = ['January', 'February', 'March', 'April', 'May', 'June',
                    'July', 'August', 'September', 'October', 'November', 'December'];

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
    throw new Error(`Diary not found: ${path}`);
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
