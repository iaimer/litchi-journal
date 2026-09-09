import { Router } from 'express';
import {
  readDiary,
  writeDiary,
  getDateString,
  getDiaryPath,
  existsDiary,
  getAssetsDir,
  resolveImagePath,
} from '../services/vault.js';
import { readFileSync, existsSync, mkdirSync, writeFileSync, readdirSync, unlinkSync, realpathSync } from 'fs';
import { isAbsolute, join, relative, resolve } from 'path';
import sharp from 'sharp';
import config from '../config/index.js';
import { parseDiary, appendToSection, sectionHeaders, replaceEmptyBulletInSection, sortTimelineEntriesInSection } from '../services/markdown.js';
import { createObsidianDiaryContent } from '../services/template.js';
import { parseShanghaiDate } from '../utils/date.js';

const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const OLD_OP_MARKER_PATTERN = /^<!-- diary-op:[0-9a-f-]+ -->$/i;
const SAFE_IMAGE_NAME_PATTERN = /^[^/\\\u0000-\u001F\u007F]+\.(jpg|jpeg|png|gif|webp|heic|heif)$/i;
const OP_INDEX_FILE = '.diary-ops.json';

function validateOperationId(operationId: unknown): string | null {
  if (typeof operationId !== 'string' || !operationId) return null;
  if (!UUID_PATTERN.test(operationId)) return null;
  return operationId;
}

function sanitizeImagePrefix(imagePrefix: unknown): string {
  if (imagePrefix == null || imagePrefix === '') return 'Image';
  if (typeof imagePrefix !== 'string') {
    throw new Error('图片文件名前缀无效');
  }

  const trimmed = imagePrefix.trim();
  if (!/^[A-Za-z0-9_-]+$/.test(trimmed)) {
    throw new Error('图片文件名前缀只能包含英文、数字、短横线或下划线');
  }

  return trimmed;
}

function isValidCount(value: unknown): boolean {
  return typeof value === 'number' &&
    Number.isInteger(value) &&
    value >= 0 &&
    value <= 500000;
}

function isValidDuration(value: unknown): boolean {
  return isValidCount(value);
}

function durationFromHabitLine(line: string): number | null {
  const match = line.match(/(\d+)\s*(?:分钟|min)\s*$/i);
  return match ? Number(match[1]) : null;
}

function habitLabelFromLine(line: string): string {
  return line
    .replace(/^\s*-\s*(?:\[[ xX]\]\s*)?/, '')
    .replace(/\s+\d+\s*(?:分钟|min)\s*$/i, '')
    .trim();
}

function cleanHabitLabel(value: unknown): string | null {
  if (typeof value !== 'string') return null;
  const label = value.replace(/[\r\n]/g, ' ').trim();
  if (!label || label.length > 120) return null;
  return label.replace(/\s+\d+\s*(?:分钟|min)\s*$/i, '').trim() || null;
}

function hasOwn(body: Record<string, unknown>, key: string): boolean {
  return Object.prototype.hasOwnProperty.call(body, key);
}

function stripOldOpMarkers(content: string): string {
  return content
    .split('\n')
    .filter(line => !OLD_OP_MARKER_PATTERN.test(line.trim()))
    .join('\n');
}

function getOpIndexPath(date: Date): string {
  const assetsDir = getAssetsDir(date);
  if (!existsSync(assetsDir)) {
    mkdirSync(assetsDir, { recursive: true });
  }
  return join(assetsDir, OP_INDEX_FILE);
}

function readOpIndex(date: Date): Set<string> {
  const indexPath = getOpIndexPath(date);
  if (!existsSync(indexPath)) return new Set();

  try {
    const raw = readFileSync(indexPath, 'utf8');
    const parsed = JSON.parse(raw);
    if (!Array.isArray(parsed.operations)) return new Set();
    return new Set(parsed.operations.filter((id: unknown) => validateOperationId(id)));
  } catch {
    return new Set();
  }
}

function hasOpRecord(date: Date, content: string, operationId: string): boolean {
  return readOpIndex(date).has(operationId) || content.includes(`<!-- diary-op:${operationId} -->`);
}

function recordOperation(date: Date, operationId: string): void {
  const operations = readOpIndex(date);
  operations.add(operationId);
  writeFileSync(
    getOpIndexPath(date),
    JSON.stringify({ operations: [...operations].sort() }, null, 2)
  );
}

function getRequestDate(date: unknown): Date {
  return typeof date === 'string' ? parseShanghaiDate(date) : new Date();
}

function getRequestTime(time: unknown, date: Date): string {
  if (typeof time === 'string' && /^(?:[01]\d|2[0-3]):[0-5]\d$/.test(time)) return time;
  return date.toLocaleTimeString('zh-CN', {
    timeZone: 'Asia/Shanghai',
    hour: '2-digit',
    minute: '2-digit',
    hour12: false
  });
}

const router = Router();

// 检查日记是否存在
router.get('/exists/:date', async (req, res) => {
  try {
    const dateStr = req.params.date;
    const date = parseShanghaiDate(dateStr);

    const exists = existsDiary(date);
    res.json({ exists });
  } catch (error) {
    res.status(500).json({ error: (error as Error).message });
  }
});

// 创建日记（幂等：已存在也返回成功）
router.post('/create', async (req, res) => {
  try {
    const { date, operationId } = req.body;
    let diaryDate: Date;

    if (date) {
      diaryDate = parseShanghaiDate(date);
    } else {
      diaryDate = new Date();
    }

    if (existsDiary(diaryDate)) {
      if (operationId && validateOperationId(operationId)) {
        try {
          const content = readDiary(diaryDate);
          if (hasOpRecord(diaryDate, content, operationId)) {
            return res.json({ success: true, exists: true, date: getDateString(diaryDate) });
          }
        } catch {}
      }
      return res.json({ success: true, exists: true, date: getDateString(diaryDate) });
    }

    const content = createObsidianDiaryContent(diaryDate);
    writeDiary(diaryDate, content);
    if (operationId && validateOperationId(operationId)) {
      recordOperation(diaryDate, operationId);
    }

    res.json({ success: true, exists: false, date: getDateString(diaryDate) });
  } catch (error) {
    res.status(500).json({ error: (error as Error).message });
  }
});

router.get('/:date', async (req, res) => {
  try {
    const dateStr = req.params.date;
    const date = parseShanghaiDate(dateStr);

    const content = readDiary(date);
    const entry = parseDiary(content);
    entry.date = dateStr;

    res.json(entry);
  } catch (error) {
    res.status(500).json({ error: (error as Error).message });
  }
});

router.post('/quick-note', async (req, res) => {
  try {
    const { content, tags, operationId } = req.body;
    const date = getRequestDate(req.body.date);
    const time = getRequestTime(req.body.time, date);

    const tagStr = tags?.length > 0 ? ' ' + tags.map((t: string) => `#${t}`).join(' ') : '';
    const formatted = `- **${time}** ${content}${tagStr}`;

    let originalContent: string;
    try {
      originalContent = readDiary(date);
    } catch {
      return res.status(404).json({ error: '日记文件不存在，请先创建' });
    }

    if (operationId && validateOperationId(operationId)) {
      if (hasOpRecord(date, originalContent, operationId)) {
        return res.json({ success: true, content: formatted, dedup: true });
      }
    }

    const updated = stripOldOpMarkers(appendToSection(originalContent, 'quick_notes', formatted));
    writeDiary(date, updated);
    if (operationId && validateOperationId(operationId)) {
      recordOperation(date, operationId);
    }

    res.json({ success: true, content: formatted });
  } catch (error) {
    res.status(500).json({ error: (error as Error).message });
  }
});

router.post('/habit', async (req, res) => {
  try {
    const {
      water,
      steps,
      reading,
      language,
      supplements,
      readingMinutes,
      languageMinutes,
      operationId,
      extraCheckboxes,
      extraDurations,
    } = req.body;
    const date = getRequestDate(req.body.date);

    if (!isValidCount(water) || !isValidCount(steps)) {
      return res.status(400).json({ error: '习惯数值无效' });
    }
    if (hasOwn(req.body, 'readingMinutes') && !isValidDuration(readingMinutes)) {
      return res.status(400).json({ error: '阅读时长无效' });
    }
    if (hasOwn(req.body, 'languageMinutes') && !isValidDuration(languageMinutes)) {
      return res.status(400).json({ error: '学语言时长无效' });
    }

    let originalContent: string;
    try {
      originalContent = readDiary(date);
    } catch {
      return res.status(404).json({ error: '日记文件不存在，请先创建' });
    }

    if (operationId && validateOperationId(operationId)) {
      if (hasOpRecord(date, originalContent, operationId)) {
        return res.json({ success: true, dedup: true });
      }
    }

    const existingHabitLines = parseDiary(originalContent).sections.habits;
    const existingReadingLine = existingHabitLines.find(line =>
      line.includes('📖') || line.includes('阅读/亲子共读'));
    const existingLanguageLine = existingHabitLines.find(line =>
      line.includes('🇬🇧') || line.includes('学语言'));
    const existingReadingMinutes = existingReadingLine == null
      ? null
      : durationFromHabitLine(existingReadingLine);
    const existingLanguageMinutes = existingLanguageLine == null
      ? null
      : durationFromHabitLine(existingLanguageLine);
    const readingHasDuration = hasOwn(req.body, 'readingMinutes') ||
      existingReadingMinutes !== null;
    const languageHasDuration = hasOwn(req.body, 'languageMinutes') ||
      existingLanguageMinutes !== null;
    const nextReadingMinutes = readingMinutes ?? existingReadingMinutes ?? 0;
    const nextLanguageMinutes = languageMinutes ?? existingLanguageMinutes ?? 0;

    const waterEmoji = '🥤';
    const waterCount = Math.floor(water / 250);
    const waterStr = waterCount > 0
      ? `- 🥛${waterEmoji.repeat(waterCount)}饮水 ${water} mL`
      : `- 🥛饮水 ${water} mL`;

    const habits = [
      waterStr,
      `- 🧘 运动/拉伸/快走 ${steps} 步`,
      readingHasDuration
        ? `- [${reading ? 'x' : ' '}] 📖 阅读/亲子共读 ${nextReadingMinutes} 分钟`
        : `- [${reading ? 'x' : ' '}] 📖 阅读/亲子共读`,
      languageHasDuration
        ? `- [${language ? 'x' : ' '}] 🇬🇧 学语言 ${nextLanguageMinutes} 分钟`
        : `- [${language ? 'x' : ' '}] 🇬🇧 学语言`,
      `- [${supplements ? 'x' : ' '}] 💊 鱼油/植物甾醇`
    ];

    // 追加自定义 checkbox 习惯行
    if (extraCheckboxes && typeof extraCheckboxes === 'object') {
      for (const [_, info] of Object.entries(extraCheckboxes)) {
        const item = info as any;
        if (extraDurations && typeof extraDurations === 'object' &&
            Object.prototype.hasOwnProperty.call(extraDurations, _)) {
          continue;
        }
        const mark = item.checked ? 'x' : ' ';
        const label = typeof item.label === 'string' && item.label.trim()
          ? item.label.trim()
          : '?';
        habits.push(`- [${mark}] ${label}`);
      }
    }

    const durationLabels = new Set<string>();
    const durationRawLines = new Set<string>();
    if (extraDurations && typeof extraDurations === 'object') {
      for (const [key, info] of Object.entries(extraDurations)) {
        const item = info as any;
        if (!isValidDuration(item.minutes)) {
          return res.status(400).json({ error: '自定义习惯时长无效' });
        }
        const label = cleanHabitLabel(item.label);
        if (!label) return res.status(400).json({ error: '自定义习惯名称无效' });
        durationLabels.add(label);
        if (typeof item.rawLine === 'string' && item.rawLine.trim()) {
          durationRawLines.add(item.rawLine);
        }
        const mark = item.checked ? 'x' : ' ';
        habits.push(`- [${mark}] ${label} ${item.minutes} 分钟`);
      }
    }

    // 旧客户端没有 duration 字段时，保留日记中已经存在的自定义计时行。
    for (const line of existingHabitLines) {
      if (durationFromHabitLine(line) === null) continue;
      if (durationRawLines.has(line)) continue;
      const label = habitLabelFromLine(line);
      if (label.includes('📖') || label.includes('阅读/亲子共读') ||
          label.includes('🇬🇧') || label.includes('学语言') ||
          durationLabels.has(label)) {
        continue;
      }
      habits.push(line);
    }

    const updated = stripOldOpMarkers(updateHabitsSection(originalContent, habits));
    writeDiary(date, updated);
    if (operationId && validateOperationId(operationId)) {
      recordOperation(date, operationId);
    }

    res.json({ success: true });
  } catch (error) {
    res.status(500).json({ error: (error as Error).message });
  }
});

router.post('/habit/duration', async (req, res) => {
  try {
    const {
      date: rawDate,
      habitKey,
      label: rawLabel,
      rawLine,
      minutes,
      operation,
      dailyTargetMinutes,
      operationId,
    } = req.body;
    const date = getRequestDate(rawDate);

    if (typeof habitKey !== 'string' || !/^[A-Za-z0-9_-]{1,80}$/.test(habitKey)) {
      return res.status(400).json({ error: '习惯 key 无效' });
    }
    if (!isValidDuration(minutes) || (operation !== 'add' && operation !== 'set')) {
      return res.status(400).json({ error: '习惯时长参数无效' });
    }
    if (dailyTargetMinutes != null && !isValidDuration(dailyTargetMinutes)) {
      return res.status(400).json({ error: '每日时长目标无效' });
    }
    const fallbackLabel = cleanHabitLabel(rawLabel);
    if (!fallbackLabel) return res.status(400).json({ error: '习惯名称无效' });
    if (typeof rawLine !== 'string' || rawLine.length > 500 || /[\r\n]/.test(rawLine)) {
      return res.status(400).json({ error: '习惯原始行无效' });
    }

    let originalContent: string;
    try {
      originalContent = readDiary(date);
    } catch {
      return res.status(404).json({ error: '日记文件不存在，请先创建' });
    }

    const existingLines = parseDiary(originalContent).sections.habits;
    const findExistingLine = (): string | null => {
      const exactIndex = rawLine ? existingLines.indexOf(rawLine) : -1;
      if (exactIndex !== -1) return existingLines[exactIndex];
      return existingLines.find(line => {
        const label = habitLabelFromLine(line);
        return label === fallbackLabel || label.includes(fallbackLabel);
      }) ?? null;
    };

    const target = dailyTargetMinutes == null || dailyTargetMinutes === 0
      ? null
      : dailyTargetMinutes;

    if (operationId && validateOperationId(operationId) &&
        hasOpRecord(date, originalContent, operationId)) {
      const dedupLine = findExistingLine();
      const dedupMinutes = dedupLine == null
          ? 0
          : durationFromHabitLine(dedupLine) ?? 0;
      const dedupCompleted = target == null
          ? dedupMinutes > 0
          : dedupMinutes >= target;
      return res.json({
        success: true,
        dedup: true,
        minutes: dedupMinutes,
        completed: dedupCompleted,
        rawLine: dedupLine ?? rawLine,
      });
    }

    const existingLine = findExistingLine();
    const currentMinutes = existingLine == null
      ? 0
      : durationFromHabitLine(existingLine) ?? 0;
    const nextMinutes = operation === 'add' ? currentMinutes + minutes : minutes;
    if (!isValidDuration(nextMinutes)) {
      return res.status(400).json({ error: '习惯时长超出范围' });
    }

    const completed = target == null
      ? nextMinutes > 0
      : nextMinutes >= target;
    const baseLabel = existingLine == null
      ? fallbackLabel
      : habitLabelFromLine(existingLine);
    const indent = existingLine?.match(/^\s*/)?.[0] ?? '';
    const nextLine = `${indent}- [${completed ? 'x' : ' '}] ${baseLabel} ${nextMinutes} 分钟`;
    const updated = replaceHabitLineInSection(
      originalContent,
      existingLine,
      nextLine,
    );
    if (updated === null) {
      return res.status(400).json({ error: '日记缺少习惯区块' });
    }

    writeDiary(date, stripOldOpMarkers(updated));
    if (operationId && validateOperationId(operationId)) {
      recordOperation(date, operationId);
    }
    return res.json({
      success: true,
      minutes: nextMinutes,
      completed,
      rawLine: nextLine,
    });
  } catch (error) {
    return res.status(500).json({ error: (error as Error).message });
  }
});

router.post('/happiness', async (req, res) => {
  try {
    const { content, tags, operationId } = req.body;
    const date = getRequestDate(req.body.date);
    const time = getRequestTime(req.body.time, date);

    let originalContent: string;
    try {
      originalContent = readDiary(date);
    } catch {
      return res.status(404).json({ error: '日记文件不存在，请先创建' });
    }

    if (operationId && validateOperationId(operationId)) {
      if (hasOpRecord(date, originalContent, operationId)) {
        return res.json({ success: true, dedup: true });
      }
    }

    const tagStr = tags?.length > 0 ? ' ' + tags.map((t: string) => `#${t}`).join(' ') : '';
    const formattedContent = `> **${time}** ${content}${tagStr}`;
    const updated = stripOldOpMarkers(appendToSection(originalContent, 'happiness', formattedContent));
    writeDiary(date, updated);
    if (operationId && validateOperationId(operationId)) {
      recordOperation(date, operationId);
    }

    res.json({ success: true });
  } catch (error) {
    res.status(500).json({ error: (error as Error).message });
  }
});

router.post('/reflection', async (req, res) => {
  try {
    const { content, tags, operationId } = req.body;
    const date = getRequestDate(req.body.date);
    const time = getRequestTime(req.body.time, date);

    let originalContent: string;
    try {
      originalContent = readDiary(date);
    } catch {
      return res.status(404).json({ error: '日记文件不存在，请先创建' });
    }

    if (operationId && validateOperationId(operationId)) {
      if (hasOpRecord(date, originalContent, operationId)) {
        return res.json({ success: true, dedup: true });
      }
    }

    const tagStr = tags?.length > 0 ? ' ' + tags.map((t: string) => `#${t}`).join(' ') : '';
    const formattedContent = `- **${time}** ${content}${tagStr}`;

    // Replace template placeholder "- " bullet on first write, else fall through to append
    const replaced = replaceEmptyBulletInSection(originalContent, 'reflection', formattedContent);
    if (replaced) {
      const updated = stripOldOpMarkers(replaced);
      writeDiary(date, updated);
      if (operationId && validateOperationId(operationId)) {
        recordOperation(date, operationId);
      }
      return res.json({ success: true });
    }

    const updated = stripOldOpMarkers(appendToSection(originalContent, 'reflection', formattedContent));
    writeDiary(date, updated);
    if (operationId && validateOperationId(operationId)) {
      recordOperation(date, operationId);
    }

    res.json({ success: true });
  } catch (error) {
    res.status(500).json({ error: (error as Error).message });
  }
});

router.post('/anxiety', async (req, res) => {
  try {
    const { content, tags, operationId } = req.body;
    const date = getRequestDate(req.body.date);

    let originalContent: string;
    try {
      originalContent = readDiary(date);
    } catch {
      return res.status(404).json({ error: '日记文件不存在，请先创建' });
    }

    if (operationId && validateOperationId(operationId)) {
      if (hasOpRecord(date, originalContent, operationId)) {
        return res.json({ success: true, dedup: true });
      }
    }

    const tagStr = tags?.length > 0 ? ' ' + tags.map((t: string) => `#${t}`).join(' ') : '';
    const formattedContent = `${content}${tagStr}`;
    const updated = stripOldOpMarkers(appendToSection(originalContent, 'anxiety', formattedContent));
    writeDiary(date, updated);
    if (operationId && validateOperationId(operationId)) {
      recordOperation(date, operationId);
    }

    res.json({ success: true });
  } catch (error) {
    res.status(500).json({ error: (error as Error).message });
  }
});

// 替换焦虑四问区块
router.post('/anxiety/replace', async (req, res) => {
  try {
    const { content, operationId } = req.body;
    const date = getRequestDate(req.body.date);

    if (!content || typeof content !== 'string' || !content.trim()) {
      return res.status(400).json({ error: '内容不能为空' });
    }

    let originalContent: string;
    try {
      originalContent = readDiary(date);
    } catch {
      return res.status(404).json({ error: '日记文件不存在，请先创建' });
    }

    if (operationId && validateOperationId(operationId)) {
      if (hasOpRecord(date, originalContent, operationId)) {
        return res.json({ success: true, dedup: true });
      }
    }

    const updated = replaceAnxietySection(originalContent, content);
    writeDiary(date, updated);
    if (operationId && validateOperationId(operationId)) {
      recordOperation(date, operationId);
    }

    res.json({ success: true });
  } catch (error) {
    res.status(500).json({ error: (error as Error).message });
  }
});

// 替换荔枝喵说区块
router.post('/lizhi-says', async (req, res) => {
  try {
    const { date, content } = req.body;
    const diaryDate = date
      ? parseShanghaiDate(date)
      : new Date();

    let originalContent: string;
    try {
      originalContent = readDiary(diaryDate);
    } catch {
      return res.status(404).json({ error: '日记文件不存在，请先创建' });
    }

    const updated = replaceLizhiSaysSection(originalContent, content);
    writeDiary(diaryDate, updated);

    res.json({ success: true });
  } catch (error) {
    res.status(500).json({ error: (error as Error).message });
  }
});

// 追加明日寄语
router.post('/tomorrow', async (req, res) => {
  try {
    const { date, content } = req.body;
    const diaryDate = date
      ? parseShanghaiDate(date)
      : new Date();

    let originalContent: string;
    try {
      originalContent = readDiary(diaryDate);
    } catch {
      return res.status(404).json({ error: '日记文件不存在，请先创建' });
    }

    const updated = replaceTomorrowSection(originalContent, content);
    writeDiary(diaryDate, updated);

    res.json({ success: true });
  } catch (error) {
    res.status(500).json({ error: (error as Error).message });
  }
});

// 上传图片（远程模式）：接收 base64 压缩图片，保存到 assets 并追加 WikiLink
router.post('/image/upload', async (req, res) => {
  try {
    const { date: dateStr, imageData, operationId, imagePrefix } = req.body;
    const uploadDate = parseShanghaiDate(dateStr);
    const [year, monthNum, day] = dateStr.split('-').map(Number);

    let originalContent: string;
    try {
      originalContent = readDiary(uploadDate);
    } catch {
      return res.status(404).json({ error: '日记文件不存在，请先创建' });
    }

    if (operationId && validateOperationId(operationId)) {
      if (hasOpRecord(uploadDate, originalContent, operationId)) {
        return res.json({ success: true, dedup: true });
      }
    }

    const assetsDir = getAssetsDir(uploadDate);
    if (!existsSync(assetsDir)) {
      mkdirSync(assetsDir, { recursive: true });
    }

    // 扫描已有文件确定序号
    const dayPrefix = `${year}${monthNum.toString().padStart(2, '0')}${day.toString().padStart(2, '0')}`;
    let safeImagePrefix: string;
    try {
      safeImagePrefix = sanitizeImagePrefix(imagePrefix);
    } catch (error) {
      return res.status(400).json({ error: (error as Error).message });
    }
    const prefix = `${safeImagePrefix}-${dayPrefix}-`;

    let maxSeq = 0;
    if (existsSync(assetsDir)) {
      const files = readdirSync(assetsDir);
      for (const file of files) {
        if (file.startsWith(prefix) && file.endsWith('.jpg')) {
          const seqStr = file.slice(prefix.length, -4);
          const seq = parseInt(seqStr);
          if (!isNaN(seq) && seq > maxSeq) maxSeq = seq;
        }
      }
    }

    const seq = (maxSeq + 1).toString().padStart(3, '0');
    const filename = `${prefix}${seq}.jpg`;

    // 解码 base64
    const base64Data = imageData.replace(/^data:image\/\w+;base64,/, '');
    const buffer = Buffer.from(base64Data, 'base64');

    if (buffer.length === 0) {
      return res.status(400).json({ error: '图片数据为空' });
    }
    if (buffer.length > 10 * 1024 * 1024) {
      return res.status(400).json({ error: '图片文件过大' });
    }
    if (!isImageBuffer(buffer)) {
      return res.status(400).json({ error: '不是有效的图片数据' });
    }

    // 写入图片文件
    const imagePath = join(assetsDir, filename);
    writeFileSync(imagePath, buffer);

    // 追加 WikiLink；幂等索引写入旁路文件，避免污染日记正文
    const wikiLink = `![[${filename}]]`;
    const contentWithImages = ensureImagesSection(originalContent);
    const updated = stripOldOpMarkers(appendToSection(contentWithImages, 'images', wikiLink));
    try {
      writeDiary(uploadDate, updated);
      if (operationId && validateOperationId(operationId)) {
        recordOperation(uploadDate, operationId);
      }
    } catch (error) {
      unlinkSync(imagePath);
      throw error;
    }

    res.json({ success: true, filename });
  } catch (error) {
    res.status(500).json({ error: (error as Error).message });
  }
});

function replaceLizhiSaysSection(content: string, newText: string): string {
  const lines = content.split('\n');
  const newHeader = '### 🧠 人生教练';
  const oldHeader = '### 🧠 荔枝喵说';

  let startIndex = -1;
  let endIndex = -1;

  for (let i = 0; i < lines.length; i++) {
    if (lines[i].startsWith(newHeader) || lines[i].startsWith(oldHeader)) {
      startIndex = i;
      break;
    }
  }

  if (startIndex === -1) return content;

  const allHeaders = ['## 🏃 习惯打卡', '## ✍️ 随手记', '## ✨ 每日小确幸',
    '## 😰 焦虑时刻', '### 💡 觉察与迭代', newHeader, oldHeader, '### 🌙 明日寄语', '## 📸 影像记录'];
  for (let i = startIndex + 1; i < lines.length; i++) {
    if (allHeaders.some(h => lines[i].startsWith(h))) {
      endIndex = i;
      break;
    }
  }

  if (endIndex === -1) endIndex = lines.length;

  const newLines = newText.split('\n').map(l => l.trim() ? `- ${l}` : l);
  const before = lines.slice(0, startIndex);
  const after = lines.slice(endIndex);

  return [...before, newHeader, ...newLines, '', ...after].join('\n');
}

function replaceTomorrowSection(content: string, newText: string): string {
  const lines = content.split('\n');
  const header = '### 🌙 明日寄语';

  let startIndex = -1;
  let endIndex = -1;

  for (let i = 0; i < lines.length; i++) {
    if (lines[i].startsWith(header)) {
      startIndex = i;
      break;
    }
  }

  if (startIndex === -1) return content;

  const allHeaders = ['## 🏃 习惯打卡', '## ✍️ 随手记', '## ✨ 每日小确幸',
    '## 😰 焦虑时刻', '### 💡 觉察与迭代', '### 🧠 人生教练',
    '### 🧠 荔枝喵说', '### 🌙 明日寄语', '## 📸 影像记录'];
  for (let i = startIndex + 1; i < lines.length; i++) {
    if (allHeaders.some(h => lines[i].startsWith(h))) {
      endIndex = i;
      break;
    }
  }

  if (endIndex === -1) endIndex = lines.length;

  const newLines = newText.split('\n').map(l => l.trim() ? `- ${l}` : l);
  const before = lines.slice(0, startIndex);
  const after = lines.slice(endIndex);

  return [...before, header, ...newLines, '', ...after].join('\n');
}

function updateHabitsSection(content: string, habits: string[]): string {
  const lines = content.split('\n');
  const header = '## 🏃 习惯打卡';

  let startIndex = -1;
  let endIndex = -1;

  for (let i = 0; i < lines.length; i++) {
    if (lines[i].startsWith(header)) {
      startIndex = i;
      break;
    }
  }

  if (startIndex === -1) return content;

  const allHeaders = ['## 🏃 习惯打卡', '## ✍️ 随手记', '## ✨ 每日小确幸', '## 😰 焦虑时刻', '### 💡 觉察与迭代'];
  for (let i = startIndex + 1; i < lines.length; i++) {
    if (allHeaders.some(h => lines[i].startsWith(h))) {
      endIndex = i;
      break;
    }
  }

  if (endIndex === -1) endIndex = lines.length;

  const before = lines.slice(0, startIndex + 1);
  const after = lines.slice(endIndex);

  return [...before, ...habits, '', ...after].join('\n');
}

function replaceHabitLineInSection(
  content: string,
  existingLine: string | null,
  nextLine: string,
): string | null {
  const lines = content.split('\n');
  const header = '## 🏃 习惯打卡';
  const startIndex = lines.findIndex(line => line.startsWith(header));
  if (startIndex === -1) return null;

  let endIndex = lines.length;
  for (let i = startIndex + 1; i < lines.length; i++) {
    if (/^(?:##|###)\s/.test(lines[i])) {
      endIndex = i;
      break;
    }
  }

  if (existingLine != null) {
    const exactIndex = lines.findIndex(
      (line, index) => index > startIndex && index < endIndex && line === existingLine,
    );
    if (exactIndex !== -1) {
      lines[exactIndex] = nextLine;
      return lines.join('\n');
    }
  }

  let insertIndex = endIndex;
  while (insertIndex > startIndex + 1 && lines[insertIndex - 1].trim() === '') {
    insertIndex--;
  }
  lines.splice(insertIndex, 0, nextLine);
  return lines.join('\n');
}

function replaceAnxietySection(content: string, newText: string): string {
  const lines = content.split('\n');
  const header = '## 😰 焦虑时刻';

  let startIndex = -1;
  let endIndex = -1;

  for (let i = 0; i < lines.length; i++) {
    if (lines[i].startsWith(header)) {
      startIndex = i;
      break;
    }
  }

  if (startIndex === -1) {
    // Section doesn't exist — create it before the next section or at end
    const insertHeaders = ['## 🏃 习惯打卡', '## ✍️ 随手记', '## ✨ 每日小确幸', '### 💡 觉察与迭代',
      '### 🧠 人生教练', '### 🌙 明日寄语', '## 📸 影像记录'];
    let insertIndex = lines.length;
    for (let i = 0; i < lines.length; i++) {
      if (insertHeaders.some(h => lines[i].startsWith(h))) {
        insertIndex = i;
        break;
      }
    }
    const newLines = newText.split('\n');
    const before = lines.slice(0, insertIndex);
    const after = lines.slice(insertIndex);
    return [...before, header, ...newLines, '', ...after].join('\n');
  }

  const allHeaders = ['## 🏃 习惯打卡', '## ✍️ 随手记', '## ✨ 每日小确幸',
    '## 😰 焦虑时刻', '### 💡 觉察与迭代', '### 🧠 人生教练', '### 🌙 明日寄语', '## 📸 影像记录'];
  for (let i = startIndex + 1; i < lines.length; i++) {
    if (allHeaders.some(h => lines[i].startsWith(h))) {
      endIndex = i;
      break;
    }
  }

  if (endIndex === -1) endIndex = lines.length;

  const newLines = newText.split('\n');
  const before = lines.slice(0, startIndex + 1);
  const after = lines.slice(endIndex);

  return [...before, ...newLines, '', ...after].join('\n');
}

router.get('/image/render/:year/:imageName', async (req, res) => {
  try {
    const year = Number(req.params.year);
    const imageName = req.params.imageName;
    const month = req.query.month == null ? null : Number(req.query.month);
    const rawMaxWidth = req.query.maxWidth == null
      ? 480
      : Number(req.query.maxWidth);

    if (!Number.isInteger(year) || year < 1000 || year > 9999) {
      return res.status(400).json({ error: 'Invalid year' });
    }
    if (month !== null && (!Number.isInteger(month) || month < 1 || month > 12)) {
      return res.status(400).json({ error: 'Invalid month' });
    }
    if (!Number.isInteger(rawMaxWidth) || rawMaxWidth < 64 || rawMaxWidth > 2000) {
      return res.status(400).json({ error: 'Invalid maxWidth' });
    }
    if (!isSafeImageName(imageName)) {
      return res.status(400).json({ error: 'Invalid image name' });
    }

    const imagePath = resolveImagePath(year, imageName, month);
    if (!imagePath) return res.status(404).json({ error: 'Image not found' });

    let imageBuffer: Buffer;
    try {
      imageBuffer = readFileSync(imagePath);
    } catch {
      // 文件可能在检查与读取之间被移除，不把本地路径暴露给客户端。
      return res.status(404).json({ error: 'Image not found' });
    }
    try {
      const rendered = await sharp(imageBuffer, { failOn: 'none' })
        .rotate()
        .resize({ width: rawMaxWidth, withoutEnlargement: true })
        .webp({ quality: 82 })
        .toBuffer();

      return res
        .type('image/webp')
        .set('Cache-Control', 'private, max-age=86400')
        .set('Vary', 'Authorization')
        .send(rendered);
    } catch {
      // 少数格式或损坏图片无法由 sharp 转换时，仍返回原图，保持旧链路可用。
      return res
        .type(getMimeType(imageName))
        .set('Cache-Control', 'private, max-age=86400')
        .set('Vary', 'Authorization')
        .send(imageBuffer);
    }
  } catch (error) {
    res.status(500).json({ error: (error as Error).message });
  }
});

router.get('/image/:year/:imageName', async (req, res) => {
  try {
    const year = Number(req.params.year);
    const imageName = req.params.imageName;
    const month = req.query.month ? Number(req.query.month) : null;

    if (!Number.isInteger(year) || year < 1000 || year > 9999) {
      return res.status(400).json({ error: 'Invalid year' });
    }
    if (month !== null && (!Number.isInteger(month) || month < 1 || month > 12)) {
      return res.status(400).json({ error: 'Invalid month' });
    }
    if (!isSafeImageName(imageName)) {
      return res.status(400).json({ error: 'Invalid image name' });
    }

    const imagePath = resolveImagePath(year, imageName, month);

    if (!imagePath) {
      return res.status(404).json({ error: 'Image not found' });
    }

    let imageBuffer: Buffer;
    try {
      imageBuffer = readFileSync(imagePath);
    } catch {
      return res.status(404).json({ error: 'Image not found' });
    }
    const base64 = imageBuffer.toString('base64');
    const mimeType = getMimeType(imageName);

    res.json({
      data: `data:${mimeType};base64,${base64}`,
      mimeType
    });
  } catch (error) {
    res.status(500).json({ error: (error as Error).message });
  }
});

function getFirstLine(grouped: string): string {
  return grouped.split('\n\n')[0];
}

function extractImageName(line: string): string | null {
  const match = line.match(/!\[\[([^/\\\]]+\.(?:jpg|jpeg|png|gif|webp|heic|heif))\]\]/i);
  return match ? match[1] : null;
}

function findAllMatches(lines: string[], startIdx: number, endIdx: number, target: string): number[] {
  const matches: number[] = [];
  for (let i = startIdx; i < endIdx; i++) {
    if (lines[i].trim() === target.trim()) matches.push(i);
  }
  return matches;
}

function isEntryOrBoundary(line: string): boolean {
  const t = line.trim();
  if (t.startsWith('- ') || t.startsWith('> ')) return true;
  if (t.startsWith('##') || t.startsWith('###')) return true;
  if (t.startsWith('---')) return true;
  if (t.startsWith('![[')) return true;
  if (/^- \[[ x]\]/.test(t)) return true;
  return false;
}

function findSectionBounds(lines: string[], header: string): { start: number; end: number } | null {
  const LEGACY_LIZHI_SAYS = '### 🧠 荔枝喵说';
  const allHeaders = [...Object.values(sectionHeaders), LEGACY_LIZHI_SAYS, '## 📈 每日复盘'];
  let start = -1;
  for (let i = 0; i < lines.length; i++) {
    if (lines[i].startsWith(header)) { start = i; break; }
  }
  if (start === -1) return null;
  let end = lines.length;
  for (let i = start + 1; i < lines.length; i++) {
    if (allHeaders.some(h => lines[i].startsWith(h))) { end = i; break; }
  }
  return { start, end };
}

function findEntryRangeInSection(
  lines: string[], _startIdx: number, endIdx: number,
  targetLine: string, matches: number[]
): { startIndex: number; endIndexExclusive: number } | null {
  if (matches.length === 0) return null;

  const targetLines = targetLine.split(/\n\n|\n/).filter(l => l.trim());
  if (targetLines.length > 1) {
    const exactMatch = matches.find(matchIndex =>
      targetLines.every((target, offset) =>
        matchIndex + offset < endIdx && lines[matchIndex + offset].trim() === target.trim()
      )
    );
    if (exactMatch !== undefined) {
      return { startIndex: exactMatch, endIndexExclusive: exactMatch + targetLines.length };
    }
  }

  if (matches.length > 1) {
    console.warn(`Duplicate entry first line at indices ${matches.join(', ')}; using first`);
  }
  const i = matches[0];
  let end = i + 1;
  while (end < endIdx) {
    if (isEntryOrBoundary(lines[end].trim())) break;
    end++;
  }
  while (end > i + 1 && lines[end - 1].trim() === '') end--;
  return { startIndex: i, endIndexExclusive: end };
}

router.post('/delete-entry', async (req, res) => {
  try {
    const { date: dateStr, section, line } = req.body;
    if (!dateStr || !section || !line) return res.status(400).json({ error: '缺少 date, section 或 line' });
    const date = getRequestDate(dateStr);
    const content = readDiary(date);
    const lines = content.split('\n');
    const header = sectionHeaders[section];
    if (!header) return res.status(400).json({ error: '未知区块' });
    const bounds = findSectionBounds(lines, header);
    if (!bounds) return res.status(404).json({ error: '区块未找到' });

    const firstLine = getFirstLine(line);
    const matches = findAllMatches(lines, bounds.start + 1, bounds.end, firstLine);
    if (matches.length === 0) return res.status(404).json({ error: '条目未找到' });

    const range = findEntryRangeInSection(lines, bounds.start + 1, bounds.end, line, matches);
    if (!range) return res.status(404).json({ error: '条目未找到' });

    const imageName = section === 'images' ? extractImageName(firstLine) : null;
    lines.splice(range.startIndex, range.endIndexExclusive - range.startIndex);
    const updatedContent = lines.join('\n');
    writeDiary(date, updatedContent);
    if (imageName && isSafeImageName(imageName) && !updatedContent.includes(`![[${imageName}]]`)) {
      try {
        const imagePath = getSafeAssetPath(getAssetsDir(date), imageName);
        if (existsSync(imagePath)) unlinkSync(imagePath);
      } catch {
        // 图片路径异常时保留文件，不能让已完成的日记删除操作返回失败。
      }
    }
    res.json({ success: true });
  } catch (error) {
    res.status(500).json({ error: (error as Error).message });
  }
});

router.post('/edit-entry', async (req, res) => {
  try {
    const { date: dateStr, section, target, replacement } = req.body;
    if (!dateStr || !section || !target || !replacement) return res.status(400).json({ error: '缺少参数' });
    const date = getRequestDate(dateStr);
    const content = readDiary(date);
    const lines = content.split('\n');
    const header = sectionHeaders[section];
    if (!header) return res.status(400).json({ error: '未知区块' });
    const bounds = findSectionBounds(lines, header);
    if (!bounds) return res.status(404).json({ error: '区块未找到' });

    const firstLine = getFirstLine(target);
    const matches = findAllMatches(lines, bounds.start + 1, bounds.end, firstLine);
    if (matches.length === 0) return res.status(404).json({ error: '条目未找到' });

    const range = findEntryRangeInSection(lines, bounds.start + 1, bounds.end, target, matches);
    if (!range) return res.status(404).json({ error: '条目未找到' });

    const newLines = replacement.split('\n');
    lines.splice(range.startIndex, range.endIndexExclusive - range.startIndex, ...newLines);
    writeDiary(date, sortTimelineEntriesInSection(lines.join('\n'), section));
    res.json({ success: true });
  } catch (error) {
    res.status(500).json({ error: (error as Error).message });
  }
});

function isSafeImageName(imageName: string): boolean {
  return SAFE_IMAGE_NAME_PATTERN.test(imageName);
}

function getSafeAssetPath(assetsDir: string, imageName: string): string {
  const resolvedAssetsDir = resolve(assetsDir);
  const imagePath = resolve(resolvedAssetsDir, imageName);
  const relativePath = relative(resolvedAssetsDir, imagePath);

  if (!relativePath || relativePath.startsWith('..') || isAbsolute(relativePath)) {
    throw new Error('Invalid image path');
  }

  // 字符串路径位于 assets 目录内并不代表真实文件没有通过符号链接逃逸。
  // 仅对已存在的路径做 realpath 校验，避免缺失目录仍能正常返回 404。
  if (existsSync(imagePath)) {
    const realVaultPath = realpathSync(resolve(config.vaultPath));
    const realAssetsDir = realpathSync(resolvedAssetsDir);
    const realImagePath = realpathSync(imagePath);
    const vaultRelativePath = relative(realVaultPath, realAssetsDir);
    const realRelativePath = relative(realAssetsDir, realImagePath);
    if (
      !vaultRelativePath ||
      vaultRelativePath.startsWith('..') ||
      isAbsolute(vaultRelativePath) ||
      !realRelativePath ||
      realRelativePath.startsWith('..') ||
      isAbsolute(realRelativePath)
    ) {
      throw new Error('Invalid image path');
    }
  }

  return imagePath;
}

// 旧格式日记没有「影像记录」区块时，在末尾补建一个再追加 WikiLink。
function ensureImagesSection(content: string): string {
  if (content.includes(sectionHeaders.images)) return content;
  return `${content.trimEnd()}\n\n---\n${sectionHeaders.images}\n`;
}

function isImageBuffer(buffer: Buffer): boolean {
  if (buffer.length < 12) return false;

  // JPEG: FF D8 FF
  if (buffer[0] === 0xff && buffer[1] === 0xd8 && buffer[2] === 0xff) return true;
  // PNG: 89 50 4E 47
  if (buffer[0] === 0x89 && buffer[1] === 0x50 && buffer[2] === 0x4e && buffer[3] === 0x47) return true;
  // GIF: GIF8
  if (buffer.toString('latin1', 0, 4) === 'GIF8') return true;
  // WebP: RIFF....WEBP
  if (
    buffer.toString('latin1', 0, 4) === 'RIFF' &&
    buffer.toString('latin1', 8, 12) === 'WEBP'
  ) {
    return true;
  }
  // HEIC/HEIF: ftyp....heic|heix|heif|mif1|msf1
  if (buffer.toString('latin1', 4, 8) === 'ftyp' &&
      /^(heic|heix|heif|mif1|msf1)/.test(buffer.toString('latin1', 8, 12))) {
    return true;
  }
  return false;
}

function getMimeType(filename: string): string {
  const ext = filename.toLowerCase().split('.').pop();
  const mimeTypes: Record<string, string> = {
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
    'gif': 'image/gif',
    'webp': 'image/webp',
    'heic': 'image/heic',
    'heif': 'image/heif'
  };
  return mimeTypes[ext || ''] || 'image/jpeg';
}

export default router;
