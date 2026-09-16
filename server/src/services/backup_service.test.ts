import { mkdtempSync, rmSync, writeFileSync } from 'fs';
import { tmpdir } from 'os';
import { join } from 'path';
import { afterEach, describe, expect, it, vi } from 'vitest';
import {
  BackupBusyError,
  BackupService,
  getNextScheduledRun,
  getPreviousScheduledRun,
} from './backup_service.js';
import { BackupStore } from './backup_store.js';

vi.mock('../config/index.js', () => ({
  default: { serverDataDir: '/private/tmp/litchi-backup-test-data' },
}));

const temporaryDirectories: string[] = [];

afterEach(() => {
  vi.useRealTimers();
  for (const directory of temporaryDirectories.splice(0)) {
    rmSync(directory, { recursive: true, force: true });
  }
});

describe('BackupService', () => {
  it('calculates weekly Shanghai schedule boundaries', () => {
    const now = new Date('2026-09-16T14:00:00.000Z');
    expect(getNextScheduledRun(now, 0, '03:00').toISOString()).toBe('2026-09-19T19:00:00.000Z');
    expect(getPreviousScheduledRun(now, 0, '03:00').toISOString()).toBe('2026-09-12T19:00:00.000Z');
  });

  it('shares one task lock between manual backup calls', async () => {
    const directory = mkdtempSync(join(tmpdir(), 'litchi-backup-service-'));
    temporaryDirectories.push(directory);
    const vaultPath = join(directory, 'vault');
    writeFileSync(vaultPath, 'placeholder');
    const archivePath = join(directory, 'archive.zip');
    writeFileSync(archivePath, 'zip');
    const store = new BackupStore(join(directory, 'data'));
    store.saveSettings({
      enabled: false,
      webdavUrl: 'https://dav.example.test',
      username: 'alice',
      password: 'secret',
      remotePath: '/backups',
    });
    let releaseUpload!: () => void;
    const uploadFinished = new Promise<void>(resolve => {
      releaseUpload = resolve;
    });
    const service = new BackupService({
      vaultPath,
      store,
      createArchive: async () => ({
        path: archivePath,
        fileName: 'litchi-journal-diary-20260916-220000.zip',
        sizeBytes: 3,
        sha256: 'a'.repeat(64),
        manifest: { schemaVersion: 1, createdAt: new Date().toISOString(), source: '01.日记', files: [] },
      }),
      createWebDavClient: () => ({
        testConnection: async () => {},
        uploadArchive: async () => {
          await uploadFinished;
          return { remotePath: '/backups/file.zip', deletedCount: 0 };
        },
      }),
    });
    service.startManualBackup();
    expect(() => service.startManualBackup()).toThrow(BackupBusyError);
    releaseUpload();
    await new Promise(resolve => setTimeout(resolve, 20));
    expect(service.getDto().status.state).toBe('success');
    expect(service.getDto().status.lastWebDavSuccessAt).toBeDefined();
  });

  it('runs a scheduled WebDAV backup after an export releases the shared lock', async () => {
    vi.useFakeTimers();
    vi.setSystemTime(new Date('2026-09-16T14:00:00.000Z'));
    const directory = mkdtempSync(join(tmpdir(), 'litchi-backup-queued-'));
    temporaryDirectories.push(directory);
    const vaultPath = join(directory, 'vault');
    writeFileSync(vaultPath, 'placeholder');
    const archivePath = join(directory, 'archive.zip');
    writeFileSync(archivePath, 'zip');
    const store = new BackupStore(join(directory, 'data'));
    store.saveSettings({
      enabled: true,
      webdavUrl: 'https://dav.example.test',
      username: 'alice',
      password: 'secret',
      remotePath: '/backups',
    });
    const uploadArchive = vi.fn(async () => ({ remotePath: '/backups/file.zip', deletedCount: 0 }));
    const service = new BackupService({
      vaultPath,
      store,
      now: () => new Date(),
      createArchive: async () => ({
        path: archivePath,
        fileName: 'litchi-journal-diary-20260916-220000.zip',
        sizeBytes: 3,
        sha256: 'a'.repeat(64),
        manifest: { schemaVersion: 1, createdAt: new Date().toISOString(), source: '01.日记', files: [] },
      }),
      createWebDavClient: () => ({ testConnection: async () => {}, uploadArchive }),
    });

    service.start();
    const exported = await service.createExportArchive();
    await vi.advanceTimersByTimeAsync(1000);
    expect(uploadArchive).not.toHaveBeenCalled();
    await service.finishExport(exported, true);
    await vi.advanceTimersByTimeAsync(1);
    expect(uploadArchive).toHaveBeenCalledOnce();
    service.stop();
  });

  it('does not count a phone export as a successful scheduled WebDAV backup', async () => {
    vi.useFakeTimers();
    vi.setSystemTime(new Date('2026-09-16T14:00:00.000Z'));
    const directory = mkdtempSync(join(tmpdir(), 'litchi-backup-catchup-'));
    temporaryDirectories.push(directory);
    const vaultPath = join(directory, 'vault');
    writeFileSync(vaultPath, 'placeholder');
    const archivePath = join(directory, 'archive.zip');
    writeFileSync(archivePath, 'zip');
    const store = new BackupStore(join(directory, 'data'));
    store.saveSettings({
      enabled: true,
      webdavUrl: 'https://dav.example.test',
      username: 'alice',
      password: 'secret',
      remotePath: '/backups',
    });
    store.saveStatus({ state: 'success', lastSuccessAt: new Date().toISOString() });
    const uploadArchive = vi.fn(async () => ({ remotePath: '/backups/file.zip', deletedCount: 0 }));
    const service = new BackupService({
      vaultPath,
      store,
      now: () => new Date(),
      createArchive: async () => ({
        path: archivePath,
        fileName: 'litchi-journal-diary-20260916-220000.zip',
        sizeBytes: 3,
        sha256: 'a'.repeat(64),
        manifest: { schemaVersion: 1, createdAt: new Date().toISOString(), source: '01.日记', files: [] },
      }),
      createWebDavClient: () => ({ testConnection: async () => {}, uploadArchive }),
    });

    service.start();
    await vi.advanceTimersByTimeAsync(1000);
    expect(uploadArchive).toHaveBeenCalledOnce();
    service.stop();
  });
});
