import app from './app.js';
import config from './config/index.js';
import { cleanupDiaryTemporaryFiles } from './services/vault-temp-cleanup.js';

const PORT = config.port;
app.listen(PORT, () => {
  console.log(`Diary API Server running on port ${PORT}`);
  console.log(`Vault path: ${config.vaultPath}`);
  void cleanupDiaryTemporaryFiles(config.vaultPath).catch(() => {
    console.warn('日记临时副本清理未完成，下次启动时重试');
  });
});
