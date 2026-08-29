import { afterAll, beforeEach, describe, expect, it, vi } from 'vitest';
import {
  existsSync,
  mkdirSync,
  rmSync,
  writeFileSync,
} from 'fs';
import { join } from 'path';

const testConfig = vi.hoisted(() => ({
  vaultPath: `/private/tmp/litchi-diary-image-route-${process.pid}`,
}));

vi.mock('../config/index.js', () => ({
  default: {
    vaultPath: testConfig.vaultPath,
    apiToken: 'test-token',
    port: 0,
  },
}));

import diaryRoutes from './diary.js';

type Handler = (req: unknown, res: any) => Promise<void>;

function imageHandler(): Handler {
  const stack = (diaryRoutes as any).stack as any[];
  const layer = stack.find(
    item => item.route?.path === '/image/render/:year/:imageName',
  );
  return layer.route.stack[0].handle as Handler;
}

function response() {
  return {
    statusCode: 200,
    headers: {} as Record<string, string>,
    body: undefined as unknown,
    status(code: number) {
      this.statusCode = code;
      return this;
    },
    json(body: unknown) {
      this.body = body;
      return this;
    },
    type(value: string) {
      this.headers['content-type'] = value;
      return this;
    },
    set(name: string, value: string) {
      this.headers[name.toLowerCase()] = value;
      return this;
    },
    send(body: unknown) {
      this.body = body;
      return this;
    },
  };
}

function assetsDir(year: number, month: number): string {
  return join(
    testConfig.vaultPath,
    '01.日记',
    String(year),
    `${month.toString().padStart(2, '0')}.${month === 3 ? 'March' : 'August'}`,
    'assets',
  );
}

describe('rendered diary image route', () => {
  beforeEach(() => {
    rmSync(testConfig.vaultPath, { recursive: true, force: true });
    mkdirSync(assetsDir(2024, 3), { recursive: true });
  });

  afterAll(() => {
    rmSync(testConfig.vaultPath, { recursive: true, force: true });
  });

  it('returns an oriented, resized WebP binary for a valid image', async () => {
    const source = Buffer.from(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
      'base64',
    );
    writeFileSync(join(assetsDir(2024, 3), 'first.png'), source);

    const res = response();
    await imageHandler()(
      {
        params: { year: '2024', imageName: 'first.png' },
        query: { month: '3', maxWidth: '480' },
      },
      res,
    );

    expect(res.statusCode).toBe(200);
    expect(res.headers['content-type']).toBe('image/webp');
    expect(Buffer.isBuffer(res.body)).toBe(true);
    expect((res.body as Buffer).length).toBeGreaterThan(0);
  });

  it('falls back to the original binary when resizing fails', async () => {
    const source = Buffer.from('not-a-decodable-image');
    writeFileSync(join(assetsDir(2024, 3), 'broken.jpg'), source);

    const res = response();
    await imageHandler()(
      {
        params: { year: '2024', imageName: 'broken.jpg' },
        query: { month: '3', maxWidth: '480' },
      },
      res,
    );

    expect(res.statusCode).toBe(200);
    expect(res.headers['content-type']).toBe('image/jpeg');
    expect(res.body).toEqual(source);
  });

  it('rejects unsafe names, invalid widths, and missing files', async () => {
    const unsafe = response();
    await imageHandler()(
      {
        params: { year: '2024', imageName: '../secret.jpg' },
        query: { month: '3', maxWidth: '480' },
      },
      unsafe,
    );
    expect(unsafe.statusCode).toBe(400);

    const controlCharacter = response();
    await imageHandler()(
      {
        params: { year: '2024', imageName: 'bad\u0000.jpg' },
        query: { month: '3', maxWidth: '480' },
      },
      controlCharacter,
    );
    expect(controlCharacter.statusCode).toBe(400);

    const invalidWidth = response();
    await imageHandler()(
      {
        params: { year: '2024', imageName: 'missing.jpg' },
        query: { month: '3', maxWidth: '32' },
      },
      invalidWidth,
    );
    expect(invalidWidth.statusCode).toBe(400);

    const missing = response();
    await imageHandler()(
      {
        params: { year: '2024', imageName: 'missing.jpg' },
        query: { month: '3', maxWidth: '480' },
      },
      missing,
    );
    expect(missing.statusCode).toBe(404);
    expect(existsSync(join(assetsDir(2024, 3), 'missing.jpg'))).toBe(false);
  });
});
