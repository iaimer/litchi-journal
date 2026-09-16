import { Router } from 'express';
import {
  BackupBusyError,
  BackupConfigurationError,
  BackupService,
} from '../services/backup_service.js';
import { WebDavBackupError } from '../services/webdav_backup.js';

export function createBackupRouter(service: BackupService): Router {
  const router = Router();

  router.get('/settings/backup', (_req, res) => {
    try {
      res.json(service.getDto());
    } catch {
      res.status(500).json({ error: '获取备份设置失败，请稍后重试' });
    }
  });

  router.put('/settings/backup', (req, res) => {
    try {
      res.json(service.updateSettings(req.body ?? {}));
    } catch (error) {
      if (error instanceof BackupConfigurationError) {
        res.status(400).json({ error: error.message });
        return;
      }
      res.status(500).json({ error: '备份设置保存失败，请稍后重试' });
    }
  });

  router.post('/settings/backup/test', async (req, res) => {
    try {
      await service.testConnection(req.body ?? {});
      res.json({ success: true });
    } catch (error) {
      if (error instanceof BackupConfigurationError || error instanceof WebDavBackupError) {
        res.status(400).json({ error: error.message });
        return;
      }
      res.status(500).json({ error: 'WebDAV 连接测试失败，请稍后重试' });
    }
  });

  router.post('/backups/webdav', (req, res) => {
    try {
      service.startManualBackup();
      res.status(202).json({ accepted: true });
    } catch (error) {
      if (error instanceof BackupBusyError) {
        res.status(409).json({ error: error.message });
        return;
      }
      res.status(500).json({ error: '备份任务启动失败，请稍后重试' });
    }
  });

  router.get('/backups/export', async (_req, res) => {
    try {
      await service.streamExport(res);
    } catch (error) {
      if (res.headersSent) return;
      if (error instanceof BackupBusyError) {
        res.status(409).json({ error: error.message });
        return;
      }
      if (error instanceof BackupConfigurationError) {
        res.status(400).json({ error: error.message });
        return;
      }
      res.status(500).json({ error: 'ZIP 导出失败，请稍后重试' });
    }
  });

  return router;
}
