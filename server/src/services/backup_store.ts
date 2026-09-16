import {
  chmodSync,
  closeSync,
  existsSync,
  fsyncSync,
  mkdirSync,
  openSync,
  readFileSync,
  renameSync,
  unlinkSync,
  writeFileSync,
} from 'fs';
import { randomUUID } from 'crypto';
import { dirname, join } from 'path';
import { serverDataDir } from '../config/index.js';

export type BackupStatusKind = 'idle' | 'running' | 'success' | 'failed';

export interface BackupSettings {
  enabled: boolean;
  weekday: number;
  time: string;
  timezone: 'Asia/Shanghai';
  webdavUrl: string;
  username: string;
  password: string;
  remotePath: string;
  recentWeeks: 8;
  monthlyMonths: 12;
}

export interface BackupStatus {
  state: BackupStatusKind;
  phase?: string;
  lastAttemptAt?: string;
  lastSuccessAt?: string;
  lastWebDavSuccessAt?: string;
  nextRunAt?: string;
  lastFileName?: string;
  lastSizeBytes?: number;
  lastSha256?: string;
  lastError?: string;
}

export interface BackupSettingsDto {
  enabled: boolean;
  weekday: number;
  time: string;
  timezone: 'Asia/Shanghai';
  webdav: {
    url: string;
    username: string;
    remotePath: string;
    passwordConfigured: boolean;
  };
  retention: {
    recentWeeks: 8;
    monthlyMonths: 12;
  };
  status: BackupStatus;
}

export interface BackupSettingsInput {
  enabled?: unknown;
  weekday?: unknown;
  time?: unknown;
  webdavUrl?: unknown;
  username?: unknown;
  password?: unknown;
  clearPassword?: unknown;
  remotePath?: unknown;
}

export const DEFAULT_BACKUP_SETTINGS: BackupSettings = {
  enabled: false,
  weekday: 0,
  time: '03:00',
  timezone: 'Asia/Shanghai',
  webdavUrl: '',
  username: '',
  password: '',
  remotePath: '/荔枝日记备份',
  recentWeeks: 8,
  monthlyMonths: 12,
};

export class BackupStoreCorruptionError extends Error {
  constructor(readonly kind: 'settings' | 'credentials' | 'status') {
    super('备份配置文件损坏，请重新检查并保存备份设置');
    this.name = 'BackupStoreCorruptionError';
  }
}

const DEFAULT_BACKUP_STATUS: BackupStatus = {
  state: 'idle',
};

export class BackupStore {
  private readonly settingsPath: string;
  private readonly credentialsPath: string;
  private readonly statusPath: string;

  constructor(dataDir?: string) {
    const resolvedDataDir = dataDir ?? getConfiguredDataDir();
    this.settingsPath = join(resolvedDataDir, 'backup-settings.json');
    this.credentialsPath = join(resolvedDataDir, 'backup-credentials.json');
    this.statusPath = join(resolvedDataDir, 'backup-state.json');
  }

  loadSettings(): BackupSettings {
    const raw = this.readJson(this.settingsPath, 'settings');
    const credentials = this.readJson(this.credentialsPath, 'credentials');
    const password = credentials && typeof credentials === 'object'
      ? (credentials as Record<string, unknown>).password
      : undefined;
    return normalizeSettings({
      ...(raw && typeof raw === 'object' ? raw : {}),
      // 兼容早期试运行版本曾写入设置文件的密码，后续保存会迁移到凭据文件。
      password: typeof password === 'string'
        ? password
        : raw && typeof raw === 'object' && typeof (raw as Record<string, unknown>).password === 'string'
          ? (raw as Record<string, unknown>).password
          : '',
    });
  }

  saveSettings(input: BackupSettingsInput): BackupSettings {
    const current = this.loadSettings();
    const next = mergeSettings(current, input);
    const { password, ...safeSettings } = next;
    this.writeJson(this.settingsPath, safeSettings);
    this.writeJson(this.credentialsPath, { password });
    return next;
  }

  loadStatus(): BackupStatus {
    const raw = this.readJson(this.statusPath, 'status');
    if (!raw || typeof raw !== 'object') return { ...DEFAULT_BACKUP_STATUS };
    const value = raw as Partial<BackupStatus>;
    const state = value.state;
    if (
      state !== 'idle' &&
      state !== 'running' &&
      state !== 'success' &&
      state !== 'failed'
    ) {
      return { ...DEFAULT_BACKUP_STATUS };
    }
    return {
      state,
      ...(typeof value.phase === 'string' ? { phase: value.phase } : {}),
      ...(typeof value.lastAttemptAt === 'string'
        ? { lastAttemptAt: value.lastAttemptAt }
        : {}),
      ...(typeof value.lastSuccessAt === 'string'
        ? { lastSuccessAt: value.lastSuccessAt }
        : {}),
      ...(typeof value.lastWebDavSuccessAt === 'string'
        ? { lastWebDavSuccessAt: value.lastWebDavSuccessAt }
        : {}),
      ...(typeof value.nextRunAt === 'string'
        ? { nextRunAt: value.nextRunAt }
        : {}),
      ...(typeof value.lastFileName === 'string'
        ? { lastFileName: value.lastFileName }
        : {}),
      ...(typeof value.lastSizeBytes === 'number'
        ? { lastSizeBytes: value.lastSizeBytes }
        : {}),
      ...(typeof value.lastSha256 === 'string'
        ? { lastSha256: value.lastSha256 }
        : {}),
      ...(typeof value.lastError === 'string'
        ? { lastError: value.lastError }
        : {}),
    };
  }

  saveStatus(status: BackupStatus): void {
    this.writeJson(this.statusPath, status);
  }

  toDto(settings = this.loadSettings(), status = this.loadStatus()): BackupSettingsDto {
    return {
      enabled: settings.enabled,
      weekday: settings.weekday,
      time: settings.time,
      timezone: settings.timezone,
      webdav: {
        url: redactUrl(settings.webdavUrl),
        username: settings.username,
        remotePath: settings.remotePath,
        passwordConfigured: settings.password.trim().length > 0,
      },
      retention: {
        recentWeeks: settings.recentWeeks,
        monthlyMonths: settings.monthlyMonths,
      },
      status,
    };
  }

  private readJson(
    path: string,
    kind: BackupStoreCorruptionError['kind'],
  ): unknown {
    if (!existsSync(path)) return null;
    try {
      return JSON.parse(readFileSync(path, 'utf-8')) as unknown;
    } catch {
      this.quarantineCorruptFile(path);
      throw new BackupStoreCorruptionError(kind);
    }
  }

  private writeJson(path: string, value: unknown): void {
    const dir = dirname(path);
    mkdirSync(dir, { recursive: true, mode: 0o700 });
    chmodSync(dir, 0o700);
    const tempPath = `${path}.${randomUUID()}.tmp`;
    try {
      writeFileSync(tempPath, `${JSON.stringify(value, null, 2)}\n`, {
        encoding: 'utf-8',
        mode: 0o600,
        flag: 'wx',
      });
      chmodSync(tempPath, 0o600);
      const fileDescriptor = openSync(tempPath, 'r');
      try {
        fsyncSync(fileDescriptor);
      } finally {
        closeSync(fileDescriptor);
      }
      renameSync(tempPath, path);
      chmodSync(path, 0o600);
      const directoryDescriptor = openSync(dir, 'r');
      try {
        fsyncSync(directoryDescriptor);
      } finally {
        closeSync(directoryDescriptor);
      }
    } catch (error) {
      try {
        unlinkSync(tempPath);
      } catch (cleanupError) {
        if (!isMissingFileError(cleanupError)) {
          console.warn('备份配置临时文件清理失败');
        }
      }
      throw error;
    }
  }

  private quarantineCorruptFile(path: string): void {
    const quarantinePath = `${path}.corrupt-${Date.now()}-${randomUUID()}`;
    try {
      renameSync(path, quarantinePath);
      chmodSync(quarantinePath, 0o600);
    } catch {
      console.warn('备份配置损坏且无法隔离');
    }
  }
}

export function normalizeSettings(raw: unknown): BackupSettings {
  const value = raw && typeof raw === 'object' ? (raw as Record<string, unknown>) : {};
  const weekday = toInteger(value.weekday, DEFAULT_BACKUP_SETTINGS.weekday);
  const time = typeof value.time === 'string' && isValidTime(value.time)
    ? value.time
    : DEFAULT_BACKUP_SETTINGS.time;
  const remotePath = normalizeRemotePath(value.remotePath);
  return {
    enabled: value.enabled === true,
    weekday: weekday >= 0 && weekday <= 6 ? weekday : DEFAULT_BACKUP_SETTINGS.weekday,
    time,
    timezone: 'Asia/Shanghai',
    webdavUrl: typeof value.webdavUrl === 'string' ? value.webdavUrl.trim() : '',
    username: typeof value.username === 'string' ? value.username.trim() : '',
    password: typeof value.password === 'string' ? value.password : '',
    remotePath,
    recentWeeks: 8,
    monthlyMonths: 12,
  };
}

export function mergeSettings(
  current: BackupSettings,
  input: BackupSettingsInput,
): BackupSettings {
  const password =
    input.clearPassword === true
      ? ''
      : typeof input.password === 'string'
        ? input.password
        : current.password;
  return normalizeSettings({
    ...current,
    enabled: input.enabled ?? current.enabled,
    weekday: input.weekday ?? current.weekday,
    time: input.time ?? current.time,
    webdavUrl: input.webdavUrl ?? current.webdavUrl,
    username: input.username ?? current.username,
    remotePath: input.remotePath ?? current.remotePath,
    password,
  });
}

export function validateWebDavConfiguration(settings: BackupSettings): string | null {
  const baseError = validateSettings({ ...settings, enabled: false });
  if (baseError) return baseError;
  if (!settings.webdavUrl || !settings.username || !settings.password) {
    return '请完成 WebDAV 地址、用户名和应用密码配置';
  }
  return null;
}

export function validateSettings(settings: BackupSettings): string | null {
  if (settings.weekday < 0 || settings.weekday > 6) return '备份星期无效';
  if (!isValidTime(settings.time)) return '备份时间无效';
  if (!settings.remotePath.startsWith('/') || settings.remotePath.includes('..')) {
    return 'WebDAV 远程目录无效';
  }
  if (!settings.webdavUrl && settings.enabled) return '启用自动备份前请配置 WebDAV';
  if (settings.webdavUrl) {
    try {
      const url = new URL(settings.webdavUrl);
      if (url.protocol !== 'https:') return 'WebDAV 必须使用 HTTPS 地址';
      if (url.username || url.password) return 'WebDAV 地址不能包含用户名或密码';
    } catch {
      return 'WebDAV 地址无效';
    }
  }
  if (settings.enabled && (!settings.username || !settings.password)) {
    return '启用自动备份前请完成 WebDAV 配置';
  }
  return null;
}

function normalizeRemotePath(value: unknown): string {
  if (typeof value !== 'string' || !value.trim()) return DEFAULT_BACKUP_SETTINGS.remotePath;
  let path = value.trim().replace(/\\/g, '/');
  if (!path.startsWith('/')) path = `/${path}`;
  path = path.replace(/\/+/g, '/');
  while (path.length > 1 && path.endsWith('/')) path = path.slice(0, -1);
  return path.includes('..') ? DEFAULT_BACKUP_SETTINGS.remotePath : path;
}

function isValidTime(value: string): boolean {
  const match = /^(\d{2}):(\d{2})$/.exec(value);
  if (!match) return false;
  const hour = Number(match[1]);
  const minute = Number(match[2]);
  return hour >= 0 && hour <= 23 && minute >= 0 && minute <= 59;
}

function toInteger(value: unknown, fallback: number): number {
  return typeof value === 'number' && Number.isInteger(value) ? value : fallback;
}

function redactUrl(value: string): string {
  if (!value) return '';
  try {
    const url = new URL(value);
    url.username = '';
    url.password = '';
    return url.toString().replace(/\/$/, '');
  } catch {
    return '';
  }
}

function getConfiguredDataDir(): string {
  return serverDataDir || join(process.cwd(), 'data');
}

function isMissingFileError(error: unknown): boolean {
  return error instanceof Error && 'code' in error && error.code === 'ENOENT';
}
