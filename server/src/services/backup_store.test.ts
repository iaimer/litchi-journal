import { chmodSync, mkdirSync, mkdtempSync, readFileSync, rmSync, statSync, writeFileSync } from 'fs';
import { tmpdir } from 'os';
import { join } from 'path';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { BackupStore, DEFAULT_BACKUP_SETTINGS } from './backup_store.js';

vi.mock('../config/index.js', () => ({
  default: { serverDataDir: '/private/tmp/litchi-backup-test-data' },
}));

const temporaryDirectories: string[] = [];

afterEach(() => {
  for (const directory of temporaryDirectories.splice(0)) {
    rmSync(directory, { recursive: true, force: true });
  }
});

describe('BackupStore', () => {
  it('persists settings atomically and never exposes the password in DTO', () => {
    const directory = mkdtempSync(join(tmpdir(), 'litchi-backup-store-'));
    temporaryDirectories.push(directory);
    const store = new BackupStore(join(directory, 'data'));
    const saved = store.saveSettings({
      enabled: true,
      weekday: 2,
      time: '04:30',
      webdavUrl: 'https://dav.example.test/root',
      username: 'alice',
      password: 'secret-not-for-output',
      remotePath: '/荔枝日记备份',
    });
    expect(saved.password).toBe('secret-not-for-output');
    const dto = store.toDto(saved, { state: 'success', lastSha256: 'a'.repeat(64) });
    expect(dto.webdav).toEqual({
      url: 'https://dav.example.test/root',
      username: 'alice',
      remotePath: '/荔枝日记备份',
      passwordConfigured: true,
    });
    expect(JSON.stringify(dto)).not.toContain('secret-not-for-output');
    expect(store.loadSettings()).toEqual(saved);
    expect(statSync(join(directory, 'data', 'backup-settings.json')).mode & 0o777).toBe(0o600);
    expect(statSync(join(directory, 'data', 'backup-credentials.json')).mode & 0o777).toBe(0o600);
    expect(readFileSync(join(directory, 'data', 'backup-settings.json'), 'utf8')).not.toContain(
      'secret-not-for-output',
    );
  });

  it('falls back to safe defaults after a damaged settings file', () => {
    const directory = mkdtempSync(join(tmpdir(), 'litchi-backup-store-corrupt-'));
    temporaryDirectories.push(directory);
    const dataDirectory = join(directory, 'data');
    mkdirSync(dataDirectory, { recursive: true });
    const settingsPath = join(dataDirectory, 'backup-settings.json');
    writeFileSync(settingsPath, '{broken');
    chmodSync(settingsPath, 0o600);
    expect(new BackupStore(dataDirectory).loadSettings()).toEqual(DEFAULT_BACKUP_SETTINGS);
  });
});
