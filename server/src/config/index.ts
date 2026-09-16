import { existsSync, readFileSync } from 'fs';
import { dirname, join } from 'path';
import { fileURLToPath } from 'url';

export interface Config {
  vaultPath: string;
  apiToken: string;
  port: number;
  allowedOrigins?: string[];
}

const configPath = fileURLToPath(new URL('../../config.json', import.meta.url));
export const serverDataDir = join(dirname(configPath), 'data');

if (!existsSync(configPath)) {
  throw new Error('Missing server/config.json. Copy config.example.json and set local values.');
}

const config = JSON.parse(readFileSync(configPath, 'utf-8')) as Config;

if (!config.vaultPath || !config.apiToken || config.apiToken === 'REPLACE_WITH_A_RANDOM_TOKEN') {
  throw new Error('Invalid server/config.json. Set vaultPath and a private apiToken.');
}

export default config;
