import { describe, expect, it, vi } from 'vitest';

const fixture = vi.hoisted(() => ({
  months: [] as Array<{ year: number; month: number }>,
  diaries: new Map<string, string[]>(),
  contents: new Map<string, string>(),
  availableImages: new Set<string>(),
}));

vi.mock('../services/vault.js', () => ({
  listDiaryMonths: () => fixture.months,
  listMonthDiaries: (year: number, month: number) =>
    fixture.diaries.get(`${year}-${month}`) ?? [],
  readDiary: (date: Date) => {
    const dateKey = date.toISOString().slice(0, 10);
    const content = fixture.contents.get(dateKey);
    if (content == null) throw new Error('Diary not found');
    return content;
  },
  resolveImagePath: (_year: number, imageName: string, _month: number | null) =>
    fixture.availableImages.has(imageName) ? `/vault/assets/${imageName}` : null,
}));

import historyRoutes from './history.js';

type Handler = (req: unknown, res: any) => Promise<void>;

function galleryHandler(): Handler {
  const stack = (historyRoutes as any).stack as any[];
  const layer = stack.find(item => item.route?.path === '/gallery');
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

describe('history gallery route', () => {
  it('returns months, photo days, all images, and pagination cursor', async () => {
    fixture.months = [
      { year: 2024, month: 3 },
      { year: 2024, month: 2 },
      { year: 2023, month: 12 },
    ];
    fixture.diaries = new Map([
      ['2024-3', ['2024-03-08', '2024-03-09']],
      ['2024-2', []],
    ]);
    fixture.contents = new Map([
      [
        '2024-03-08',
        [
          '## 📸 影像记录',
          '![[first.jpg]] ![[second.png]] ![[../ignored.jpg]]',
          '## ✍️ 随手记 & 灵感',
          '- **09:00** 早起',
        ].join('\n'),
      ],
    ]);
    fixture.availableImages = new Set(['first.jpg', 'second.png']);

    const res = response();
    await galleryHandler()(
      { query: { cursor: '2024-03', limit: '2' } },
      res,
    );

    expect(res.statusCode).toBe(200);
    expect(res.body).toEqual({
      months: [
        {
          year: 2024,
          month: 3,
          totalDays: 1,
          totalImages: 2,
          days: [
            {
              date: '2024-03-08',
              images: ['first.jpg', 'second.png'],
              hasContent: true,
            },
          ],
        },
        {
          year: 2024,
          month: 2,
          totalDays: 0,
          totalImages: 0,
          days: [],
        },
      ],
      nextCursor: '2024-01',
    });
  });

  it('paginates empty months across a year boundary and skips an invalid diary', async () => {
    fixture.months = [
      { year: 2024, month: 1 },
      { year: 2023, month: 12 },
      { year: 2023, month: 10 },
    ];
    fixture.diaries = new Map([
      ['2024-1', []],
      ['2023-12', ['2023-12-15', '2023-12-16']],
    ]);
    fixture.contents = new Map([
      [
        '2023-12-15',
        ['## 📸 影像记录', '![[december.jpg]]'].join('\n'),
      ],
    ]);
    fixture.availableImages = new Set(['december.jpg']);

    const res = response();
    await galleryHandler()(
      { query: { cursor: '2024-01', limit: '2' } },
      res,
    );

    expect(res.statusCode).toBe(200);
    expect(res.body).toEqual({
      months: [
        { year: 2024, month: 1, totalDays: 0, totalImages: 0, days: [] },
        {
          year: 2023,
          month: 12,
          totalDays: 1,
          totalImages: 1,
          days: [
            {
              date: '2023-12-15',
              images: ['december.jpg'],
              hasContent: false,
            },
          ],
        },
      ],
      nextCursor: '2023-11',
    });
  });

  it('filters today and future dates', async () => {
    const today = new Date();
    const parts = new Intl.DateTimeFormat('en-CA', {
      timeZone: 'Asia/Shanghai',
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
    }).formatToParts(today);
    const values = Object.fromEntries(parts.map(part => [part.type, part.value]));
    const year = Number(values.year);
    const month = Number(values.month);
    const day = Number(values.day);
    const date = (offset: number) => {
      const dateValue = new Date(Date.UTC(year, month - 1, day + offset));
      return new Intl.DateTimeFormat('en-CA', {
        timeZone: 'Asia/Shanghai',
      }).format(dateValue);
    };

    fixture.months = [{ year, month }];
    fixture.diaries = new Map([
      [`${year}-${month}`, [date(-1), date(0), date(1)]],
    ]);
    fixture.contents = new Map([
      [date(-1), ['## 📸 影像记录', '![[past.jpg]]'].join('\n')],
      [date(0), ['## 📸 影像记录', '![[today.jpg]]'].join('\n')],
      [date(1), ['## 📸 影像记录', '![[future.jpg]]'].join('\n')],
    ]);
    fixture.availableImages = new Set(['past.jpg', 'today.jpg', 'future.jpg']);

    const res = response();
    await galleryHandler()(
      { query: { cursor: `${year}-${month.toString().padStart(2, '0')}`, limit: '1' } },
      res,
    );

    expect(res.statusCode).toBe(200);
    expect((res.body as any).months[0].days).toEqual([
      {
        date: date(-1),
        images: ['past.jpg'],
        hasContent: false,
      },
    ]);
  });

  it('filters missing assets and promotes the first available image', async () => {
    fixture.months = [{ year: 2024, month: 3 }];
    fixture.diaries = new Map([['2024-3', ['2024-03-08', '2024-03-09']]]);
    fixture.contents = new Map([
      [
        '2024-03-08',
        ['## 📸 影像记录', '![[missing.jpg]] ![[second.png]]'].join('\n'),
      ],
      ['2024-03-09', ['## 📸 影像记录', '![[gone.jpg]]'].join('\n')],
    ]);
    fixture.availableImages = new Set(['second.png']);

    const res = response();
    await galleryHandler()(
      { query: { cursor: '2024-03', limit: '1' } },
      res,
    );

    expect(res.statusCode).toBe(200);
    expect((res.body as any).months[0]).toEqual({
      year: 2024,
      month: 3,
      totalDays: 1,
      totalImages: 1,
      days: [
        {
          date: '2024-03-08',
          images: ['second.png'],
          hasContent: false,
        },
      ],
    });
  });

  it('rejects malformed, out-of-range, and future pagination inputs', async () => {
    fixture.months = [{ year: 2024, month: 1 }];
    const handler = galleryHandler();

    const malformed = response();
    await handler({ query: { cursor: '2024/01' } }, malformed);
    expect(malformed.statusCode).toBe(400);

    const badLimit = response();
    await handler({ query: { limit: '7' } }, badLimit);
    expect(badLimit.statusCode).toBe(400);

    const future = response();
    await handler({ query: { cursor: '9999-01' } }, future);
    expect(future.statusCode).toBe(400);
  });
});
