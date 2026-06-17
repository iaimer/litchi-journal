import { Router } from 'express';
import { readFileSync, existsSync } from 'fs';
import { join } from 'path';
import config from '../config/index.js';
import { readDiary, listMonthDiaries, getDiaryPath } from '../services/vault.js';
import { parseDiary } from '../services/markdown.js';
import { getShanghaiDateString, parseShanghaiDate } from '../utils/date.js';

const router = Router();

router.get('/habit', async (req, res) => {
  try {
    const days = parseInt(req.query.days as string) || 30;
    const stats: any[] = [];

    const today = parseShanghaiDate(getShanghaiDateString(new Date()));
    for (let i = days - 1; i >= 0; i--) {
      const date = new Date(today.getTime() - i * 24 * 60 * 60 * 1000);

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
          supplements: false
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
    supplements: false
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
    }

    if (line.includes('🇬🇧') || line.includes('学语言')) {
      data.language = line.includes('[x]');
    }

    if (line.includes('💊') || line.includes('鱼油')) {
      data.supplements = line.includes('[x]');
    }
  }

  return data;
}

export default router;
