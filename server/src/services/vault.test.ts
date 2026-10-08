import { afterEach, expect, it, vi } from 'vitest';
import { readFileSync } from 'fs';

vi.mock('../config/index.js', () => ({
  default: { vaultPath: '/private/tmp/litchi-vault-read-fixture' },
}));
vi.mock('fs', async importOriginal => ({
  ...await importOriginal<typeof import('fs')>(),
  readFileSync: vi.fn(),
}));

import { DiaryNotFoundError, readDiary } from './vault.js';

afterEach(() => vi.resetAllMocks());

it('converts only ENOENT to a typed missing diary', () => {
  vi.mocked(readFileSync).mockImplementation(() => {
    throw Object.assign(new Error('missing'), { code: 'ENOENT' });
  });
  expect(() => readDiary(new Date('2024-08-12T12:00:00+08:00')))
    .toThrow(DiaryNotFoundError);
});

it.each(['EACCES', 'EIO', 'EISDIR'])('preserves %s instead of reporting missing', code => {
  const error = Object.assign(new Error('read failed'), { code });
  vi.mocked(readFileSync).mockImplementation(() => { throw error; });
  expect(() => readDiary(new Date('2024-08-12T12:00:00+08:00'))).toThrow(error);
});
