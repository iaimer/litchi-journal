import { timingSafeEqual } from 'crypto';
import { Request, Response, NextFunction } from 'express';
import config from '../config/index.js';

export function authMiddleware(req: Request, res: Response, next: NextFunction) {
  const authHeader = req.headers.authorization;

  if (!authHeader) {
    return res.status(401).json({ error: 'Missing Authorization header' });
  }

  if (!authHeader.startsWith('Token ')) {
    return res.status(401).json({ error: 'Invalid Authorization scheme' });
  }

  const token = authHeader.slice('Token '.length).trim();
  if (!isTokenValid(token, config.apiToken)) {
    return res.status(401).json({ error: 'Invalid token' });
  }

  next();
}

function isTokenValid(token: string, expectedToken: string) {
  if (!token || !expectedToken) return false;

  const tokenBuffer = Buffer.from(token);
  const expectedBuffer = Buffer.from(expectedToken);
  if (tokenBuffer.length !== expectedBuffer.length) return false;

  return timingSafeEqual(tokenBuffer, expectedBuffer);
}
