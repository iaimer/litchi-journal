import express from 'express';
import cors from 'cors';
import type { CorsOptions } from 'cors';
import { authMiddleware } from './middleware/auth.js';
import diaryRoutes from './routes/diary.js';
import habitRoutes from './routes/habit.js';
import historyRoutes from './routes/history.js';
import settingsRoutes from './routes/settings.js';
import { createBackupRouter } from './routes/backups.js';
import { BackupService } from './services/backup_service.js';
import config from './config/index.js';

const app = express();

const corsOptions: CorsOptions = {
  origin(origin, callback) {
    const allowedOrigins = config.allowedOrigins ?? [];
    if (
      !origin ||
      allowedOrigins.length === 0 ||
      allowedOrigins.includes(origin)
    ) {
      callback(null, true);
      return;
    }
    callback(new Error('Not allowed by CORS'));
  },
};

app.use(cors(corsOptions));
app.use(express.json({ limit: '10mb' }));

app.get('/health', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

app.use(authMiddleware);

app.use('/api/v1/diary', diaryRoutes);
app.use('/api/v1/stats', habitRoutes);
app.use('/api/v1/history', historyRoutes);
app.use('/api/v1/settings', settingsRoutes);

const backupService = new BackupService({ vaultPath: config.vaultPath });
backupService.start();
app.use('/api/v1', createBackupRouter(backupService));

const PORT = config.port;
app.listen(PORT, () => {
  console.log(`Diary API Server running on port ${PORT}`);
  console.log(`Vault path: ${config.vaultPath}`);
});

export { app, backupService };
