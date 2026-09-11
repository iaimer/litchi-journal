import { Router } from 'express';
import { readFileSync, existsSync } from 'fs';
import { join } from 'path';
import config from '../config/index.js';
import { readDiary, listDiaryMonths, listMonthDiaries, getDiaryPath } from '../services/vault.js';
import { parseDiary } from '../services/markdown.js';
import { getShanghaiDateString, parseShanghaiDate } from '../utils/date.js';

const router = Router();

router.get('/habit', async (req, res) => {
  try {
    const rawDays = queryString(req.query.days);
    const fromParam = queryString(req.query.from);
    const toParam = queryString(req.query.to);
    const stats: any[] = [];

    const today = parseShanghaiDate(getShanghaiDateString(new Date()));
    const dates: Date[] = [];
    if (fromParam !== undefined || toParam !== undefined) {
      if (fromParam === undefined || toParam === undefined) {
        res.status(400).json({ error: 'from and to are required together' });
        return;
      }

      let start: Date;
      let end: Date;
      try {
        start = parseShanghaiDate(fromParam);
        end = parseShanghaiDate(toParam);
      } catch {
        res.status(400).json({ error: 'Invalid date range' });
        return;
      }

      const rangeDays = Math.floor((end.getTime() - start.getTime()) / DAY_MS) + 1;
      if (rangeDays < 1 || rangeDays > MAX_RANGE_DAYS) {
        res.status(400).json({ error: 'Date range must contain 1 to 366 days' });
        return;
      }

      for (let i = 0; i < rangeDays; i++) {
        dates.push(new Date(start.getTime() + i * DAY_MS));
      }
    } else if (rawDays === 'all') {
      const dateKeys = new Set<string>();
      for (const month of listDiaryMonths()) {
        for (const dateKey of listMonthDiaries(month.year, month.month)) {
          if (dateKey <= getShanghaiDateString(today)) dateKeys.add(dateKey);
        }
      }
      for (const dateKey of [...dateKeys].sort()) dates.push(parseShanghaiDate(dateKey));
    } else {
      const requested = Number.parseInt(rawDays ?? '', 10);
      const days = Number.isFinite(requested)
        ? Math.min(Math.max(requested, 1), MAX_RANGE_DAYS)
        : 30;
      for (let i = days - 1; i >= 0; i--) {
        dates.push(new Date(today.getTime() - i * DAY_MS));
      }
    }

    for (const date of dates) {
      try {
        const content = readDiary(date);
        const entry = parseDiary(content);
        const habitData = parseHabitLines(entry.sections.habits);

        stats.push({
          date: getShanghaiDateString(date),
          hasDiary: true,
          ...habitData
        });
      } catch {
        stats.push({
          date: getShanghaiDateString(date),
          ...emptyHabitData(),
        });
      }
    }

    res.json(stats);
  } catch (error) {
    res.status(500).json({ error: (error as Error).message });
  }
});

const DAY_MS = 24 * 60 * 60 * 1000;
const MAX_RANGE_DAYS = 366;

function queryString(value: unknown): string | undefined {
  return typeof value === 'string' ? value : undefined;
}

function emptyHabitData() {
  return {
    hasDiary: false,
    water: 0,
    steps: 0,
    reading: false,
    language: false,
    supplements: false,
    readingMinutes: null,
    languageMinutes: null,
    customCheckboxes: {} as Record<string, boolean>,
    customDurations: {} as Record<string, number>
  };
}

function parseHabitLines(lines: string[]): any {
  const data = {
    water: 0,
    steps: 0,
    reading: false,
    language: false,
    supplements: false,
    readingMinutes: null as number | null,
    languageMinutes: null as number | null,
    customCheckboxes: {} as Record<string, boolean>,
    customDurations: {} as Record<string, number>
  };

  for (const line of lines) {
    if (isWaterLine(line)) {
      const match = line.match(/饮水\s+(\d+)\s*mL/);
      if (match) data.water = parseInt(match[1], 10);
    }

    if (isStepsLine(line)) {
      const match = line.match(/(\d+)\s*步/);
      if (match) data.steps = parseInt(match[1], 10);
    }

    if (isReadingLine(line)) {
      data.reading = isCheckedLine(line);
      const match = line.match(/(\d+)\s*(?:分钟|min)\s*$/i);
      if (match) data.readingMinutes = parseInt(match[1], 10);
    }

    if (isLanguageLine(line)) {
      data.language = isCheckedLine(line);
      const match = line.match(/(\d+)\s*(?:分钟|min)\s*$/i);
      if (match) data.languageMinutes = parseInt(match[1], 10);
    }

    if (isSupplementLine(line)) {
      data.supplements = isCheckedLine(line);
    }

    const durationMatch = line.match(/^(?:\s*)-\s*(?:\[[ xX]\]\s*)?(.+?)\s+(\d+)\s*(?:分钟|min)\s*$/i);
    if (durationMatch && !isBuiltInHabitLine(line)) {
      data.customDurations[durationMatch[1].trim()] = parseInt(durationMatch[2], 10);
      continue;
    }

    const checkboxMatch = line.match(/^\s*-\s*\[([ xX])\]\s*(.+?)\s*$/);
    if (checkboxMatch && !isBuiltInHabitLine(line)) {
      data.customCheckboxes[checkboxMatch[2].trim()] =
        checkboxMatch[1].toLowerCase() === 'x';
    }
  }

  return data;
}

function isWaterLine(line: string): boolean {
  return /^\s*-\s*(?:🥛(?:🥤)*\s*)?饮水\s+\d+\s*mL\s*$/i.test(line);
}

function isStepsLine(line: string): boolean {
  return /^\s*-\s*(?:🧘\s*)?(?:运动|运动\s*\/\s*拉伸\s*\/\s*快走)\s+\d+\s*步\s*$/.test(line);
}

function checkboxHabitLabel(line: string): string | null {
  const match = line.match(/^\s*-\s*\[[ xX]\]\s*(.+?)\s*$/);
  if (!match) return null;
  return match[1]
    .replace(/\s+\d+\s*(?:分钟|min)\s*$/i, '')
    .replace(/\s*\/\s*/g, '/')
    .replace(/\s+/g, ' ')
    .trim();
}

function isCheckedLine(line: string): boolean {
  return /^\s*-\s*\[[xX]\]/.test(line);
}

function isReadingLine(line: string): boolean {
  const label = checkboxHabitLabel(line);
  return label != null && new Set([
    '阅读',
    '亲子共读',
    '亲子阅读',
    '阅读/亲子共读',
    '📖 阅读',
    '📖 亲子共读',
    '📖 阅读/亲子共读',
  ]).has(label);
}

function isLanguageLine(line: string): boolean {
  const label = checkboxHabitLabel(line);
  return label === '学语言' || label === '🇬🇧 学语言';
}

function isSupplementLine(line: string): boolean {
  const label = checkboxHabitLabel(line);
  return label != null && new Set([
    '鱼油',
    '植物甾醇',
    '鱼油/植物甾醇',
    '补充剂',
    '💊 鱼油',
    '💊 植物甾醇',
    '💊 鱼油/植物甾醇',
    '💊 补充剂',
  ]).has(label);
}

function isBuiltInHabitLine(line: string): boolean {
  return isWaterLine(line) ||
    isStepsLine(line) ||
    isReadingLine(line) ||
    isLanguageLine(line) ||
    isSupplementLine(line);
}

export default router;
