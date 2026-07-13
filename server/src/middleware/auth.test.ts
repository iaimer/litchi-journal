import { describe, expect, it, vi } from 'vitest';
import { Request, Response } from 'express';

vi.mock('../config/index.js', () => ({
  default: {
    apiToken: 'secret-token',
  },
}));

import { authMiddleware } from './auth.js';

function makeResponse() {
  const res = {
    statusCode: 200,
    body: undefined as unknown,
    status(code: number) {
      this.statusCode = code;
      return this;
    },
    json(body: unknown) {
      this.body = body;
      return this;
    },
  };
  return res as Response & { statusCode: number; body: unknown };
}

function runAuth(authorization?: string) {
  const req = {
    headers: {
      authorization,
    },
  } as Request;
  const res = makeResponse();
  const next = vi.fn();

  authMiddleware(req, res, next);

  return { res, next };
}

describe('authMiddleware', () => {
  it('accepts strict Token authorization header', () => {
    const { res, next } = runAuth('Token secret-token');

    expect(res.statusCode).toBe(200);
    expect(next).toHaveBeenCalledOnce();
  });

  it('rejects missing authorization header', () => {
    const { res, next } = runAuth();

    expect(res.statusCode).toBe(401);
    expect(next).not.toHaveBeenCalled();
  });

  it('rejects non-Token authorization scheme', () => {
    const { res, next } = runAuth('Bearer secret-token');

    expect(res.statusCode).toBe(401);
    expect(next).not.toHaveBeenCalled();
  });

  it('rejects partial token replacement attacks', () => {
    const { res, next } = runAuth('Token nope Token secret-token');

    expect(res.statusCode).toBe(401);
    expect(next).not.toHaveBeenCalled();
  });
});
