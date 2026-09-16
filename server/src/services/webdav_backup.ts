import { createReadStream } from 'fs';
import { posix } from 'path';
import { randomUUID } from 'crypto';
import { AuthType, createClient } from 'webdav';
import type { FileStat, WebDAVClient } from 'webdav';
import type { BackupSettings } from './backup_store.js';
import type { CreatedBackupArchive } from './backup_archive.js';

export type WebDavFailureKind =
  | 'auth'
  | 'network'
  | 'storage'
  | 'capability'
  | 'server'
  | 'unknown';

export class WebDavBackupError extends Error {
  readonly kind: WebDavFailureKind;

  constructor(kind: WebDavFailureKind, message: string) {
    super(message);
    this.name = 'WebDavBackupError';
    this.kind = kind;
  }
}

export interface WebDavUploadResult {
  remotePath: string;
  deletedCount: number;
}

export interface WebDavBackupClient {
  testConnection(): Promise<void>;
  uploadArchive(archive: CreatedBackupArchive, now?: Date): Promise<WebDavUploadResult>;
}

export function createWebDavBackupClient(
  settings: BackupSettings,
): WebDavBackupClient {
  if (!settings.webdavUrl || !settings.username || !settings.password) {
    throw new WebDavBackupError('auth', 'WebDAV 配置不完整');
  }

  const client = createClient(settings.webdavUrl, {
    authType: AuthType.Password,
    username: settings.username,
    password: settings.password,
  });
  const remotePath = normalizeRemotePath(settings.remotePath);

  return {
    testConnection: () => testConnection(client, remotePath),
    uploadArchive: (archive, now = new Date()) =>
      uploadArchive(client, remotePath, archive, settings, now),
  };
}

async function testConnection(
  client: WebDAVClient,
  remotePath: string,
): Promise<void> {
  let markerPath: string | null = null;
  let movedMarkerPath: string | null = null;
  let probeDirectoryPath: string | null = null;
  try {
    await ensureRemoteDirectory(client, remotePath);
    const compliance = await client.getDAVCompliance(remotePath);
    const supported = new Set(compliance.compliance.map(value => value.toLowerCase()));
    if (supported.size > 0 && !hasMoveCapability(supported)) {
      throw new WebDavBackupError('capability', 'WebDAV 服务不支持安全改名');
    }
    // getDirectoryContents 使用 PROPFIND，确认服务端能读取目录及文件属性。
    await client.getDirectoryContents(remotePath, { details: true });

    // 用一次空目录探测 MKCOL/DELETE，确保测试不仅能读取目录，也具备创建目录的能力。
    probeDirectoryPath = joinRemote(
      remotePath,
      `.litchi-journal-probe-${randomUUID()}`,
    );
    await client.createDirectory(probeDirectoryPath, { recursive: false });
    await client.deleteFile(probeDirectoryPath);
    probeDirectoryPath = null;

    markerPath = joinRemote(remotePath, `.litchi-journal-test-${randomUUID()}.txt`);
    movedMarkerPath = `${markerPath}.moved`;
    await client.putFileContents(markerPath, 'litchi-journal-webdav-test', {
      overwrite: false,
    });
    await client.moveFile(markerPath, movedMarkerPath, { overwrite: false });
    const stat = await client.stat(movedMarkerPath) as FileStat;
    if (stat.type !== 'file' || stat.size <= 0) {
      throw new WebDavBackupError('capability', 'WebDAV 文件校验失败');
    }
  } catch (error) {
    throw normalizeWebDavError(error);
  } finally {
    for (const path of [movedMarkerPath, markerPath, probeDirectoryPath]) {
      if (!path) continue;
      try {
        await client.deleteFile(path);
      } catch {
        // 测试清理失败不覆盖原始连接结果。
      }
    }
  }
}

async function uploadArchive(
  client: WebDAVClient,
  remotePath: string,
  archive: CreatedBackupArchive,
  settings: BackupSettings,
  now: Date,
): Promise<WebDavUploadResult> {
  const finalPath = joinRemote(remotePath, archive.fileName);
  const partialPath = `${finalPath}.partial`;
  try {
    await ensureRemoteDirectory(client, remotePath);
    await client.putFileContents(
      partialPath,
      createReadStream(archive.path),
      { contentLength: archive.sizeBytes, overwrite: true },
    );
    const partialStat = await client.stat(partialPath) as FileStat;
    if (partialStat.type !== 'file' || partialStat.size !== archive.sizeBytes) {
      throw new WebDavBackupError('storage', 'WebDAV 远端文件大小校验失败');
    }
    await client.moveFile(partialPath, finalPath, { overwrite: false });
    const deletedCount = await pruneRemoteBackups(client, remotePath, settings, now);
    return { remotePath: finalPath, deletedCount };
  } catch (error) {
    try {
      await client.deleteFile(partialPath);
    } catch {
      // 保留远端失败文件不会改变失败状态，正式清理只处理应用命名的 ZIP。
    }
    throw normalizeWebDavError(error);
  }
}

async function ensureRemoteDirectory(
  client: WebDAVClient,
  remotePath: string,
): Promise<void> {
  try {
    const stat = await client.stat(remotePath) as FileStat;
    if (stat.type !== 'directory') {
      throw new WebDavBackupError('capability', 'WebDAV 远程目录不是文件夹');
    }
    return;
  } catch (error) {
    const status = getStatus(error);
    if (status !== 404) throw normalizeWebDavError(error);
  }

  try {
    await client.createDirectory(remotePath, { recursive: true });
  } catch (error) {
    throw normalizeWebDavError(error);
  }
}

async function pruneRemoteBackups(
  client: WebDAVClient,
  remotePath: string,
  settings: BackupSettings,
  now: Date,
): Promise<number> {
  const result = await client.getDirectoryContents(remotePath, { details: true });
  const entries = (Array.isArray(result) ? result : result.data) as FileStat[];
  const backups = entries
    .filter(entry => entry.type === 'file')
    .map(entry => ({ entry, timestamp: parseBackupTimestamp(entry.basename) }))
    .filter((item): item is { entry: FileStat; timestamp: Date } => item.timestamp !== null)
    .sort((a, b) => b.timestamp.getTime() - a.timestamp.getTime());

  const keep = new Set<string>(
    backups.slice(0, settings.recentWeeks).map(item => item.entry.basename),
  );
  const nowParts = getShanghaiDateParts(now);
  const cutoffLocal = Date.UTC(
    nowParts.year,
    nowParts.month - settings.monthlyMonths,
    1,
  );
  const cutoff = new Date(cutoffLocal - 8 * 60 * 60 * 1000);
  const months = new Set<string>();
  for (const item of backups) {
    if (item.timestamp < cutoff) continue;
    const parts = getShanghaiDateParts(item.timestamp);
    const key = `${parts.year}-${parts.month}`;
    if (months.has(key)) continue;
    if (months.size >= settings.monthlyMonths) continue;
    months.add(key);
    keep.add(item.entry.basename);
  }

  let deletedCount = 0;
  for (const item of backups) {
    if (keep.has(item.entry.basename)) continue;
    await client.deleteFile(joinRemote(remotePath, item.entry.basename));
    deletedCount += 1;
  }
  return deletedCount;
}

function parseBackupTimestamp(name: string): Date | null {
  const match = /^litchi-journal-diary-(\d{8})-(\d{6})\.zip$/.exec(name);
  if (!match) return null;
  const date = match[1];
  const time = match[2];
  const parsed = new Date(
    `${date.slice(0, 4)}-${date.slice(4, 6)}-${date.slice(6, 8)}T${time.slice(0, 2)}:${time.slice(2, 4)}:${time.slice(4, 6)}+08:00`,
  );
  return Number.isNaN(parsed.getTime()) ? null : parsed;
}

function getShanghaiDateParts(date: Date): { year: number; month: number } {
  const formatter = new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Asia/Shanghai',
    year: 'numeric',
    month: '2-digit',
  });
  const parts = Object.fromEntries(
    formatter.formatToParts(date).map(part => [part.type, part.value]),
  );
  return { year: Number(parts.year), month: Number(parts.month) };
}

function joinRemote(directory: string, name: string): string {
  return posix.join(normalizeRemotePath(directory), name);
}

function normalizeRemotePath(value: string): string {
  let path = value.trim().replace(/\\/g, '/');
  if (!path.startsWith('/')) path = `/${path}`;
  return path.replace(/\/+/g, '/').replace(/\/$/, '') || '/';
}

function hasMoveCapability(compliance: Set<string>): boolean {
  return compliance.has('2') || compliance.has('1') || compliance.has('dav');
}

function normalizeWebDavError(error: unknown): WebDavBackupError {
  if (error instanceof WebDavBackupError) return error;
  const status = getStatus(error);
  if (status === 401 || status === 403) {
    return new WebDavBackupError('auth', 'WebDAV 认证失败，请检查用户名和应用密码');
  }
  if (status === 507 || status === 413) {
    return new WebDavBackupError('storage', 'WebDAV 存储空间不足');
  }
  if (status === 405 || status === 501 || status === 505) {
    return new WebDavBackupError('capability', 'WebDAV 服务不支持所需操作');
  }
  if (status !== undefined && status >= 500) {
    return new WebDavBackupError('server', 'WebDAV 服务器不可用，请稍后重试');
  }
  if (status === 404) {
    return new WebDavBackupError('capability', 'WebDAV 远程目录不存在且无法创建');
  }
  if (error instanceof TypeError || isNetworkError(error)) {
    return new WebDavBackupError('network', '无法连接 WebDAV，请检查地址和网络');
  }
  return new WebDavBackupError('unknown', 'WebDAV 备份失败，请稍后重试');
}

function getStatus(error: unknown): number | undefined {
  if (!error || typeof error !== 'object') return undefined;
  const status = (error as { status?: unknown }).status;
  return typeof status === 'number' ? status : undefined;
}

function isNetworkError(error: unknown): boolean {
  if (!error || typeof error !== 'object') return false;
  const code = (error as { code?: unknown }).code;
  return typeof code === 'string' && /^(EAI_AGAIN|ECONN|ETIMEDOUT|ENOTFOUND)/.test(code);
}
