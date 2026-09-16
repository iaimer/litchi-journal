import {
  createWriteStream,
  existsSync,
  mkdirSync,
  mkdtempSync,
  readFileSync,
  rmSync,
  statSync,
  symlinkSync,
  writeFileSync,
} from 'fs';
import { once } from 'events';
import { ZipArchive } from 'archiver';
import { tmpdir } from 'os';
import { join } from 'path';
import { afterEach, describe, expect, it } from 'vitest';
import * as unzipper from 'unzipper';
import {
  createBackupArchive,
  cleanupStaleBackupArchives,
  removeBackupArchive,
  validateBackupArchive,
} from './backup_archive.js';

const temporaryDirectories: string[] = [];

afterEach(() => {
  for (const directory of temporaryDirectories.splice(0)) {
    rmSync(directory, { recursive: true, force: true });
  }
});

function createFixture(): string {
  const directory = mkdtempSync(join(tmpdir(), 'litchi-backup-archive-'));
  temporaryDirectories.push(directory);
  mkdirSync(join(directory, 'vault', '01.日记', '2026', '09. September', 'assets'), {
    recursive: true,
  });
  return directory;
}

describe('createBackupArchive', () => {
  it('archives Chinese diary paths, manifest hashes, and skips unsafe entries', async () => {
    const directory = createFixture();
    const vaultPath = join(directory, 'vault');
    const diaryPath = join(vaultPath, '01.日记');
    const markdownPath = join(diaryPath, '2026', '09. September', '日记.md');
    const imagePath = join(diaryPath, '2026', '09. September', 'assets', '照片 空间.jpg');
    writeFileSync(markdownPath, '# 今天\n\n写下了一点记录。\n');
    writeFileSync(imagePath, Buffer.from([0, 1, 2, 3, 4]));
    writeFileSync(join(diaryPath, '.DS_Store'), 'ignore');
    const outsidePath = join(directory, 'outside.txt');
    writeFileSync(outsidePath, 'outside');
    symlinkSync(outsidePath, join(diaryPath, '逃逸链接.txt'));

    const archive = await createBackupArchive(
      vaultPath,
      new Date('2026-09-16T14:00:00.000Z'),
      join(directory, 'tmp'),
    );
    expect(archive.fileName).toBe('litchi-journal-diary-20260916-220000.zip');
    expect(archive.manifest.files.map(file => file.path)).toEqual([
      '01.日记/2026/09. September/assets/照片 空间.jpg',
      '01.日记/2026/09. September/日记.md',
    ]);
    expect(archive.sha256).toMatch(/^[a-f0-9]{64}$/);

    const zip = await unzipper.Open.file(archive.path);
    const names = zip.files.map(file => file.path).sort();
    expect(names).toEqual([
      '01.日记/2026/09. September/assets/照片 空间.jpg',
      '01.日记/2026/09. September/日记.md',
      '01.日记/',
      'backup-manifest.json',
    ].sort());
    const manifestEntry = zip.files.find(file => file.path === 'backup-manifest.json');
    expect(manifestEntry).toBeDefined();
    const manifest = JSON.parse((await manifestEntry!.buffer()).toString('utf8'));
    expect(manifest.files).toEqual(archive.manifest.files);
    expect(readFileSync(archive.path).length).toBe(archive.sizeBytes);

    removeBackupArchive(archive.path);
    expect(existsSync(archive.path)).toBe(false);
  });

  it('rejects an absent diary directory instead of publishing an empty backup', async () => {
    const directory = mkdtempSync(join(tmpdir(), 'litchi-backup-empty-'));
    temporaryDirectories.push(directory);
    await expect(
      createBackupArchive(
        join(directory, 'vault'),
        new Date('2026-09-16T14:00:00.000Z'),
        join(directory, 'tmp'),
      ),
    ).rejects.toThrow('日记目录不存在');
  });

  it('rejects a diary root symlink instead of following it outside the vault', async () => {
    const directory = mkdtempSync(join(tmpdir(), 'litchi-backup-root-link-'));
    temporaryDirectories.push(directory);
    const vaultPath = join(directory, 'vault');
    mkdirSync(vaultPath, { recursive: true });
    const outsidePath = join(directory, 'outside-diary');
    mkdirSync(outsidePath);
    symlinkSync(outsidePath, join(vaultPath, '01.日记'));

    await expect(
      createBackupArchive(vaultPath, new Date('2026-09-16T14:00:00.000Z'), join(directory, 'tmp')),
    ).rejects.toThrow('日记目录不能是符号链接');
  });

  it('creates private archives and removes stale crash leftovers', async () => {
    const directory = createFixture();
    const archive = await createBackupArchive(
      join(directory, 'vault'),
      new Date('2026-09-16T14:00:00.000Z'),
      join(directory, 'tmp'),
    );
    expect(statSync(archive.path).mode & 0o777).toBe(0o600);
    expect(statSync(join(directory, 'tmp', 'litchi-journal-backups')).mode & 0o777).toBe(0o700);
    expect(cleanupStaleBackupArchives(join(directory, 'tmp'))).toBe(1);
    expect(existsSync(archive.path)).toBe(false);
  });

  it('rejects a ZIP whose embedded manifest differs from the verified source', async () => {
    const directory = createFixture();
    const vaultPath = join(directory, 'vault');
    const diaryPath = join(vaultPath, '01.日记', '2026', '09. September', '日记.md');
    writeFileSync(diaryPath, '# 今天\n');
    const expected = await createBackupArchive(
      vaultPath,
      new Date('2026-09-16T14:00:00.000Z'),
      join(directory, 'tmp'),
    );
    const corruptPath = join(directory, 'corrupt.zip');
    const output = createWriteStream(corruptPath);
    const archive = new ZipArchive();
    archive.pipe(output);
    archive.append(JSON.stringify({ ...expected.manifest, files: [] }), {
      name: 'backup-manifest.json',
    });
    archive.file(diaryPath, { name: expected.manifest.files[0].path });
    await Promise.all([archive.finalize(), once(output, 'close')]);

    await expect(
      validateBackupArchive(corruptPath, expected.manifest),
    ).rejects.toThrow('备份清单内容无效');
  });
});
