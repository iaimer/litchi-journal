import { validateApiToken } from './token.js';
import { existsSync, readFileSync } from 'fs';
import { fileURLToPath } from 'url';

interface Config {
  vaultPath: string;
  apiToken: string;
  port: number;
  allowedOrigins?: string[];
}

const configPath = fileURLToPath(new URL('../../config.json', import.meta.url));

if (!existsSync(configPath)) {
  throw new Error('Missing server/config.json. Copy config.example.json and set local values.');
}

const config = JSON.parse(readFileSync(configPath, 'utf-8')) as Config;

if (typeof config.vaultPath !== 'string' || !config.vaultPath.trim()) {
  throw new Error('Invalid server/config.json. Set vaultPath and a private apiToken.');
}

config.apiToken = validateApiToken(config.apiToken);

export default config;
