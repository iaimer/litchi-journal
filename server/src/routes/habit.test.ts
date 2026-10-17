import { beforeEach, describe, expect, it, vi } from 'vitest';

const fixture = vi.hoisted(() => ({
  contents: new Map<string, string>(),
  diaryKeys: [] as string[],
}));

vi.mock('../services/vault.js', () => ({
  readDiary: (date: Date) => {
    const key = date.toISOString().slice(0, 10);
    const content = fixture.contents.get(key);
    if (content == null) throw new Error('Diary not found');
    return content;
  },
  listDiaryMonths: () => [{ year: 2024, month: 2 }],
  listMonthDiaries: () => fixture.diaryKeys,
  getDiaryPath: () => '',
}));

import habitRoutes from './habit.js';

type Handler = (req: unknown, res: any) => Promise<void>;

function habitHandler(): Handler {
  const stack = (habitRoutes as any).stack as any[];
  const layer = stack.find(item => item.route?.path === '/habit');
  return layer.route.stack[0].handle as Handler;
}

function response() {
  return {
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
}

describe('habit trend route', () => {
  beforeEach(() => {
    fixture.contents = new Map();
    fixture.diaryKeys = [];
  });

  it('returns a bounded date range with built-in and custom snapshots', async () => {
    fixture.contents.set(
      '2026-09-09',
      [
        '# 2026年9月9日',
        '## 🏃 习惯打卡',
        '- [x] 📖 亲子共读 45 分钟',
        '- [x] 🇬🇧 学语言 20 分钟',
        '- [x] 💊 补充剂',
        '- 饮水 1500 mL',
        '- 运动 6000 步',
        '- [x] 📝 拉伸',
      ].join('\n'),
    );

    const res = response();
    await habitHandler()(
      { query: { from: '2026-09-09', to: '2026-09-11' } },
      res,
    );

    expect(res.statusCode).toBe(200);
    expect(res.body).toEqual([
      expect.objectContaining({
        date: '2026-09-09',
        hasDiary: true,
        water: 1500,
        steps: 6000,
        reading: true,
        language: true,
        supplements: true,
        readingMinutes: 45,
        languageMinutes: 20,
        customCheckboxes: { '📝 拉伸': true },
      }),
      expect.objectContaining({
        date: '2026-09-10',
        hasDiary: false,
        water: 0,
        readingMinutes: null,
        customCheckboxes: {},
      }),
      expect.objectContaining({
        date: '2026-09-11',
        hasDiary: false,
      }),
    ]);
  });

  it('does not confuse custom habit names with built-in habits', async () => {
    fixture.contents.set(
      '2026-09-10',
      [
        '# 2026年9月10日',
        '## 🏃 习惯打卡',
        '- [x] 📝 运动拉伸',
        '- [x] 📝 每天学语言',
        '- [x] 📝 补充剂记录',
        '- [x] 📝 饮水 500 mL',
        '- [x] 📝 阅读计划 25 分钟',
      ].join('\n'),
    );

    const res = response();
    await habitHandler()(
      { query: { from: '2026-09-10', to: '2026-09-10' } },
      res,
    );

    expect(res.statusCode).toBe(200);
    expect(res.body).toEqual([
      expect.objectContaining({
        water: 0,
        steps: 0,
        reading: false,
        language: false,
        supplements: false,
        customCheckboxes: {
          '📝 运动拉伸': true,
          '📝 每天学语言': true,
          '📝 补充剂记录': true,
          '📝 饮水 500 mL': true,
        },
        customDurations: { '📝 阅读计划': 25 },
      }),
    ]);
  });

  it('days=all skips invalid filenames and dates while preserving sorted valid snapshots', async () => {
    fixture.diaryKeys = ['备份', '2024-02-30', '2024-02-31', '2024-02-2', '2024-02-29', '2024-02-28', '2024-02-29', '9999-01-01'];
    fixture.contents.set('2024-02-29', '## 🏃 习惯打卡\n- 饮水 1200 mL');
    fixture.contents.set('2024-02-28', '## 🏃 习惯打卡\n- 饮水 800 mL');
    const res = response();
    await habitHandler()({ query: { days: 'all' } }, res);
    expect(res.statusCode).toBe(200);
    expect(res.body).toEqual([
      expect.objectContaining({ date: '2024-02-28', hasDiary: true, water: 800 }),
      expect.objectContaining({ date: '2024-02-29', hasDiary: true, water: 1200 }),
    ]);
  });

  it('rejects incomplete, invalid, reversed, and oversized ranges', async () => {
    for (const query of [
      { from: '2026-09-09' },
      { from: '2026-02-30', to: '2026-03-01' },
      { from: '2026-09-11', to: '2026-09-09' },
      { from: '2025-01-01', to: '2026-01-02' },
    ]) {
      const res = response();
      await habitHandler()({ query }, res);
      expect(res.statusCode).toBe(400);
    }
  });
});
