import { Router } from 'express';
import { readDiary, listMonthDiaries, getDiaryPath } from '../services/vault.js';
import { parseDiary } from '../services/markdown.js';
import { parseShanghaiDate } from '../utils/date.js';

const router = Router();

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

        // 检查是否有实际内容（随手记、小确幸、觉察、焦虑时刻）
        const hasQuickNotes = entry.sections.quick_notes
          .some(l => l.trim() && !l.includes('<!--') && !l.includes('- **HH:MM** 内容 #标签') && l.length > 2);

        const hasHappiness = entry.sections.happiness
          .some(l => l.trim() && !l.includes('<!--') && !l.match(/^>\s*$/) && !l.includes('总有事件值得感恩'));

        const hasReflection = entry.sections.reflection
          .some(l => l.trim() && !l.includes('<!--') && l !== '- ');

        const hasAnxiety = entry.sections.anxiety
          .some(l => l.trim() && !l.includes('<!--') && !l.match(/^>\s*$/));

        const hasContent = hasQuickNotes || hasHappiness || hasReflection || hasAnxiety;

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

export default router;
