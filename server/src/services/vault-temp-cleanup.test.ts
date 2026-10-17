import { afterEach, beforeEach, expect, it } from 'vitest';
import { mkdtempSync, mkdirSync, readFileSync, rmSync, symlinkSync, utimesSync, writeFileSync, existsSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { cleanupDiaryTemporaryFiles } from './vault-temp-cleanup.js';

let root: string;
const now = Date.parse('2026-10-18T12:00:00Z');
const suffix = '.aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa.tmp';
const relative = join('01.日记', '2024', '08.August', '2024-08-12.md');
const put = (name: string, text = '完整日记', ageHours = 48) => {
  const path = join(root, name);
  mkdirSync(dirname(path), { recursive: true });
  writeFileSync(path, text);
  utimesSync(path, new Date(now - ageHours * 3600000), new Date(now - ageHours * 3600000));
  return path;
};
beforeEach(() => { root = mkdtempSync(join(tmpdir(), 'litchi-temp-cleanup-')); });
afterEach(() => rmSync(root, { recursive: true, force: true }));

it('removes only an expired duplicate temporary copy of an existing diary', async () => {
  const diary = put(relative);
  const temp = put(relative + suffix);
  expect(await cleanupDiaryTemporaryFiles(root, now)).toBe(1);
  expect(existsSync(temp)).toBe(false);
  expect(readFileSync(diary, 'utf8')).toBe('完整日记');
});

it.each(['missing', 'different', 'empty'])('preserves possible recovery data when the diary is %s', async kind => {
  if (kind !== 'missing') put(relative, kind === 'empty' ? '' : '另一份内容');
  const temp = put(relative + suffix);
  expect(await cleanupDiaryTemporaryFiles(root, now)).toBe(0);
  expect(readFileSync(temp, 'utf8')).toBe('完整日记');
});

it('keeps recent files, non-system names and impossible dates', async () => {
  put(relative);
  const paths = [
    put(relative + suffix, '完整日记', 1),
    put(relative + '.user.tmp'),
    put(relative.replace('2024-08-12', '2024-02-30') + suffix),
    put(join('01.日记', '2024', '08.August', '2024-08-13.md') + suffix),
    put(join('other', '2024-08-12.md') + suffix),
  ];
  expect(await cleanupDiaryTemporaryFiles(root, now)).toBe(0);
  expect(paths.every(existsSync)).toBe(true);
});

it('does not follow linked directories or linked temporary files', async () => {
  const outside = mkdtempSync(join(tmpdir(), 'litchi-temp-outside-'));
  try {
    const outsideFile = join(outside, '2024-08-12.md' + suffix);
    writeFileSync(outsideFile, '完整日记');
    utimesSync(outsideFile, new Date(now - 48 * 3600000), new Date(now - 48 * 3600000));
    put(relative);
    symlinkSync(outsideFile, join(root, relative + suffix));
    symlinkSync(outside, join(root, '01.日记', '2024', '09.September'), 'dir');
    expect(await cleanupDiaryTemporaryFiles(root, now)).toBe(0);
    expect(readFileSync(outsideFile, 'utf8')).toBe('完整日记');
  } finally {
    rmSync(outside, { recursive: true, force: true });
  }
});

it('an absent journal root is a successful no-op', async () => {
  expect(await cleanupDiaryTemporaryFiles(root, now)).toBe(0);
});
