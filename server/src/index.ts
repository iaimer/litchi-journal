import express from 'express';
import cors from 'cors';
import { authMiddleware } from './middleware/auth.js';
import diaryRoutes from './routes/diary.js';
import habitRoutes from './routes/habit.js';
import historyRoutes from './routes/history.js';
import settingsRoutes from './routes/settings.js';
import config from './config/index.js';

const app = express();

app.use(cors());
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
});