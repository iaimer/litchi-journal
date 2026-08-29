import { Router } from 'express';
import { readDiary, listDiaryMonths, listMonthDiaries } from '../services/vault.js';
import { parseDiary } from '../services/markdown.js';
import { getShanghaiDateParts, parseShanghaiDate } from '../utils/date.js';
import {
  formatMonthCursor,
  hasDiaryContent,
  monthFromIndex,
  monthIndex,
  parseGalleryLimit,
  parseMonthCursor,
  extractGalleryImageNames,
  type GalleryMonth,
} from '../services/gallery.js';

const router = Router();

router.get('/gallery', async (req, res) => {
  try {
    const today = getShanghaiDateParts(new Date());
    const todayMonthIndex = monthIndex(today.year, today.month);
    const parsedCursor = req.query.cursor == null
      ? { year: today.year, month: today.month }
      : parseMonthCursor(req.query.cursor);
    const limit = parseGalleryLimit(req.query.limit);

    if (!parsedCursor) {
      return res.status(400).json({ error: 'Invalid cursor' });
    }
    if (limit == null) {
      return res.status(400).json({ error: 'Invalid limit' });
    }

    const requestedIndex = monthIndex(parsedCursor.year, parsedCursor.month);
    if (requestedIndex > todayMonthIndex) {
      return res.status(400).json({ error: 'Cursor cannot be in the future' });
    }

    const existingMonths = listDiaryMonths();
    if (existingMonths.length === 0) {
      return res.json({ months: [], nextCursor: null });
    }

    const earliestIndex = Math.min(
      ...existingMonths.map(month => monthIndex(month.year, month.month)),
    );
    if (requestedIndex < earliestIndex) {
      return res.json({ months: [], nextCursor: null });
    }

    const months: GalleryMonth[] = [];
    let cursorIndex = requestedIndex;
    while (months.length < limit && cursorIndex >= earliestIndex) {
      const month = monthFromIndex(cursorIndex);
      months.push(buildGalleryMonth(month.year, month.month, today));
      cursorIndex -= 1;
    }

    res.json({
      months,
      nextCursor: cursorIndex >= earliestIndex
        ? formatMonthCursor(monthFromIndex(cursorIndex).year, monthFromIndex(cursorIndex).month)
        : null,
    });
  } catch (error) {
    res.status(500).json({ error: (error as Error).message });
  }
});

router.get('/:year/:month', async (req, res) => {
  try {
    const year = parseInt(req.params.year);
    const month = parseInt(req.params.month);

    const diaryDates = listMonthDiaries(year, month);
    const diaries: any[] = [];

    for (const dateStr of diaryDates) {
      const date = parseShanghaiDate(dateStr);

      try {
        const content = readDiary(date);
        const entry = parseDiary(content);

        const images = entry.sections.images.filter(l => l.includes('![['));
        const hasImages = images.length > 0;

        let firstImage: string | undefined;
        if (hasImages) {
          const imageLine = images.find(l => l.includes('![['));
          if (imageLine) {
            const match = imageLine.match(/!\[\[(.*?)\]\]/);
            firstImage = match ? match[1] : undefined;
          }
        }

        const quickNotesCount = entry.sections.quick_notes
          .filter(l => l.trim() && !l.includes('<!--') && !l.includes('- **HH:MM** 内容 #标签'))
          .length;

        // 检查是否有实际内容（随手记、小确幸、觉察、焦虑时刻）。
        // 与画廊索引共用模板占位符过滤规则，避免空日记被月历误标记。
        const hasContent = hasDiaryContent(entry);

        diaries.push({
          date: dateStr,
          hasImages,
          firstImage,
          quickNotesCount,
          exists: true,
          hasContent
        });
      } catch (error) {
        console.error(`Failed to parse diary ${dateStr}:`, error);
      }
    }

    res.json({ year, month, diaries });
  } catch (error) {
    res.status(500).json({ error: (error as Error).message });
  }
});

function buildGalleryMonth(
  year: number,
  month: number,
  today: { year: number; month: number; day: number },
): GalleryMonth {
  const todayString = `${today.year}-${today.month.toString().padStart(2, '0')}-${today.day.toString().padStart(2, '0')}`;
  const days = [];

  const diaryDates = listMonthDiaries(year, month).sort((a, b) => b.localeCompare(a));
  for (const dateStr of diaryDates) {
    let date;
    try {
      date = parseShanghaiDate(dateStr);
    } catch {
      continue;
    }
    if (dateStr >= todayString) continue;

    try {
      const entry = parseDiary(readDiary(date));
      const images = extractGalleryImageNames(entry.sections.images);
      if (images.length === 0) continue;
      days.push({
        date: dateStr,
        images,
        hasContent: hasDiaryContent(entry),
      });
    } catch (error) {
      console.error(`Failed to parse gallery diary ${dateStr}:`, error);
    }
  }

  return {
    year,
    month,
    totalDays: days.length,
    totalImages: days.reduce((total, day) => total + day.images.length, 0),
    days,
  };
}

export default router;
