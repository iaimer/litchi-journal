import { lstat, readFile, readdir, unlink } from 'node:fs/promises';
import { join } from 'node:path';
import { getShanghaiDateParts, parseShanghaiDate } from '../utils/date.js';

const MAX_AGE_MS = 24 * 60 * 60 * 1000;
const TEMP_NAME = /^(\d{4}-\d{2}-\d{2})\.md\.[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\.tmp$/i;

async function directoryEntries(path: string) {
  try {
    if (!(await lstat(path)).isDirectory()) return [];
    return await readdir(path, { withFileTypes: true });
  } catch (error) {
    if ((error as NodeJS.ErrnoException).code === 'ENOENT') return [];
    throw error;
  }
}

async function removeDuplicate(path: string, diary: string, now: number): Promise<boolean> {
  try {
    const metadata = await lstat(path);
    if (!metadata.isFile() || now - metadata.mtimeMs < MAX_AGE_MS) return false;
    const original = await lstat(diary);
    if (!original.isFile() || original.size === 0 || original.size !== metadata.size) return false;
    const [temporaryBytes, diaryBytes] = await Promise.all([readFile(path), readFile(diary)]);
    // 不同内容可能是崩溃前尚未提交的唯一副本，留给人工恢复。
    if (!temporaryBytes.equals(diaryBytes)) return false;
    const current = await lstat(path);
    if (!current.isFile() || current.ino !== metadata.ino || current.mtimeMs !== metadata.mtimeMs) return false;
    await unlink(path);
    return true;
  } catch (error) {
    if ((error as NodeJS.ErrnoException).code === 'ENOENT') return false;
    throw error;
  }
}

export async function cleanupDiaryTemporaryFiles(vaultPath: string, now = Date.now()): Promise<number> {
  const root = join(vaultPath, '01.日记');
  let removed = 0;
  for (const year of await directoryEntries(root)) {
    if (!year.isDirectory() || !/^\d{4}$/.test(year.name)) continue;
    const yearPath = join(root, year.name);
    for (const month of await directoryEntries(yearPath)) {
      if (!month.isDirectory() || !/^(0[1-9]|1[0-2])\.[A-Za-z]+$/.test(month.name)) continue;
      const monthPath = join(yearPath, month.name);
      for (const entry of await directoryEntries(monthPath)) {
        const match = entry.isFile() ? TEMP_NAME.exec(entry.name) : null;
        if (!match) continue;
        try {
          const date = getShanghaiDateParts(parseShanghaiDate(match[1]));
          if (date.year !== Number(year.name) || date.month !== Number(month.name.slice(0, 2))) continue;
        } catch { continue; }
        if (await removeDuplicate(join(monthPath, entry.name), join(monthPath, `${match[1]}.md`), now)) removed++;
      }
    }
  }
  return removed;
}
