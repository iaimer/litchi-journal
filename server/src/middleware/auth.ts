import { Request, Response, NextFunction } from 'express';
import config from '../config/index.js';

export function authMiddleware(req: Request, res: Response, next: NextFunction) {
  const authHeader = req.headers.authorization;

  if (!authHeader) {
    return res.status(401).json({ error: 'Missing Authorization header' });
  }

  const token = authHeader.replace('Token ', '');

  if (token !== config.apiToken) {
    return res.status(401).json({ error: 'Invalid token' });
  }

  next();
}