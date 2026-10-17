import { afterAll, beforeEach, describe, expect, it } from 'vitest';
import { existsSync, mkdirSync, readFileSync, readdirSync, rmSync, writeFileSync } from 'fs';
import { join } from 'path';
import { vi } from 'vitest';

const fixture = await vi.hoisted(async () => {
  const { mkdtempSync } = await import('node:fs');
  const { tmpdir } = await import('node:os');
  const { join } = await import('node:path');
  return { vaultPath: mkdtempSync(join(tmpdir(), 'litchi-write-reliability-')) };
});
vi.mock('../config/index.js', () => ({ default: { ...fixture, apiToken: 'test-token', port: 0 } }));
vi.mock('fs', async importOriginal => {
  const fs = await importOriginal<typeof import('fs')>();
  return { ...fs, writeFileSync: vi.fn(fs.writeFileSync) };
});
import router from './diary.js';
import { getAssetsDir, readDiary, writeDiary } from '../services/vault.js';

const date = new Date('2024-08-12T12:00:00+08:00');
const op = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const entryId = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
const photoOp = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc';
const png = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=';
const template = '# 今天\n## 🏃 习惯打卡\n- [ ] 📖 阅读/亲子共读 0 分钟\n## ✍️ 随手记 & 灵感\n## ✨ 每日小确幸\n### 💡 觉察与迭代\n## 😰 焦虑时刻\n### 🧠 人生教练\n### 🌙 明日寄语\n## 📸 影像记录';

async function post(path: string, body: Record<string, unknown>) {
  const layer = (router as any).stack.find((item: any) => item.route?.path === path);
  const response = { statusCode: 200, body: {} as any,
    status(code: number) { this.statusCode = code; return this; },
    json(value: unknown) { this.body = value; return this; },
  };
  await layer.route.stack[0].handle({ body: { date: '2024-08-12', ...body } }, response);
  return response;
}

beforeEach(async () => {
  const real = await vi.importActual<typeof import('fs')>('fs');
  vi.mocked(writeFileSync).mockImplementation(real.writeFileSync);
  rmSync(fixture.vaultPath, { recursive: true, force: true });
  writeDiary(date, template);
});
afterAll(() => rmSync(fixture.vaultPath, { recursive: true, force: true }));

describe('write reliability', () => {
  it.each(['/quick-note', '/happiness', '/reflection', '/anxiety', '/habit', '/lizhi-says', '/tomorrow'])(
    '%s rejects a missing section without changing the file', async path => {
      writeDiary(date, '# 只有自定义标题\n## 自定义');
      const before = readDiary(date);
      const res = await post(path, { content: '待保存', tags: [], water: 250, steps: 0 });
      expect(res.statusCode).toBe(409);
      expect(readDiary(date)).toBe(before);
    },
  );

  it('preserves omitted custom habits, notes, dividers and following unknown sections', async () => {
    const source = '# 今天\n## 🏃 习惯打卡\n- 🥛饮水 0 mL\n- [x] 📝 冥想\n备注不应丢失\n---\n## 我的其他内容\n珍贵内容';
    writeDiary(date, source);
    const res = await post('/habit', { water: 250, steps: 0, reading: false, language: false, supplements: false });
    expect(res.statusCode).toBe(200);
    const saved = readDiary(date);
    for (const text of ['- [x] 📝 冥想', '备注不应丢失\n---', '## 我的其他内容\n珍贵内容']) expect(saved).toContain(text);
    expect(saved).toContain('饮水 250 mL');
  });

  it('does not confuse a custom duration with reading or a substring label', async () => {
    writeDiary(date, '## 🏃 习惯打卡\n- [x] 📖 读书笔记 25 分钟\n- [ ] 📝 深度拉伸 4 分钟\n## ✍️ 随手记 & 灵感');
    await post('/habit', { water: 0, steps: 0 });
    expect(readDiary(date)).toContain('- [x] 📖 读书笔记 25 分钟');
    await post('/habit/duration', { habitKey: 'custom_stretch', label: '拉伸', rawLine: '', minutes: 2, operation: 'add' });
    expect(readDiary(date)).toContain('- [ ] 📝 深度拉伸 4 分钟');
    expect(readDiary(date)).toContain('拉伸 2 分钟');
  });

  it('updates a renamed custom habit only through its exact source rawLine', async () => {
    writeDiary(date, '## 🏃 习惯打卡\n- [ ] 📝 旧习惯\n- [x] 📝 冥想 7 分钟\n## ✍️ 随手记 & 灵感');
    const res = await post('/habit', { water: 0, steps: 0,
      extraCheckboxes: { custom_one: { label: '📝 新习惯', rawLine: '- [ ] 📝 旧习惯', checked: true } },
      extraDurations: { custom_two: { label: '📝 静坐', rawLine: '- [x] 📝 冥想 7 分钟', minutes: 8, checked: true } },
    });
    expect(res.statusCode).toBe(200);
    expect(readDiary(date)).toContain('- [x] 📝 新习惯');
    expect(readDiary(date)).toContain('- [x] 📝 静坐 8 分钟');
    expect(readDiary(date)).not.toContain('旧习惯');
    expect(readDiary(date)).not.toContain('冥想');
  });

  it('rejects a stale custom habit source without overwriting another row', async () => {
    const before = readDiary(date);
    const res = await post('/habit', { water: 0, steps: 0,
      extraCheckboxes: { custom_one: { label: '📝 新习惯', rawLine: '- [ ] 已不存在的习惯', checked: true } },
    });
    expect(res.statusCode).toBe(409);
    expect(readDiary(date)).toBe(before);
  });

  it('rejects a first-line-only target for a multiline record', async () => {
    writeDiary(date, '## ✍️ 随手记 & 灵感\n- **08:00** 第一段\n  不可误删的第二段');
    const before = readDiary(date);
    expect((await post('/delete-entry', { section: 'quick_notes', line: '- **08:00** 第一段' })).statusCode).toBe(404);
    expect(readDiary(date)).toBe(before);
  });

  it('deletes only a standalone image rawLine and preserves its following notes', async () => {
    writeDiary(date, '## 📸 影像记录\n![[standalone.jpg]]\n手写照片说明\n另一段内容');
    const res = await post('/delete-entry', { section: 'images', line: '![[standalone.jpg]]' });
    expect(res.statusCode).toBe(200);
    expect(readDiary(date)).toContain('手写照片说明\n另一段内容');
  });

  it('rejects a changed multiline image source without falling back to its first line', async () => {
    writeDiary(date, `## 📸 影像记录\n![[standalone.jpg]]\n<!-- litchi-photo-of:${entryId};op:${photoOp} -->`);
    const before = readDiary(date);
    const res = await post('/delete-entry', { section: 'images', line: '![[standalone.jpg]]\n<!-- 已过期的关联 -->' });
    expect(res.statusCode).toBe(404);
    expect(readDiary(date)).toBe(before);
  });

  it.each([
    { date: 123 }, { date: '2024-02-30' }, { time: '25:61' },
    { tags: ['生活\n## 伪造章节'] }, { operationId: 'not-a-uuid' },
  ])('rejects invalid write input %j before touching the diary', async invalid => {
    const before = readDiary(date);
    const res = await post('/quick-note', { content: '新记录', tags: [], ...invalid });
    expect(res.statusCode).toBe(400);
    expect(readDiary(date)).toBe(before);
  });

  it.each([undefined, null, '', 123, '2024-02-30'])(
    'image upload rejects missing or invalid date %j without creating attachments', async invalidDate => {
      const before = readDiary(date);
      const res = await post('/image/upload', { date: invalidDate, imageData: `data:image/png;base64,${png}` });
      expect(res.statusCode).toBe(400);
      expect(res.body.error).toContain('日期');
      expect(readDiary(date)).toBe(before);
      expect(existsSync(getAssetsDir(date))).toBe(false);
    },
  );

  it.each([undefined, null, 123, {}, [], '', '   '])(
    'rejects invalid imageData %j before touching the diary or assets', async imageData => {
      const before = readDiary(date);
      const res = await post('/image/upload', { imageData });
      expect(res.statusCode).toBe(400);
      expect(readDiary(date)).toBe(before);
      expect(existsSync(getAssetsDir(date))).toBe(false);
    },
  );

  it.each([
    '- 没有时间的记录\n  缩进续行',
    '> 没有时间的引用\n> 第二段引用',
    '> [!note] 提醒\n> 不可遗漏的说明',
    '- [ ] 自定义任务\n  任务说明',
  ])('requires the full non-timeline block for edit and delete: %s', async block => {
    writeDiary(date, `## ✍️ 随手记 & 灵感\n${block}\n- **09:00** 相邻记录`);
    const before = readDiary(date);
    for (const path of ['/delete-entry', '/edit-entry']) {
      const res = await post(path, { section: 'quick_notes', line: block.split('\n')[0], target: block.split('\n')[0], replacement: '- 新内容' });
      expect(res.statusCode).toBe(404);
      expect(readDiary(date)).toBe(before);
      const continuation = block.split('\n')[1];
      const partial = await post(path, { section: 'quick_notes', line: continuation, target: continuation, replacement: '- 新内容' });
      expect(partial.statusCode).toBe(404);
      expect(readDiary(date)).toBe(before);
    }
    const edited = await post('/edit-entry', { section: 'quick_notes', target: block, replacement: '- 完整改写\n  新续行' });
    expect(edited.statusCode).toBe(200);
    expect(readDiary(date)).toContain('- 完整改写\n  新续行');
    const removed = await post('/delete-entry', { section: 'quick_notes', line: '- 完整改写\n  新续行' });
    expect(removed.statusCode).toBe(200);
    expect(readDiary(date)).toContain('- **09:00** 相邻记录');
    expect(readDiary(date)).not.toContain('新续行');
  });

  it('requires the association marker when deleting a linked image rawLine', async () => {
    const block = `![[photo.jpg]]\n<!-- litchi-photo-of:${entryId};op:${photoOp} -->`;
    writeDiary(date, `## 📸 影像记录\n${block}\n手写说明应保留`);
    const before = readDiary(date);
    expect((await post('/delete-entry', { section: 'images', line: '![[photo.jpg]]' })).statusCode).toBe(404);
    expect(readDiary(date)).toBe(before);
    expect((await post('/delete-entry', { section: 'images', line: block })).statusCode).toBe(200);
    expect(readDiary(date)).toContain('手写说明应保留');
    expect(readDiary(date)).not.toContain('litchi-photo-of');
  });

  it('does not inject a section through a custom checkbox label', async () => {
    const before = readDiary(date);
    const res = await post('/habit', { water: 0, steps: 0,
      extraCheckboxes: { custom_one: { label: '习惯\n## 伪造章节', checked: true } },
    });
    expect(res.statusCode).toBe(400);
    expect(readDiary(date)).toBe(before);
  });

  it('deduplicates committed minutes when the old operation index is lost or corrupt', async () => {
    const body = { habitKey: 'reading', label: '📖 阅读/亲子共读', rawLine: '- [ ] 📖 阅读/亲子共读 0 分钟', minutes: 15, operation: 'add', operationId: op };
    expect((await post('/habit/duration', body)).statusCode).toBe(200);
    mkdirSync(getAssetsDir(date), { recursive: true });
    writeFileSync(join(getAssetsDir(date), '.diary-ops.json'), '{broken');
    const retry = await post('/habit/duration', body);
    expect(retry.body).toMatchObject({ dedup: true, minutes: 15 });
    expect(readDiary(date)).not.toContain('30 分钟');
  });

  it('fails closed for an unknown operation when the legacy index is corrupt', async () => {
    mkdirSync(getAssetsDir(date), { recursive: true });
    writeFileSync(join(getAssetsDir(date), '.diary-ops.json'), '{broken');
    const before = readDiary(date);
    expect((await post('/quick-note', { content: '新记录', tags: [], operationId: op })).statusCode).toBe(409);
    expect(readDiary(date)).toBe(before);
  });

  it('keeps committed operation ids after replacing another section', async () => {
    const body = { content: '只有一条', tags: [], operationId: op };
    await post('/quick-note', body);
    await post('/tomorrow', { content: '明日内容' });
    const retry = await post('/quick-note', body);
    expect(retry.body.dedup).toBe(true);
    expect(readDiary(date).match(/只有一条/g)).toHaveLength(1);
  });

  it('deduplicates after an external editor converts line endings to CRLF', async () => {
    const body = { content: '只有一条', tags: [], operationId: op };
    await post('/quick-note', body);
    writeDiary(date, readDiary(date).replace(/\n/g, '\r\n'));
    expect((await post('/quick-note', body)).body.dedup).toBe(true);
    expect(readDiary(date).match(/只有一条/g)).toHaveLength(1);
  });

  it('commits an upload without a second fallible operation-index write', async () => {
    const real = await vi.importActual<typeof import('fs')>('fs');
    vi.mocked(writeFileSync).mockImplementation((path, ...args: any[]) => {
      if (String(path).endsWith('.diary-ops.json')) throw new Error('index disk failure');
      return (real.writeFileSync as any)(path, ...args);
    });
    const res = await post('/image/upload', { imageData: png, operationId: op });
    expect(res.statusCode).toBe(200);
    expect(existsSync(join(getAssetsDir(date), res.body.filename))).toBe(true);
    expect(readFileSync(join(getAssetsDir(date), res.body.filename)).length).toBeGreaterThan(0);
    const retry = await post('/image/upload', { imageData: png, operationId: op });
    expect(retry.body.dedup).toBe(true);
    expect(retry.body.filename).toBe(res.body.filename);
  });

  it('removes only an uncommitted upload when the diary write fails', async () => {
    const before = readDiary(date);
    const real = await vi.importActual<typeof import('fs')>('fs');
    vi.mocked(writeFileSync).mockImplementation((path, ...args: any[]) => {
      if (typeof path === 'number') throw new Error('diary disk failure');
      return (real.writeFileSync as any)(path, ...args);
    });
    const res = await post('/image/upload', { imageData: png, operationId: op });
    expect(res.statusCode).toBe(500);
    expect(readDiary(date)).toBe(before);
    expect(readdirSync(getAssetsDir(date))).toEqual([]);
  });

  it.each(['![[shared.jpg|300]]', '![](assets/shared.jpg)', '![[SHARED.JPG]]', '{"nodes":[{"file":"assets/shared.jpg"}]}'])(
    'keeps an attachment referenced by %s', async reference => {
      const line = `- **08:00** 图文\n<!-- litchi-entry-id:${entryId} -->`;
      writeDiary(date, `## ✍️ 随手记 & 灵感\n${line}\n## 📸 影像记录\n![[shared.jpg]]\n<!-- litchi-photo-of:${entryId};op:${photoOp} -->`);
      mkdirSync(getAssetsDir(date), { recursive: true });
      writeFileSync(join(getAssetsDir(date), 'shared.jpg'), Buffer.from(png, 'base64'));
      writeFileSync(join(fixture.vaultPath, reference.startsWith('{') ? 'board.canvas' : 'other.md'), reference);
      expect((await post('/delete-entry', { section: 'quick_notes', line })).statusCode).toBe(200);
      expect(existsSync(join(getAssetsDir(date), 'shared.jpg'))).toBe(true);
    },
  );

  it('keeps operation metadata outside frontmatter and readable sections', async () => {
    writeDiary(date, `---\ntags:\n  - 日记\n---\n${template}`);
    await post('/quick-note', { content: '真实正文', tags: [], operationId: op });
    const saved = readDiary(date);
    expect(saved).toMatch(/^---\ntags:\n  - 日记\n---\n<!-- diary-op:/);
    expect((await post('/quick-note', { content: '真实正文', tags: [], operationId: op })).body.dedup).toBe(true);
  });

  it('does not use an indented pasted marker to associate a photo', async () => {
    writeDiary(date, `## ✍️ 随手记 & 灵感\n- **08:00** 正文\n  <!-- litchi-entry-id:${entryId} -->\n## 📸 影像记录`);
    const before = readDiary(date);
    const res = await post('/image/upload', { entryId, operationId: op, imageData: png });
    expect(res.statusCode).toBe(404);
    expect(readDiary(date)).toBe(before);
  });

  it('edits and deletes an indented multiline record as one exact block', async () => {
    const line = '- **18:00** 晚间\n  ## 细节\n  - [ ] 子任务\n  续行';
    writeDiary(date, `## ✍️ 随手记 & 灵感\n${line}\n- **08:00** 上午\n## ✨ 每日小确幸`);
    const replacement = line.replace('18:00', '07:00');
    expect((await post('/edit-entry', { section: 'quick_notes', target: line, replacement })).statusCode).toBe(200);
    expect(readDiary(date)).toContain(`${replacement}\n- **08:00** 上午`);
    expect((await post('/delete-entry', { section: 'quick_notes', line: replacement })).statusCode).toBe(200);
    expect(readDiary(date)).not.toContain('子任务');
  });
});
