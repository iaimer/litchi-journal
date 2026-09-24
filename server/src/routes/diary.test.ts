import { afterAll, beforeEach, describe, expect, it, vi } from 'vitest';
import {
  existsSync,
  mkdirSync,
  rmSync,
  symlinkSync,
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
import { readDiary, writeDiary } from '../services/vault.js';

type Handler = (req: unknown, res: any) => Promise<void>;

function imageHandler(): Handler {
  const stack = (diaryRoutes as any).stack as any[];
  const layer = stack.find(
    item => item.route?.path === '/image/render/:year/:imageName',
  );
  return layer.route.stack[0].handle as Handler;
}

function uploadImageHandler(): Handler {
  const stack = (diaryRoutes as any).stack as any[];
  const layer = stack.find(item => item.route?.path === '/image/upload');
  return layer.route.stack[0].handle as Handler;
}

function habitDurationHandler(): Handler {
  const stack = (diaryRoutes as any).stack as any[];
  const layer = stack.find(item => item.route?.path === '/habit/duration');
  return layer.route.stack[0].handle as Handler;
}

function diaryEntryHandler(path: string): Handler {
  const stack = (diaryRoutes as any).stack as any[];
  const layer = stack.find(item => item.route?.path === path);
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

  it('does not follow an image symlink outside the vault', async () => {
    const outsidePath = join(testConfig.vaultPath, '..', `outside-${process.pid}.jpg`);
    const linkedPath = join(assetsDir(2024, 3), 'linked.jpg');
    writeFileSync(outsidePath, Buffer.from('outside-vault-content'));
    symlinkSync(outsidePath, linkedPath);

    try {
      const res = response();
      await imageHandler()(
        {
          params: { year: '2024', imageName: 'linked.jpg' },
          query: { month: '3', maxWidth: '480' },
        },
        res,
      );

      expect(res.statusCode).toBe(404);
    } finally {
      rmSync(outsidePath, { force: true });
    }
  });
});

describe('habit duration route', () => {
  const date = new Date('2024-08-12T12:00:00+08:00');
  const content = [
    '# 今天',
    '',
    '## 🏃 习惯打卡',
    '- [ ] 📖 阅读/亲子共读 0 分钟',
    '',
    '## ✍️ 随手记 & 灵感',
  ].join('\n');

  beforeEach(() => {
    rmSync(testConfig.vaultPath, { recursive: true, force: true });
    writeDiary(date, content);
  });

  afterAll(() => {
    rmSync(testConfig.vaultPath, { recursive: true, force: true });
  });

  it('adds minutes, marks completion, and preserves the raw habit section', async () => {
    const res = response();
    await habitDurationHandler()(
      {
        body: {
          date: '2024-08-12',
          habitKey: 'reading',
          label: '📖 阅读/亲子共读 0 分钟',
          rawLine: '- [ ] 📖 阅读/亲子共读 0 分钟',
          minutes: 35,
          operation: 'add',
          dailyTargetMinutes: 30,
          operationId: '123e4567-e89b-12d3-a456-426614174000',
        },
      },
      res,
    );

    expect(res.statusCode).toBe(200);
    expect(res.body).toMatchObject({ minutes: 35, completed: true });
    const updated = readDiary(date);
    expect(updated).toContain('- [x] 📖 阅读/亲子共读 35 分钟');
    expect(updated).toContain('## ✍️ 随手记 & 灵感');
  });

  it('returns a complete deduplicated result without adding minutes twice', async () => {
    const request = {
      body: {
        date: '2024-08-12',
        habitKey: 'reading',
        label: '📖 阅读/亲子共读 0 分钟',
        rawLine: '- [ ] 📖 阅读/亲子共读 0 分钟',
        minutes: 15,
        operation: 'add',
        dailyTargetMinutes: 30,
        operationId: '123e4567-e89b-12d3-a456-426614174001',
      },
    };
    const first = response();
    await habitDurationHandler()(request, first);
    const second = response();
    await habitDurationHandler()(request, second);

    expect(second.statusCode).toBe(200);
    expect(second.body).toMatchObject({ dedup: true, minutes: 15 });
    expect(readDiary(date)).toContain('- [ ] 📖 阅读/亲子共读 15 分钟');
    expect(readDiary(date)).not.toContain('30 分钟');
  });

  it('inserts a custom duration row when the raw line is not present', async () => {
    const res = response();
    await habitDurationHandler()(
      {
        body: {
          date: '2024-08-12',
          habitKey: 'custom_language',
          label: '📝 法语听力',
          rawLine: '',
          minutes: 12,
          operation: 'add',
        },
      },
      res,
    );

    expect(res.statusCode).toBe(200);
    expect(readDiary(date)).toContain('- [x] 📝 法语听力 12 分钟');
  });
});

describe('multiline timeline entry routes', () => {
  const date = new Date('2024-08-12T12:00:00+08:00');
  const content = [
    '# 今天',
    '',
    '## ✍️ 随手记 & 灵感',
    '- **08:00** 早间第一段。',
    '',
    '早间第二段。 #早间',
    '- **18:00** 晚间第一段。',
    '',
    '晚间第二段。 #晚间',
    '',
    '## ✨ 每日小确幸',
  ].join('\n');

  beforeEach(() => {
    rmSync(testConfig.vaultPath, { recursive: true, force: true });
    writeDiary(date, content);
  });

  afterAll(() => {
    rmSync(testConfig.vaultPath, { recursive: true, force: true });
  });

  it('deletes exactly one multiline block using Parser rawLine', async () => {
    const rawLine = '- **18:00** 晚间第一段。\n\n晚间第二段。 #晚间';
    const res = response();
    await diaryEntryHandler('/delete-entry')(
      { body: { date: '2024-08-12', section: 'quick_notes', line: rawLine } },
      res,
    );

    expect(res.statusCode).toBe(200);
    const updated = readDiary(date);
    expect(updated).toContain('- **08:00** 早间第一段。\n\n早间第二段。 #早间');
    expect(updated).not.toContain('晚间第一段。');
    expect(updated).not.toContain('晚间第二段。');
  });

  it('edits exactly one multiline block and preserves neighboring entries', async () => {
    const target = '- **18:00** 晚间第一段。\n\n晚间第二段。 #晚间';
    const replacement = '- **19:00** 更新第一段。\n  更新第二段。 #更新';
    const res = response();
    await diaryEntryHandler('/edit-entry')(
      {
        body: {
          date: '2024-08-12',
          section: 'quick_notes',
          target,
          replacement,
        },
      },
      res,
    );

    expect(res.statusCode).toBe(200);
    const updated = readDiary(date);
    expect(updated).toContain('- **08:00** 早间第一段。\n\n早间第二段。 #早间');
    expect(updated).toContain('- **19:00** 更新第一段。\n  更新第二段。 #更新');
    expect(updated).not.toContain('晚间第一段。');
  });

  it('writes continuation paragraphs with a stable list-item prefix', async () => {
    const res = response();
    await diaryEntryHandler('/quick-note')(
      {
        body: {
          date: '2024-08-12',
          time: '10:00',
          content: '新增第一段。\n\n新增第二段。',
          tags: ['新增'],
        },
      },
      res,
    );

    expect(res.statusCode).toBe(200);
    expect(readDiary(date)).toContain(
      '- **10:00** 新增第一段。\n  \n  新增第二段。 #新增',
    );
  });

  const duplicateFirstLineCases = [
    {
      name: '随手记',
      section: 'quick_notes',
      header: '## ✍️ 随手记 & 灵感',
      nextHeader: '## ✨ 每日小确幸',
      first: '- **18:00** 相同首段。\n  第一条末段。 #第一条',
      second: '- **18:00** 相同首段。\n  第二条末段。 #第二条',
      replacement: '- **19:00** 更新首段。\n  更新末段。 #更新',
    },
    {
      name: '觉察',
      section: 'reflection',
      header: '### 💡 觉察与迭代',
      nextHeader: '### 🧠 人生教练',
      first: '- **18:00** 相同首段。\n  第一条末段。 #第一条',
      second: '- **18:00** 相同首段。\n  第二条末段。 #第二条',
      replacement: '- **19:00** 更新首段。\n  更新末段。 #更新',
    },
    {
      name: '小确幸',
      section: 'happiness',
      header: '## ✨ 每日小确幸',
      nextHeader: '## 😰 焦虑时刻',
      first: '> **18:00** 相同首段。\n> 第一条末段。 #第一条',
      second: '> **18:00** 相同首段。\n> 第二条末段。 #第二条',
      replacement: '> **19:00** 更新首段。\n> 更新末段。 #更新',
    },
  ];

  it.each(duplicateFirstLineCases)(
    'deletes the exact $name block when first lines are identical',
    async ({ section, header, nextHeader, first, second }) => {
      writeDiary(date, ['# 今天', '', header, first, second, '', nextHeader].join('\n'));
      const res = response();

      await diaryEntryHandler('/delete-entry')(
        { body: { date: '2024-08-12', section, line: second } },
        res,
      );

      expect(res.statusCode).toBe(200);
      const updated = readDiary(date);
      expect(updated).toContain(first);
      expect(updated).not.toContain('第二条末段。');
    },
  );

  it.each(duplicateFirstLineCases)(
    'edits the exact $name block when first lines are identical',
    async ({ section, header, nextHeader, first, second, replacement }) => {
      writeDiary(date, ['# 今天', '', header, first, second, '', nextHeader].join('\n'));
      const res = response();

      await diaryEntryHandler('/edit-entry')(
        {
          body: {
            date: '2024-08-12',
            section,
            target: second,
            replacement,
          },
        },
        res,
      );

      expect(res.statusCode).toBe(200);
      const updated = readDiary(date);
      expect(updated).toContain(first);
      expect(updated).toContain(replacement);
      expect(updated).not.toContain('第二条末段。');
    },
  );

  it('rejects a stale multiline rawLine without changing the diary', async () => {
    const before = readDiary(date);
    const staleRawLine = '- **18:00** 晚间第一段。\n\n已经过期的第二段。 #晚间';
    const res = response();

    await diaryEntryHandler('/delete-entry')(
      { body: { date: '2024-08-12', section: 'quick_notes', line: staleRawLine } },
      res,
    );

    expect(res.statusCode).toBe(404);
    expect(readDiary(date)).toBe(before);
  });
});

describe('entry photo associations', () => {
  const date = new Date('2024-03-12T12:00:00+08:00');
  const entryId = '11111111-1111-4111-8111-111111111111';
  const operationId = '22222222-2222-4222-8222-222222222222';
  const source = Buffer.from(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
    'base64',
  );

  beforeEach(() => {
    rmSync(testConfig.vaultPath, { recursive: true, force: true });
    writeDiary(
      date,
      [
        '# 今天',
        '',
        '## ✍️ 随手记 & 灵感',
        '- **08:00** 正文第一段。',
        '',
        '正文最后一段。 #育儿',
        `<!-- litchi-entry-id:${entryId} -->`,
        '',
        '## 📸 影像记录',
      ].join('\n'),
    );
    mkdirSync(assetsDir(2024, 3), { recursive: true });
  });

  afterAll(() => {
    rmSync(testConfig.vaultPath, { recursive: true, force: true });
  });

  it('appends a same-minute multiline record with its hidden id intact', async () => {
    const addedEntryId = '77777777-7777-4777-8777-777777777777';
    const appendOperationId = '88888888-8888-4888-8888-888888888888';
    const res = response();
    await diaryEntryHandler('/quick-note')(
      {
        body: {
          date: '2024-03-12',
          time: '08:00',
          content: '新增记录第一段。\n\n新增记录末段。',
          tags: ['记录'],
          entryId: addedEntryId,
          operationId: appendOperationId,
        },
      },
      res,
    );

    const updated = readDiary(date);
    expect(res.statusCode).toBe(200);
    expect(updated.indexOf(`<!-- litchi-entry-id:${entryId} -->`)).toBeLessThan(
      updated.indexOf('- **08:00** 新增记录第一段。'),
    );
    expect(updated).toContain(
      `新增记录末段。 #记录\n<!-- litchi-entry-id:${addedEntryId} -->`,
    );
    expect(updated.match(/<!-- litchi-entry-id:/g)).toHaveLength(2);
  });

  it('keeps a multiline entry id with its record when edited and time-sorted', async () => {
    const secondEntryId = '55555555-5555-4555-8555-555555555555';
    const photoOperationId = '66666666-6666-4666-8666-666666666666';
    const rawLine = [
      '- **08:00** 正文第一段。',
      '',
      '正文最后一段。 #育儿',
      `<!-- litchi-entry-id:${entryId} -->`,
    ].join('\n');
    writeDiary(
      date,
      [
        '# 今天',
        '',
        '## ✍️ 随手记 & 灵感',
        rawLine,
        '- **09:00** 后续记录。',
        `<!-- litchi-entry-id:${secondEntryId} -->`,
        '',
        '## 📸 影像记录',
        '![[attached.jpg]]',
        `<!-- litchi-photo-of:${entryId};op:${photoOperationId} -->`,
      ].join('\n'),
    );

    const res = response();
    await diaryEntryHandler('/edit-entry')(
      {
        body: {
          date: '2024-03-12',
          section: 'quick_notes',
          target: rawLine,
          replacement: '- **10:00** 更新后的第一段。\n\n更新后的末段。 #家庭',
          entryId,
        },
      },
      res,
    );

    const updated = readDiary(date);
    expect(res.statusCode).toBe(200);
    expect(updated.indexOf('- **09:00** 后续记录。')).toBeLessThan(
      updated.indexOf('- **10:00** 更新后的第一段。'),
    );
    expect(updated).toContain(
      `更新后的末段。 #家庭\n<!-- litchi-entry-id:${entryId} -->`,
    );
    expect(updated).toContain(
      `<!-- litchi-photo-of:${entryId};op:${photoOperationId} -->`,
    );
  });

  it('attaches uploads to an entry and deduplicates retries by upload id', async () => {
    const req = {
      body: {
        date: '2024-03-12',
        imageData: source.toString('base64'),
        imagePrefix: 'Litchi_Img',
        operationId,
        entryId,
      },
    };
    const first = response();
    await uploadImageHandler()(req, first);

    expect(first.statusCode).toBe(200);
    const filename = (first.body as { filename: string }).filename;
    expect(readDiary(date)).toContain(`![[${filename}]]`);
    expect(readDiary(date)).toContain(
      `<!-- litchi-photo-of:${entryId};op:${operationId} -->`,
    );

    const second = response();
    await uploadImageHandler()(req, second);
    expect(second.body).toMatchObject({ dedup: true, filename });
    expect(readDiary(date).match(new RegExp(`!\\[\\[${filename}\\]\\]`, 'g')))
      .toHaveLength(1);
  });

  it('deletes only photos linked to the deleted entry and keeps referenced files', async () => {
    const linkedName = 'linked.jpg';
    const sharedName = 'shared.jpg';
    const linkedOperation = '33333333-3333-4333-8333-333333333333';
    const otherEntryId = '44444444-4444-4444-8444-444444444444';
    writeFileSync(join(assetsDir(2024, 3), linkedName), source);
    writeFileSync(join(assetsDir(2024, 3), sharedName), source);
    writeDiary(
      date,
      [
        '# 今天',
        '',
        '## ✍️ 随手记 & 灵感',
        '- **08:00** 正文第一段。',
        '',
        '正文最后一段。 #育儿',
        `<!-- litchi-entry-id:${entryId} -->`,
        '- **09:00** 另一条记录。',
        `<!-- litchi-entry-id:${otherEntryId} -->`,
        '',
        '## 📸 影像记录',
        `![[${linkedName}]]`,
        `<!-- litchi-photo-of:${entryId};op:${linkedOperation} -->`,
        `![[${sharedName}]]`,
        `<!-- litchi-photo-of:${otherEntryId};op:${operationId} -->`,
      ].join('\n'),
    );

    const res = response();
    await diaryEntryHandler('/delete-entry')(
      {
        body: {
          date: '2024-03-12',
          section: 'quick_notes',
          line: [
            '- **08:00** 正文第一段。',
            '',
            '正文最后一段。 #育儿',
            `<!-- litchi-entry-id:${entryId} -->`,
          ].join('\n'),
        },
      },
      res,
    );

    expect(res.statusCode).toBe(200);
    expect(res.body).toMatchObject({ deletedPhotoCount: 1 });
    expect(existsSync(join(assetsDir(2024, 3), linkedName))).toBe(false);
    expect(existsSync(join(assetsDir(2024, 3), sharedName))).toBe(true);
    expect(readDiary(date)).toContain(`![[${sharedName}]]`);
    expect(readDiary(date)).not.toContain(`![[${linkedName}]]`);
  });

  it('keeps a linked file referenced by another diary in the same month', async () => {
    const filename = 'shared-across-days.jpg';
    const nextDate = new Date('2024-03-13T12:00:00+08:00');
    writeFileSync(join(assetsDir(2024, 3), filename), source);
    writeDiary(
      date,
      `# 今天\n\n## ✍️ 随手记 & 灵感\n- **08:00** 正文\n<!-- litchi-entry-id:${entryId} -->\n\n## 📸 影像记录\n![[${filename}]]\n<!-- litchi-photo-of:${entryId};op:${operationId} -->`,
    );
    writeDiary(nextDate, `# 明天\n\n## 📸 影像记录\n![[${filename}]]`);

    const res = response();
    await diaryEntryHandler('/delete-entry')(
      {
        body: {
          date: '2024-03-12',
          section: 'quick_notes',
          line: `- **08:00** 正文\n<!-- litchi-entry-id:${entryId} -->`,
        },
      },
      res,
    );

    expect(res.statusCode).toBe(200);
    expect(existsSync(join(assetsDir(2024, 3), filename))).toBe(true);
    expect(readDiary(nextDate)).toContain(`![[${filename}]]`);
  });

  it('does not cascade-delete a photo with an invalid association marker', async () => {
    const filename = 'orphan-invalid-op.jpg';
    writeFileSync(join(assetsDir(2024, 3), filename), source);
    writeDiary(
      date,
      `# 今天\n\n## ✍️ 随手记 & 灵感\n- **08:00** 正文\n<!-- litchi-entry-id:${entryId} -->\n\n## 📸 影像记录\n![[${filename}]]\n<!-- litchi-photo-of:${entryId};op:------------------------------------ -->`,
    );

    const res = response();
    await diaryEntryHandler('/delete-entry')(
      {
        body: {
          date: '2024-03-12',
          section: 'quick_notes',
          line: `- **08:00** 正文\n<!-- litchi-entry-id:${entryId} -->`,
        },
      },
      res,
    );

    expect(res.statusCode).toBe(200);
    expect(readDiary(date)).toContain(`![[${filename}]]`);
    expect(existsSync(join(assetsDir(2024, 3), filename))).toBe(true);
  });

  it('rejects a tenth photo attached to one entry', async () => {
    const photos = Array.from({ length: 9 }, (_, index) => {
      const photoOpId = `33333333-3333-4333-8333-${String(index).padStart(12, '0')}`;
      return `![[existing-${index}.jpg]]\n<!-- litchi-photo-of:${entryId};op:${photoOpId} -->`;
    });
    writeDiary(date, `${readDiary(date)}\n${photos.join('\n')}`);

    const res = response();
    await uploadImageHandler()(
      {
        body: {
          date: '2024-03-12',
          imageData: source.toString('base64'),
          operationId,
          entryId,
        },
      },
      res,
    );

    expect(res.statusCode).toBe(409);
    expect(readDiary(date).match(/litchi-photo-of:/g)).toHaveLength(9);
  });

  it('does not treat a pasted entry marker in body text as the new entry id', async () => {
    const addedEntryId = '77777777-7777-4777-8777-777777777777';
    const res = response();
    await diaryEntryHandler('/quick-note')(
      {
        body: {
          date: '2024-03-12',
          time: '09:00',
          content: `正文\n<!-- litchi-entry-id:${entryId} -->`,
          tags: [],
          entryId: addedEntryId,
        },
      },
      res,
    );
    expect(res.statusCode).toBe(200);

    const upload = response();
    await uploadImageHandler()(
      {
        body: {
          date: '2024-03-12',
          imageData: source.toString('base64'),
          operationId,
          entryId: addedEntryId,
        },
      },
      upload,
    );
    expect(upload.statusCode).toBe(200);
    expect(readDiary(date)).toContain(`<!-- litchi-photo-of:${addedEntryId};op:${operationId} -->`);
  });

  it('preserves a pasted marker in edited body without changing its linked id', async () => {
    const copiedId = '77777777-7777-4777-8777-777777777777';
    const target = '- **08:00** 正文第一段。\n\n正文最后一段。 #育儿\n'
      + `<!-- litchi-entry-id:${entryId} -->`;
    const res = response();
    await diaryEntryHandler('/edit-entry')(
      {
        body: {
          date: '2024-03-12',
          section: 'quick_notes',
          target,
          replacement: `- **08:00** 新正文\n  <!-- litchi-entry-id:${copiedId} -->`,
          entryId,
        },
      },
      res,
    );

    const updated = readDiary(date);
    expect(res.statusCode).toBe(200);
    expect(updated).toContain(`  <!-- litchi-entry-id:${copiedId} -->`);
    expect(updated).toContain(`<!-- litchi-entry-id:${entryId} -->`);
  });
});
