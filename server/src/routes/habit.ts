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
    const rawDays = req.query.days as string;
    const requested = parseInt(rawDays);
    const days = Number.isFinite(requested)
      ? Math.min(Math.max(requested, 1), 366)
      : 30;
    const stats: any[] = [];

    const today = parseShanghaiDate(getShanghaiDateString(new Date()));
    const dates: Date[] = [];
    if (rawDays === 'all') {
      const dateKeys = new Set<string>();
      for (const month of listDiaryMonths()) {
        for (const dateKey of listMonthDiaries(month.year, month.month)) {
          if (dateKey <= getShanghaiDateString(today)) dateKeys.add(dateKey);
        }
      }
      for (const dateKey of [...dateKeys].sort()) dates.push(parseShanghaiDate(dateKey));
    } else {
      for (let i = days - 1; i >= 0; i--) {
        dates.push(new Date(today.getTime() - i * 24 * 60 * 60 * 1000));
      }
    }

    for (const date of dates) {

      try {
        const content = readDiary(date);
        const entry = parseDiary(content);
        const habitData = parseHabitLines(entry.sections.habits);

        stats.push({
          date: getShanghaiDateString(date),
          ...habitData
        });
      } catch {
        stats.push({
          date: getShanghaiDateString(date),
          water: 0,
          steps: 0,
          reading: false,
          language: false,
          supplements: false,
          readingMinutes: null,
          languageMinutes: null,
          customDurations: {}
        });
      }
    }

    res.json(stats);
  } catch (error) {
    res.status(500).json({ error: (error as Error).message });
  }
});

function parseHabitLines(lines: string[]): any {
  const data = {
    water: 0,
    steps: 0,
    reading: false,
    language: false,
    supplements: false,
    readingMinutes: null as number | null,
    languageMinutes: null as number | null,
    customDurations: {} as Record<string, number>
  };

  for (const line of lines) {
    if (line.includes('饮水')) {
      const match = line.match(/饮水\s+(\d+)\s*mL/);
      if (match) data.water = parseInt(match[1], 10);
    }

    if (line.includes('步') && line.includes('运动')) {
      const match = line.match(/(\d+)\s*步/);
      if (match) data.steps = parseInt(match[1], 10);
    }

    if (line.includes('📖')) {
      data.reading = line.includes('[x]');
      const match = line.match(/(\d+)\s*(?:分钟|min)\s*$/i);
      if (match) data.readingMinutes = parseInt(match[1], 10);
    }

    if (line.includes('🇬🇧') || line.includes('学语言')) {
      data.language = line.includes('[x]');
      const match = line.match(/(\d+)\s*(?:分钟|min)\s*$/i);
      if (match) data.languageMinutes = parseInt(match[1], 10);
    }

    if (line.includes('💊') || line.includes('鱼油')) {
      data.supplements = line.includes('[x]');
    }

    const durationMatch = line.match(/^(?:\s*)-\s*(?:\[[ xX]\]\s*)?(.+?)\s+(\d+)\s*(?:分钟|min)\s*$/i);
    if (durationMatch &&
        !line.includes('📖') &&
        !line.includes('阅读/亲子共读') &&
        !line.includes('🇬🇧') &&
        !line.includes('学语言') &&
        !line.includes('饮水') &&
        !line.includes('运动') &&
        !line.includes('鱼油') &&
        !line.includes('植物甾醇')) {
      data.customDurations[durationMatch[1].trim()] = parseInt(durationMatch[2], 10);
    }
  }

  return data;
}

export default router;
