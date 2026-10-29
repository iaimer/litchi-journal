import express from 'express';
import type { Server } from 'node:http';
import { existsSync, readdirSync, mkdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { afterAll, beforeAll, beforeEach, describe, expect, it, vi } from 'vitest';

const fixture = await vi.hoisted(async () => {
  const { mkdtempSync } = await import('node:fs');
  const { tmpdir } = await import('node:os');
  const { join } = await import('node:path');
  return { vaultPath: mkdtempSync(join(tmpdir(), 'litchi-settings-')) };
});
vi.mock('../config/index.js', () => ({ default: fixture }));
import settingsRoutes from './settings.js';

let server: Server;
let baseUrl: string;
const tagPath = () => join(fixture.vaultPath, '.litchi-journal', 'tag-system.json');
const templatePath = () => join(fixture.vaultPath, '_Templates', '标签规范.md');
const validConfig = {
  domains: [{ id: 'life', name: '生活', topics: [{ id: 'daily', name: '日常' }] }],
  methods: [{ id: 'reflect', name: '反思' }],
};

beforeAll(async () => {
  const app = express();
  app.use(express.json());
  app.use('/settings', settingsRoutes);
  server = await new Promise<Server>((resolve) => {
    const listening = app.listen(0, '127.0.0.1', () => resolve(listening));
  });
  const address = server.address();
  if (address == null || typeof address === 'string') throw new Error('Missing test listener');
  baseUrl = `http://127.0.0.1:${address.port}/settings/tags`;
});

beforeEach(() => {
  for (const name of ['.litchi-journal', '_Templates']) {
    rmSync(join(fixture.vaultPath, name), { recursive: true, force: true });
  }
});

afterAll(async () => {
  await new Promise<void>((resolve, reject) => server.close(error => error ? reject(error) : resolve()));
  rmSync(fixture.vaultPath, { recursive: true, force: true });
});

const put = (body: unknown) => fetch(baseUrl, {
  method: 'PUT', headers: { 'content-type': 'application/json' }, body: JSON.stringify(body),
});

describe('settings tags HTTP routes using a temporary Vault', () => {
  it('loads defaults on first access and persists a readable configuration', async () => {
    const response = await fetch(baseUrl);
    expect(response.status).toBe(200);
    const config = await response.json();
    expect(config.domains.length).toBeGreaterThan(0);
    expect(config.methods.length).toBeGreaterThan(0);
    expect(existsSync(tagPath())).toBe(false);
  });

  it('round-trips settings and preserves manual template text on repeated saves', async () => {
    mkdirSync(join(fixture.vaultPath, '_Templates'), { recursive: true });
    writeFileSync(templatePath(), '# 人工规范\n\n保留这段说明\n');
    expect((await put(validConfig)).status).toBe(200);
    const updated = { ...validConfig, methods: [{ id: 'remember', name: '回忆' }] };
    expect((await put(updated)).status).toBe(200);
    expect(await (await fetch(baseUrl)).json()).toEqual(updated);
    const template = readFileSync(templatePath(), 'utf-8');
    expect(template).toContain('保留这段说明');
    expect(template).toContain('**#回忆**');
    expect(template).not.toContain('**#反思**');
    expect(template.split('<!-- litchi-journal-tag-config:start -->')).toHaveLength(2);
  });

  it.each([
    { domains: [], methods: [] },
    { domains: [{ name: '生活', topics: [{ name: '生活' }] }], methods: [] },
    { domains: [{ name: '#错误', topics: [{ name: '日常' }] }], methods: [] },
  ])('rejects invalid tags without changing stored configuration: %j', async body => {
    await put(validConfig);
    const beforeConfig = readFileSync(tagPath(), 'utf-8');
    const beforeTemplate = readFileSync(templatePath(), 'utf-8');
    expect((await put(body)).status).toBe(400);
    expect(readFileSync(tagPath(), 'utf-8')).toBe(beforeConfig);
    expect(readFileSync(templatePath(), 'utf-8')).toBe(beforeTemplate);
  });
});

it('keeps corrupt bytes on GET and preserves them on successful PUT', async () => {
  mkdirSync(join(fixture.vaultPath, '.litchi-journal'), {recursive:true});
  writeFileSync(tagPath(), '{broken');
  expect((await fetch(baseUrl)).status).toBe(200);
  expect(readFileSync(tagPath(), 'utf8')).toBe('{broken');
  expect((await put(validConfig)).status).toBe(200);
  const saved = readdirSync(join(fixture.vaultPath, '.litchi-journal')).find(n => n.includes('.corrupt-'))!;
  expect(readFileSync(join(fixture.vaultPath, '.litchi-journal', saved), 'utf8')).toBe('{broken');
});
it('reports saved config when template fails and allows retry', async () => {
  writeFileSync(join(fixture.vaultPath, '_Templates'), 'blocked');
  const response = await put(validConfig);
  expect(response.status).toBe(200);
  expect(await response.json()).toEqual({success:true,warnings:['TAG_TEMPLATE_SYNC_FAILED']});
  expect(await (await fetch(baseUrl)).json()).toEqual(validConfig);
  rmSync(join(fixture.vaultPath, '_Templates'));
  expect(await (await put(validConfig)).json()).toEqual({success:true});
});
it.each([null, {domains:[null], methods:[]}, {domains:[{name:'生活', topics:[null]}],methods:[]}])('rejects malformed schema', async body => {
  expect((await put(body)).status).toBe(400);
});

it('preserves invalid UTF8 bytes in quarantine', async () => {
 mkdirSync(join(fixture.vaultPath,'.litchi-journal'),{recursive:true});
 const bytes=Buffer.from([0xff,0xfe,0x7b]); writeFileSync(tagPath(),bytes);
 expect((await put(validConfig)).status).toBe(200);
 const backup=readdirSync(join(fixture.vaultPath,'.litchi-journal')).find(n=>n.includes('.corrupt-'))!;
 expect(readFileSync(join(fixture.vaultPath,'.litchi-journal',backup))).toEqual(bytes);
});
