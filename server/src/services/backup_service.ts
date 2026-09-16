import { existsSync } from 'fs';
import type { Response } from 'express';
import { createReadStream } from 'fs';
import { pipeline } from 'stream/promises';
import {
  BackupSourceChangedError,
  BackupSourceUnavailableError,
  cleanupStaleBackupArchives,
  createBackupArchive,
  removeBackupArchive,
} from './backup_archive.js';
import {
  BackupSettings,
  BackupSettingsDto,
  BackupSettingsInput,
  BackupStatus,
  BackupStore,
  BackupStoreCorruptionError,
  mergeSettings,
  validateSettings,
  validateWebDavConfiguration,
} from './backup_store.js';
import {
  createWebDavBackupClient,
  WebDavBackupClient,
  WebDavBackupError,
} from './webdav_backup.js';

export class BackupBusyError extends Error {
  constructor() {
    super('备份任务正在运行');
    this.name = 'BackupBusyError';
  }
}

export class BackupConfigurationError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'BackupConfigurationError';
  }
}

export interface BackupServiceOptions {
  vaultPath: string;
  store?: BackupStore;
  now?: () => Date;
  createWebDavClient?: (settings: BackupSettings) => WebDavBackupClient;
  createArchive?: (vaultPath: string, now: Date) => ReturnType<typeof createBackupArchive>;
}

export interface ExportArchiveHandle {
  archivePath: string;
  fileName: string;
  sizeBytes: number;
  sha256: string;
}

const RETRY_DELAYS_MS = [15 * 60_000, 60 * 60_000, 6 * 60 * 60_000, 24 * 60 * 60_000];

export class BackupService {
  private readonly vaultPath: string;
  private readonly store: BackupStore;
  private readonly now: () => Date;
  private readonly createWebDavClient: (settings: BackupSettings) => WebDavBackupClient;
  private readonly createArchive: BackupServiceOptions['createArchive'];
  private timer: NodeJS.Timeout | null = null;
  private retryTimer: NodeJS.Timeout | null = null;
  private running = false;
  private started = false;
  private retryIndex = 0;
  private pendingWebDavRun = false;

  constructor(options: BackupServiceOptions) {
    this.vaultPath = options.vaultPath;
    this.store = options.store ?? new BackupStore();
    this.now = options.now ?? (() => new Date());
    this.createWebDavClient = options.createWebDavClient ?? createWebDavBackupClient;
    this.createArchive = options.createArchive ?? ((vaultPath, now) => createBackupArchive(vaultPath, now));
  }

  start(): void {
    if (this.started) return;
    this.started = true;
    try {
      cleanupStaleBackupArchives();
    } catch {
      this.writeSafeFailure('服务器临时备份文件清理失败，请检查磁盘权限');
    }
    try {
      this.recoverAfterRestart();
      this.scheduleNextRun(true);
    } catch (error) {
      if (error instanceof BackupStoreCorruptionError) {
        this.writeSafeFailure(error.message);
        this.scheduleNextRun(false);
        return;
      }
      throw error;
    }
  }

  stop(): void {
    this.started = false;
    if (this.timer) clearTimeout(this.timer);
    if (this.retryTimer) clearTimeout(this.retryTimer);
    this.timer = null;
    this.retryTimer = null;
  }

  getDto(): BackupSettingsDto {
    return this.store.toDto(this.store.loadSettings(), this.store.loadStatus());
  }

  updateSettings(input: BackupSettingsInput): BackupSettingsDto {
    const current = this.store.loadSettings();
    const next = mergeSettings(current, input);
    const error = validateSettings(next);
    if (error) throw new BackupConfigurationError(error);
    this.store.saveSettings(input);
    this.retryIndex = 0;
    if (this.retryTimer) clearTimeout(this.retryTimer);
    this.retryTimer = null;
    if (!next.enabled) this.pendingWebDavRun = false;
    this.scheduleNextRun(false);
    return this.getDto();
  }

  async testConnection(input: BackupSettingsInput): Promise<void> {
    const settings = mergeSettings(this.store.loadSettings(), input);
    const error = validateWebDavConfiguration(settings);
    if (error) throw new BackupConfigurationError(error);
    const client = this.createWebDavClient(settings);
    await client.testConnection();
  }

  startManualBackup(): void {
    if (this.running) throw new BackupBusyError();
    void this.executeWebDavBackup();
  }

  async createExportArchive(): Promise<ExportArchiveHandle> {
    this.ensureAvailable();
    this.running = true;
    this.writeStatus({ state: 'running', phase: '正在准备 ZIP 导出' });
    try {
      const archive = await this.createArchive!(this.vaultPath, this.now());
      return {
        archivePath: archive.path,
        fileName: archive.fileName,
        sizeBytes: archive.sizeBytes,
        sha256: archive.sha256,
      };
    } catch (error) {
      this.running = false;
      this.writeFailure(error);
      throw error;
    }
  }

  async finishExport(archive: ExportArchiveHandle, success: boolean): Promise<void> {
    let cleanupFailed = false;
    try {
      removeBackupArchive(archive.archivePath);
    } catch {
      cleanupFailed = true;
    }
    this.running = false;
    if (cleanupFailed) {
      this.writeStatus({
        ...this.store.loadStatus(),
        state: 'failed',
        phase: undefined,
        lastError: '手机导出已结束，但服务器临时文件清理失败',
      });
    } else if (!success) {
      this.writeStatus({
        ...this.store.loadStatus(),
        state: 'failed',
        phase: undefined,
        lastError: '手机导出失败，请重试',
      });
    } else {
      this.writeStatus({
        ...this.store.loadStatus(),
        state: 'success',
        phase: undefined,
        lastSuccessAt: this.now().toISOString(),
        lastFileName: archive.fileName,
        lastSizeBytes: archive.sizeBytes,
        lastSha256: archive.sha256,
        lastError: undefined,
      });
    }
    this.drainPendingOrSchedule();
  }

  async streamExport(res: Response): Promise<void> {
    const archive = await this.createExportArchive();
    res.statusCode = 200;
    res.setHeader('Content-Type', 'application/zip');
    res.setHeader('Content-Disposition', `attachment; filename="${archive.fileName}"`);
    res.setHeader('Content-Length', String(archive.sizeBytes));
    res.setHeader('Cache-Control', 'no-store');
    res.setHeader('Pragma', 'no-cache');
    res.setHeader('X-Content-Type-Options', 'nosniff');
    try {
      await pipeline(createReadStream(archive.archivePath), res);
      await this.finishExport(archive, true);
    } catch (error) {
      await this.finishExport(archive, false);
      throw error;
    }
  }

  private async executeWebDavBackup(): Promise<void> {
    if (this.running) {
      this.pendingWebDavRun = true;
      return;
    }
    this.running = true;
    const attemptAt = this.now().toISOString();
    this.writeStatus({
      ...this.store.loadStatus(),
      state: 'running',
      phase: '正在打包日记和图片',
      lastAttemptAt: attemptAt,
      lastError: undefined,
    });

    let archivePath: string | null = null;
    try {
      const settings = this.store.loadSettings();
      const configError = validateWebDavConfiguration(settings);
      if (configError) throw new BackupConfigurationError(configError);
      const archive = await this.createArchive!(this.vaultPath, this.now());
      archivePath = archive.path;
      this.writeStatus({ ...this.store.loadStatus(), state: 'running', phase: '正在上传 WebDAV' });
      const client = this.createWebDavClient(settings);
      await client.uploadArchive(archive, this.now());
      const completedAt = this.now().toISOString();
      this.retryIndex = 0;
      if (this.retryTimer) clearTimeout(this.retryTimer);
      this.retryTimer = null;
      this.writeStatus({
        ...this.store.loadStatus(),
        state: 'success',
        phase: undefined,
        lastSuccessAt: completedAt,
        lastWebDavSuccessAt: completedAt,
        lastFileName: archive.fileName,
        lastSizeBytes: archive.sizeBytes,
        lastSha256: archive.sha256,
        lastError: undefined,
      });
    } catch (error) {
      this.writeFailure(error);
      this.scheduleRetry();
    } finally {
      let cleanupFailed = false;
      if (archivePath) {
        try {
          removeBackupArchive(archivePath);
        } catch {
          cleanupFailed = true;
        }
      }
      this.running = false;
      if (cleanupFailed) {
        this.writeStatus({
          ...this.store.loadStatus(),
          state: 'failed',
          phase: undefined,
          lastError: 'WebDAV 备份已上传，但服务器临时文件清理失败',
        });
      }
      this.drainPendingOrSchedule();
    }
  }

  private writeFailure(error: unknown): void {
    const message = error instanceof BackupConfigurationError
      ? error.message
      : error instanceof WebDavBackupError
        ? error.message
        : error instanceof BackupSourceChangedError
          ? 'ZIP 打包失败，日记文件在打包期间发生变化，请重试'
          : error instanceof BackupSourceUnavailableError
            ? error.message
            : 'ZIP 打包失败，请稍后重试';
    this.writeStatus({
      ...this.store.loadStatus(),
      state: 'failed',
      phase: undefined,
      lastError: message,
    });
  }

  private writeStatus(partial: BackupStatus): void {
    this.store.saveStatus({
      ...this.store.loadStatus(),
      ...partial,
    });
  }

  private recoverAfterRestart(): void {
    const status = this.store.loadStatus();
    if (status.state === 'running') {
      this.writeStatus({
        ...status,
        state: 'failed',
        phase: undefined,
        lastError: '服务重启导致备份中断，请重新执行',
      });
    }
  }

  private scheduleNextRun(checkCatchup: boolean): void {
    if (this.timer) clearTimeout(this.timer);
    this.timer = null;
    const settings = this.store.loadSettings();
    if (!settings.enabled || validateSettings(settings)) {
      this.writeStatus({ ...this.store.loadStatus(), nextRunAt: undefined });
      return;
    }

    const now = this.now();
    const next = getNextScheduledRun(now, settings.weekday, settings.time);
    this.writeStatus({ ...this.store.loadStatus(), nextRunAt: next.toISOString() });

    if (checkCatchup) {
      const previous = getPreviousScheduledRun(now, settings.weekday, settings.time);
      const lastSuccess = this.store.loadStatus().lastWebDavSuccessAt;
      if (!lastSuccess || new Date(lastSuccess).getTime() < previous.getTime()) {
        this.timer = setTimeout(() => this.requestWebDavBackup(), 1000);
        return;
      }
    }

    const delay = Math.max(1000, next.getTime() - now.getTime());
    this.timer = setTimeout(() => this.requestWebDavBackup(), delay);
  }

  private scheduleRetry(): void {
    if (this.retryTimer) clearTimeout(this.retryTimer);
    const settings = this.store.loadSettings();
    if (!settings.enabled || validateSettings(settings)) {
      this.retryTimer = null;
      return;
    }
    const delay = RETRY_DELAYS_MS[Math.min(this.retryIndex, RETRY_DELAYS_MS.length - 1)];
    this.retryIndex += 1;
    this.retryTimer = setTimeout(() => {
      this.retryTimer = null;
      this.requestWebDavBackup();
    }, delay);
  }

  private ensureAvailable(): void {
    if (this.running) throw new BackupBusyError();
    if (!existsSync(this.vaultPath)) throw new BackupConfigurationError('日记目录不可用');
  }

  private requestWebDavBackup(): void {
    if (this.running) {
      this.pendingWebDavRun = true;
      return;
    }
    void this.executeWebDavBackup();
  }

  private drainPendingOrSchedule(): void {
    if (this.pendingWebDavRun) {
      this.pendingWebDavRun = false;
      const settings = this.store.loadSettings();
      if (settings.enabled && !validateSettings(settings)) {
        setTimeout(() => this.requestWebDavBackup(), 0);
        return;
      }
    }
    this.scheduleNextRun(false);
  }

  private writeSafeFailure(message: string): void {
    try {
      this.store.saveStatus({ state: 'failed', lastError: message });
    } catch {
      console.warn('备份状态写入失败');
    }
  }
}

export function getShanghaiParts(date: Date): { year: number; month: number; day: number } {
  const formatter = new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Asia/Shanghai',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  });
  const parts = Object.fromEntries(formatter.formatToParts(date).map(part => [part.type, part.value]));
  return { year: Number(parts.year), month: Number(parts.month), day: Number(parts.day) };
}

export function getNextScheduledRun(now: Date, weekday: number, time: string): Date {
  return getScheduledRun(now, weekday, time, false);
}

export function getPreviousScheduledRun(now: Date, weekday: number, time: string): Date {
  return getScheduledRun(now, weekday, time, true);
}

function getScheduledRun(now: Date, weekday: number, time: string, previous: boolean): Date {
  const parts = getShanghaiParts(now);
  const [hour, minute] = time.split(':').map(Number);
  const todayLocal = Date.UTC(parts.year, parts.month - 1, parts.day);
  const todayWeekday = new Date(todayLocal).getUTCDay();
  let delta = previous
    ? (todayWeekday - weekday + 7) % 7
    : (weekday - todayWeekday + 7) % 7;
  let candidateLocal = todayLocal + (previous ? -delta : delta) * 24 * 60 * 60 * 1000;
  candidateLocal += (hour * 60 + minute) * 60 * 1000;
  let candidate = new Date(candidateLocal - 8 * 60 * 60 * 1000);
  if ((!previous && candidate.getTime() <= now.getTime()) || (previous && candidate.getTime() > now.getTime())) {
    candidateLocal += (previous ? -7 : 7) * 24 * 60 * 60 * 1000;
    candidate = new Date(candidateLocal - 8 * 60 * 60 * 1000);
  }
  return candidate;
}
