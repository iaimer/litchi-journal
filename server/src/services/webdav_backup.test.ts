import { mkdtempSync, rmSync, writeFileSync } from 'fs';
import { tmpdir } from 'os';
import { join } from 'path';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { createWebDavBackupClient, WebDavBackupError } from './webdav_backup.js';
import type { BackupSettings } from './backup_store.js';

const testClient = vi.hoisted(() => ({
  stat: vi.fn(),
  createDirectory: vi.fn(),
  getDAVCompliance: vi.fn(),
  putFileContents: vi.fn(),
  moveFile: vi.fn(),
  deleteFile: vi.fn(),
  getDirectoryContents: vi.fn(),
}));

vi.mock('webdav', () => ({
  AuthType: { Password: 'password' },
  createClient: vi.fn(() => testClient),
}));

const directories: string[] = [];

afterEach(() => {
  vi.clearAllMocks();
  for (const directory of directories.splice(0)) {
    rmSync(directory, { recursive: true, force: true });
  }
});

function settings(overrides: Partial<BackupSettings> = {}): BackupSettings {
  return {
    enabled: false,
    weekday: 0,
    time: '03:00',
    timezone: 'Asia/Shanghai',
    webdavUrl: 'https://dav.example.test/dav',
    username: 'alice',
    password: 'app-password',
    remotePath: '/荔枝日记备份',
    recentWeeks: 8,
    monthlyMonths: 12,
    ...overrides,
  };
}

describe('WebDAV backup client', () => {
  it('tests directory creation, DAV capability, write, move, stat, and cleanup', async () => {
    testClient.stat.mockImplementation(async (path: string) => {
      if (path === '/荔枝日记备份') return { type: 'directory', size: 0 };
      return { type: 'file', size: 23 };
    });
    testClient.getDAVCompliance.mockResolvedValue({ compliance: ['1', '2'], server: 'test' });
    testClient.putFileContents.mockResolvedValue(true);
    testClient.moveFile.mockResolvedValue(true);
    testClient.deleteFile.mockResolvedValue(true);

    await createWebDavBackupClient(settings()).testConnection();

    expect(testClient.getDAVCompliance).toHaveBeenCalledWith('/荔枝日记备份');
    expect(testClient.getDirectoryContents).toHaveBeenCalledWith(
      '/荔枝日记备份',
      { details: true },
    );
    expect(testClient.createDirectory).toHaveBeenCalledWith(
      expect.stringMatching(/^\/荔枝日记备份\/\.litchi-journal-probe-/),
      { recursive: false },
    );
    expect(testClient.putFileContents).toHaveBeenCalledOnce();
    expect(testClient.moveFile).toHaveBeenCalledOnce();
    expect(testClient.deleteFile.mock.calls.length).toBeGreaterThanOrEqual(2);
  });

  it('uses partial upload and protects unknown remote files during retention cleanup', async () => {
    const directory = mkdtempSync(join(tmpdir(), 'litchi-webdav-upload-'));
    directories.push(directory);
    const archivePath = join(directory, 'source.zip');
    writeFileSync(archivePath, 'zip-content');
    testClient.stat.mockImplementation(async (path: string) => {
      if (path === '/荔枝日记备份') return { type: 'directory', size: 0 };
      return { type: 'file', size: 10 };
    });
    testClient.putFileContents.mockImplementation(async (_path, content) => {
      if (content && typeof content !== 'string' && typeof content.resume === 'function') {
        await new Promise<void>((resolve, reject) => {
          content.once('error', reject);
          content.once('end', resolve);
          content.resume();
        });
      }
      return true;
    });
    testClient.moveFile.mockResolvedValue(true);
    testClient.getDirectoryContents.mockResolvedValue([
      ...Array.from({ length: 9 }, (_, index) => ({
        type: 'file',
        basename: `litchi-journal-diary-202609${String(16 - index).padStart(2, '0')}-030000.zip`,
        size: 10,
      })),
      { type: 'file', basename: '用户自己的文件.zip', size: 10 },
    ]);
    testClient.deleteFile.mockResolvedValue(true);

    const result = await createWebDavBackupClient(settings()).uploadArchive(
      {
        path: archivePath,
        fileName: 'litchi-journal-diary-20260916-220000.zip',
        sizeBytes: 10,
        sha256: 'a'.repeat(64),
        manifest: {
          schemaVersion: 1,
          createdAt: '2026-09-16T14:00:00.000Z',
          source: '01.日记',
          files: [],
        },
      },
      new Date('2026-09-16T14:00:00.000Z'),
    );

    expect(result.remotePath).toBe('/荔枝日记备份/litchi-journal-diary-20260916-220000.zip');
    expect(testClient.putFileContents.mock.calls[0][0]).toBe(
      '/荔枝日记备份/litchi-journal-diary-20260916-220000.zip.partial',
    );
    expect(testClient.moveFile).toHaveBeenCalledWith(
      '/荔枝日记备份/litchi-journal-diary-20260916-220000.zip.partial',
      '/荔枝日记备份/litchi-journal-diary-20260916-220000.zip',
      { overwrite: false },
    );
    expect(testClient.deleteFile).toHaveBeenCalledOnce();
    expect(testClient.deleteFile.mock.calls[0][0]).toMatch(
      /^\/荔枝日记备份\/litchi-journal-diary-/,
    );
  });

  it('maps authentication failures to a redacted category', async () => {
    testClient.stat.mockRejectedValue({ status: 401 });
    await expect(createWebDavBackupClient(settings()).testConnection()).rejects.toEqual(
      new WebDavBackupError('auth', 'WebDAV 认证失败，请检查用户名和应用密码'),
    );
  });

  it('maps server failures without exposing remote details', async () => {
    testClient.stat.mockRejectedValue({ status: 503 });
    await expect(createWebDavBackupClient(settings()).testConnection()).rejects.toEqual(
      new WebDavBackupError('server', 'WebDAV 服务器不可用，请稍后重试'),
    );
  });
});
