import express from 'express';
import cors from 'cors';
import type { CorsOptions } from 'cors';
import { authMiddleware } from './middleware/auth.js';
import diaryRoutes from './routes/diary.js';
import habitRoutes from './routes/habit.js';
import historyRoutes from './routes/history.js';
import settingsRoutes from './routes/settings.js';
import config from './config/index.js';
import { cleanupDiaryTemporaryFiles } from './services/vault-temp-cleanup.js';

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

const PORT = config.port;
app.listen(PORT, () => {
  console.log(`Diary API Server running on port ${PORT}`);
  console.log(`Vault path: ${config.vaultPath}`);
  void cleanupDiaryTemporaryFiles(config.vaultPath).catch(() => {
    console.warn('日记临时副本清理未完成，下次启动时重试');
  });
});
