import { rmSync } from 'node:fs';
import { afterAll, beforeAll, expect, it, vi } from 'vitest';
import type { Server } from 'node:http';
import { gzipSync } from 'node:zlib';
const fixture = await vi.hoisted(async () => {
 const {mkdtempSync}=await import('node:fs'); const {tmpdir}=await import('node:os'); const {join}=await import('node:path');
 return {root:mkdtempSync(join(tmpdir(),'litchi-app-test-'))};
});
vi.mock('./config/index.js', () => ({ default: {
  vaultPath: fixture.root, apiToken: 'dummy-token', allowedOrigins: [],
} }));
vi.mock('./services/vault.js', async original => ({
  ...await original<typeof import('./services/vault.js')>(),
  readDiary: () => {throw new Error('private-filesystem-path');},
  listMonthDiaries: () => {throw new Error('private-filesystem-path');},
  listDiaryMonths: () => {throw new Error('private-filesystem-path');},
}));
import app from './app.js';
let server: Server;
let url: string;
beforeAll(async () => {
  server = await new Promise<Server>(resolve => {
    const listening = app.listen(0, '127.0.0.1', () => resolve(listening));
  });
  const address = server.address();
  if (!address || typeof address === 'string') throw new Error('Missing listener');
  url = `http://127.0.0.1:${address.port}`;
});
afterAll(() => new Promise<void>((resolve, reject) => server.close(e => {rmSync(fixture.root,{recursive:true,force:true}); e ? reject(e) : resolve();})));
it.each(['{', 'invalid-gzip'])('rejects unauthenticated body before parsing: %s', async body => {
  const response = await fetch(`${url}/api/v1/diary/create`, {
    method: 'POST', headers: {'content-type':'application/json',
      ...(body === 'invalid-gzip' ? {'content-encoding':'gzip'} : {})}, body,
  });
  expect(response.status).toBe(401);
});
it('preserves health, preflight and authenticated parsing', async () => {
  expect((await fetch(`${url}/health`)).status).toBe(200);
  expect((await fetch(`${url}/api/v1/diary/create`, {method:'OPTIONS', headers:{origin:'https://example.test','access-control-request-method':'POST'}})).status).toBe(204);
  for (const body of ['{', 'invalid-gzip']) {
    expect((await fetch(`${url}/api/v1/diary/create`, {method:'POST', headers:{authorization:'Token dummy-token','content-type':'application/json',...(body === 'invalid-gzip' ? {'content-encoding':'gzip'} : {})},body})).status).toBe(400);
  }
  expect((await fetch(`${url}/api/v1/diary/create`, {method:'POST', headers:{authorization:'Token dummy-token','content-type':'application/json','content-encoding':'gzip'},body:gzipSync('{"date":"invalid"}')})).status).toBe(400);
});

it.each(['/api/v1/history/gallery','/api/v1/history/2024/08','/api/v1/stats/habit?days=all'])('sanitizes filesystem errors: %s', async path => {
 const response=await fetch(url+path,{headers:{authorization:'Token dummy-token'}});
 expect(response.status).toBe(500);
 expect(await response.text()).not.toContain('private-filesystem-path');
});
