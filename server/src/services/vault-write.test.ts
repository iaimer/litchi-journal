import { afterAll, afterEach, expect, it, vi } from 'vitest';
import { chmodSync, existsSync, fsyncSync, readFileSync, readdirSync, renameSync, rmSync, statSync, writeFileSync } from 'fs';
import { dirname } from 'path';

const fixture = vi.hoisted(() => ({ vaultPath: `/private/tmp/litchi-atomic-write-${process.pid}` }));
vi.mock('../config/index.js', () => ({ default: fixture }));
vi.mock('fs', async importOriginal => {
  const fs = await importOriginal<typeof import('fs')>();
  return { ...fs, writeFileSync: vi.fn(fs.writeFileSync), renameSync: vi.fn(fs.renameSync), fsyncSync: vi.fn(fs.fsyncSync) };
});

import { getDiaryPath, writeDiary } from './vault.js';

const date = new Date('2024-08-12T12:00:00+08:00');
afterEach(() => { vi.restoreAllMocks(); rmSync(fixture.vaultPath, { recursive: true, force: true }); });
afterAll(() => rmSync(fixture.vaultPath, { recursive: true, force: true }));

it('preserves the complete old diary when writing fails after partial output', async () => {
  writeDiary(date, '完整旧日记');
  const real = await vi.importActual<typeof import('fs')>('fs');
  vi.mocked(writeFileSync).mockImplementationOnce((path, ..._args) => {
    real.writeFileSync(path, '半截');
    throw Object.assign(new Error('disk full'), { code: 'ENOSPC' });
  });
  expect(() => writeDiary(date, '完整新日记')).toThrow('disk full');
  expect(readFileSync(getDiaryPath(date), 'utf8')).toBe('完整旧日记');
  expect(readdirSync(dirname(getDiaryPath(date)))).toEqual(['2024-08-12.md']);
});

it('leaves no diary or temporary file after a failed first write', () => {
  vi.mocked(writeFileSync).mockImplementationOnce(() => { throw new Error('disk full'); });
  expect(() => writeDiary(date, '新日记')).toThrow('disk full');
  expect(existsSync(getDiaryPath(date))).toBe(false);
  expect(readdirSync(dirname(getDiaryPath(date)))).toEqual([]);
});

it('preserves existing file permissions while replacing complete content', () => {
  writeDiary(date, '旧内容');
  chmodSync(getDiaryPath(date), 0o600);
  writeDiary(date, '新内容');
  expect(readFileSync(getDiaryPath(date), 'utf8')).toBe('新内容');
  expect(statSync(getDiaryPath(date)).mode & 0o777).toBe(0o600);
});

it.each(['fsync', 'rename'])('preserves old content when %s fails before commit', failure => {
  writeDiary(date, '完整旧日记');
  const method = failure === 'fsync' ? fsyncSync : renameSync;
  vi.mocked(method).mockImplementationOnce(() => { throw new Error('commit failed'); });
  expect(() => writeDiary(date, '新内容')).toThrow('commit failed');
  expect(readFileSync(getDiaryPath(date), 'utf8')).toBe('完整旧日记');
  expect(readdirSync(dirname(getDiaryPath(date)))).toEqual(['2024-08-12.md']);
});

it('does not report failure after rename if directory syncing is unsupported', async () => {
  writeDiary(date, '旧日记');
  const real = await vi.importActual<typeof import('fs')>('fs');
  vi.mocked(fsyncSync).mockImplementationOnce(real.fsyncSync).mockImplementationOnce(() => { throw new Error('not supported'); });
  expect(() => writeDiary(date, '已提交')).not.toThrow();
  expect(readFileSync(getDiaryPath(date), 'utf8')).toBe('已提交');
});
