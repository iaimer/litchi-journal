import { Router, type Response } from 'express';
import { DiaryWriteError } from '../services/diary-write-error.js';
import { isWaterLine, isStepsLine, isReadingLine, isLanguageLine, isSupplementLine } from '../services/habit-identity.js';
import {
  readDiary,
  DiaryNotFoundError,
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
import {
  appendToSection,
  findTimelineEntryBlockEnd,
  isTimelineEntryStart,
  parseDiary,
  replaceEmptyBulletInSection,
  sectionHeaders,
  sortTimelineEntriesInSection,
} from '../services/markdown.js';
import { createObsidianDiaryContent } from '../services/template.js';
import { parseShanghaiDate } from '../utils/date.js';

const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const ENTRY_ID_MARKER_PATTERN = /^<!-- litchi-entry-id:([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}) -->$/i;
const PHOTO_ASSOCIATION_PATTERN = /^<!-- litchi-photo-of:([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})(?:;op:([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}))? -->$/i;
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

function singleLineHabitLabel(value: unknown): string | null {
  if (typeof value !== 'string') return null;
  if (/[\r\n]/.test(value)) return null;
  const label = value.trim();
  if (!label || label.length > 120) return null;
  return label;
}

function cleanHabitLabel(value: unknown): string | null {
  const label = singleLineHabitLabel(value);
  return label?.replace(/\s+\d+\s*(?:分钟|min)\s*$/i, '').trim() || null;
}

function formatTimelineEntry(
  prefix: '-' | '>',
  time: string,
  content: unknown,
  tags: unknown,
  entryId?: string,
): string {
  const body = typeof content === 'string' ? content.trim() : '';
  const bodyLines = body.split(/\r?\n/);
  const continuationPrefix = prefix === '>' ? '> ' : '  ';
  const firstPrefix = `${prefix} **${time}** `;
  const formattedLines = bodyLines.map((line, index) => {
    const linePrefix = index === 0 ? firstPrefix : continuationPrefix;
    return `${linePrefix}${line.trimEnd()}`;
  });
  const tagStr = Array.isArray(tags) && tags.length > 0
    ? ` ${tags.map((tag) => `#${tag}`).join(' ')}`
    : '';
  const entryMarker = entryId ? `\n<!-- litchi-entry-id:${entryId} -->` : '';
  return `${formattedLines.join('\n')}${tagStr}${entryMarker}`;
}

function entryIdFromLines(lines: string[]): string | null {
  const match = ENTRY_ID_MARKER_PATTERN.exec(lines[lines.length - 1]?.trimEnd() ?? '');
  return match?.[1]?.toLowerCase() ?? null;
}

function findTimelineEntryById(
  content: string,
  entryId: string,
): { section: 'quick_notes' | 'happiness'; start: number; end: number } | null {
  const lines = content.split('\n');
  for (const section of ['quick_notes', 'happiness'] as const) {
    const bounds = findSectionBounds(lines, sectionHeaders[section]);
    if (!bounds) continue;
    for (let index = bounds.start + 1; index < bounds.end; index++) {
      if (!isTimelineEntryStart(lines[index].trim())) continue;
      const end = findTimelineEntryBlockEnd(lines, index, bounds.end);
      if (entryIdFromLines(lines.slice(index, end)) === entryId.toLowerCase()) {
        return { section, start: index, end };
      }
      index = end - 1;
    }
  }
  return null;
}

function filenameForUploadOperation(content: string, operationId: string): string | null {
  const lines = content.split('\n');
  for (let index = 0; index < lines.length - 1; index++) {
    const association = PHOTO_ASSOCIATION_PATTERN.exec(lines[index + 1].trim());
    const standalone = /^<!-- litchi-upload-op:([0-9a-f-]{36}) -->$/i.exec(lines[index + 1]);
    if ((association?.[2] ?? standalone?.[1])?.toLowerCase() !== operationId.toLowerCase()) continue;
    const match = /^!\[\[([^/\\\]]+\.(?:jpg|jpeg|png|gif|webp|heic|heif))\]\]$/i.exec(lines[index].trim());
    if (match) return match[1];
  }
  return null;
}

function countPhotosForEntry(content: string, entryId: string): number {
  const lines = content.split('\n');
  const bounds = findSectionBounds(lines, sectionHeaders.images);
  if (!bounds) return 0;

  let count = 0;
  for (let index = bounds.start + 1; index + 1 < bounds.end; index++) {
    if (!extractImageName(lines[index].trim())) continue;
    const association = PHOTO_ASSOCIATION_PATTERN.exec(lines[index + 1].trim());
    if (association?.[1]?.toLowerCase() === entryId.toLowerCase()) count++;
  }
  return count;
}

function hasOwn(body: Record<string, unknown>, key: string): boolean {
  return Object.prototype.hasOwnProperty.call(body, key);
}

function readOpIndex(date: Date): Set<string> {
  const indexPath = join(getAssetsDir(date), OP_INDEX_FILE);
  if (!existsSync(indexPath)) return new Set();
  try {
    const parsed = JSON.parse(readFileSync(indexPath, 'utf8'));
    if (!Array.isArray(parsed.operations) ||
        parsed.operations.some((id: unknown) => !validateOperationId(id))) {
      throw new Error('invalid operation index');
    }
    return new Set(parsed.operations.map((id: string) => id.toLowerCase()));
  } catch {
    throw new DiaryWriteError('旧操作记录无法读取，请检查服务器操作索引后重试');
  }
}

function hasOpRecord(date: Date, content: string, operationId: string): boolean {
  const normalized = operationId.toLowerCase();
  const committed = content.split('\n').some(line =>
    line.trimEnd().toLowerCase() === `<!-- diary-op:${normalized} -->`);
  return committed || filenameForUploadOperation(content, normalized) !== null ||
    readOpIndex(date).has(normalized);
}

function commitDiary(date: Date, content: string, operationId?: unknown): void {
  const validId = validateOperationId(operationId);
  if (!validId) {
    writeDiary(date, content);
    return;
  }
  const lines = content.split('\n');
  // 标记放在 frontmatter 之后、正文之前，章节替换不会删掉已提交历史。
  const yamlEnd = lines[0] === '---' ? lines.indexOf('---', 1) : -1;
  lines.splice(yamlEnd < 0 ? 0 : yamlEnd + 1, 0, `<!-- diary-op:${validId.toLowerCase()} -->`);
  writeDiary(date, lines.join('\n'));
}

function sendWriteError(res: Response, error: unknown): void {
  if (error instanceof DiaryNotFoundError) {
    res.status(404).json({ error: '日记文件不存在，请先创建' });
    return;
  }
  if (error instanceof DiaryWriteError) {
    res.status(error.statusCode).json({ error: error.message });
    return;
  }
  res.status(500).json({ error: '日记保存失败，请检查服务器状态后重试' });
}

function getRequestDate(date: unknown): Date {
  if (date === undefined) return new Date();
  try {
    if (typeof date === 'string') return parseShanghaiDate(date);
  } catch {
    // 输入错误与磁盘错误分开，不能把无效日期写到今天。
  }
  throw new DiaryWriteError('日期无效，请使用 YYYY-MM-DD', 400);
}

function getRequestTime(time: unknown, _date: Date): string {
  if (time !== undefined) {
    if (typeof time === 'string' && /^(?:[01]\d|2[0-3]):[0-5]\d$/.test(time)) return time;
    throw new DiaryWriteError('时间无效，请使用 HH:mm', 400);
  }
  return new Date().toLocaleTimeString('zh-CN', {
    timeZone: 'Asia/Shanghai', hour: '2-digit', minute: '2-digit', hour12: false,
  });
}

function assertWriteInput(body: Record<string, unknown>): void {
  if (!body || typeof body !== 'object' || Array.isArray(body)) {
    throw new DiaryWriteError('请求内容无效', 400);
  }
  getRequestDate(body.date);
  if (body.time !== undefined) getRequestTime(body.time, new Date());
  if (body.operationId !== undefined && !validateOperationId(body.operationId)) {
    throw new DiaryWriteError('操作标识无效，请重新打开记录页后重试', 400);
  }
  if (body.tags !== undefined && (!Array.isArray(body.tags) || body.tags.length > 64 ||
      body.tags.some(tag => typeof tag !== 'string' || !tag.trim() || tag.length > 120 || /[\r\n]/.test(tag)))) {
    throw new DiaryWriteError('标签无效，请使用单行标签', 400);
  }
  if (body.content !== undefined && (typeof body.content !== 'string' || !body.content.trim())) {
    throw new DiaryWriteError('内容不能为空', 400);
  }
}

function rejectSystemMarkers(text: string): void {
  if (text.split(/\r?\n/).some(line => (/^<!--\s*(?:diary-op|litchi-entry-id|litchi-upload-op)\s*:/i.test(line.trimEnd()) || /^<!--\s*litchi-photo-of\s*:/i.test(line.trim())))) {
    throw new DiaryWriteError('正文包含系统保留标记，请移除后重试', 400);
  }
}

function safeAnxietyContent(value: unknown): string {
  if (typeof value !== 'string' || !value.trim()) throw new DiaryWriteError('内容不能为空', 400);
  const normalized = value.trim();
  rejectSystemMarkers(normalized);
  return normalized.split(/\r?\n/).map(line => /^#{1,6}\s/.test(line) ? `\\${line}` : line).join('\n');
}

const router = Router();

// 检查日记是否存在
router.get('/exists/:date', async (req, res) => {
  try {
    const dateStr = req.params.date;
    const date = getRequestDate(dateStr);

    const exists = existsDiary(date);
    res.json({ exists });
  } catch (error) {
    sendWriteError(res, error);
  }
});

// 创建日记（幂等：已存在也返回成功）
router.post('/create', async (req, res) => {
  try {
    assertWriteInput(req.body);
    const { date, operationId } = req.body;
    const diaryDate = getRequestDate(date);

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
    commitDiary(diaryDate, content, operationId);

    res.json({ success: true, exists: false, date: getDateString(diaryDate) });
  } catch (error) {
    sendWriteError(res, error);
  }
});

router.get('/:date', async (req, res) => {
  let date: Date;
  const dateStr = req.params.date;
  try {
    date = parseShanghaiDate(dateStr);
  } catch {
    return res.status(400).json({ error: '日期无效，请使用 YYYY-MM-DD' });
  }

  try {
    const content = readDiary(date);
    const entry = parseDiary(content);
    entry.date = dateStr;

    res.json(entry);
  } catch (error) {
    if (error instanceof DiaryNotFoundError) {
      return res.status(404).json({ error: '日记不存在' });
    }
    res.status(500).json({ error: '日记读取失败，请检查服务器状态' });
  }
});

router.post('/quick-note', async (req, res) => {
  try {
    assertWriteInput(req.body);
    const { content, tags, operationId } = req.body;
    const requestedEntryId = req.body.entryId == null ? null : validateOperationId(req.body.entryId);
    if (req.body.entryId != null && !requestedEntryId) {
      return res.status(400).json({ error: '记录关联标识无效' });
    }
    const entryId = requestedEntryId ?? undefined;
    const date = getRequestDate(req.body.date);
    const time = getRequestTime(req.body.time, date);

    const formatted = formatTimelineEntry('-', time, content, tags, entryId);

    const originalContent = readDiary(date);

    if (operationId && validateOperationId(operationId)) {
      if (hasOpRecord(date, originalContent, operationId)) {
        return res.json({ success: true, content: formatted, dedup: true });
      }
    }

    const updated = appendToSection(originalContent, 'quick_notes', formatted);
    commitDiary(date, updated, operationId);

    res.json({ success: true, content: formatted, entryId });
  } catch (error) {
    sendWriteError(res, error);
  }
});

router.post('/habit', async (req, res) => {
  try {
    assertWriteInput(req.body);
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

    const originalContent = readDiary(date);

    if (operationId && validateOperationId(operationId)) {
      if (hasOpRecord(date, originalContent, operationId)) {
        return res.json({ success: true, dedup: true });
      }
    }

    const existingHabitLines = readHabitLines(originalContent);
    const existingReadingLine = existingHabitLines.find(line =>
      isReadingLine(line));
    const existingLanguageLine = existingHabitLines.find(line =>
      isLanguageLine(line));
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
    const sourceLines = new Map<string, string>();

    // 追加自定义 checkbox 习惯行
    if (extraCheckboxes && typeof extraCheckboxes === 'object') {
      for (const [_, info] of Object.entries(extraCheckboxes)) {
        const item = info as any;
        if (extraDurations && typeof extraDurations === 'object' &&
            Object.prototype.hasOwnProperty.call(extraDurations, _)) {
          continue;
        }
        const mark = item.checked ? 'x' : ' ';
        const label = singleLineHabitLabel(item.label);
        if (!label) return res.status(400).json({ error: '自定义习惯名称无效' });
        if (typeof item.rawLine === 'string' && item.rawLine) sourceLines.set(label, item.rawLine);
        habits.push(`- [${mark}] ${label}`);
      }
    }

    if (extraDurations && typeof extraDurations === 'object') {
      for (const [key, info] of Object.entries(extraDurations)) {
        const item = info as any;
        if (!isValidDuration(item.minutes)) {
          return res.status(400).json({ error: '自定义习惯时长无效' });
        }
        const label = cleanHabitLabel(item.label);
        if (!label) return res.status(400).json({ error: '自定义习惯名称无效' });
        if (typeof item.rawLine === 'string' && item.rawLine.trim()) {
          sourceLines.set(label, item.rawLine);
        }
        const mark = item.checked ? 'x' : ' ';
        habits.push(`- [${mark}] ${label} ${item.minutes} 分钟`);
      }
    }

    const updated = updateHabitsSection(originalContent, habits, sourceLines);
    commitDiary(date, updated, operationId);

    res.json({ success: true });
  } catch (error) {
    sendWriteError(res, error);
  }
});

router.post('/habit/duration', async (req, res) => {
  try {
    assertWriteInput(req.body);
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

    const originalContent = readDiary(date);

    const existingLines = readHabitLines(originalContent);
    const findExistingLine = (): string | null => {
      const exactIndex = rawLine ? existingLines.indexOf(rawLine) : -1;
      if (exactIndex !== -1) return existingLines[exactIndex];
      return existingLines.find(line => {
        const label = habitLabelFromLine(line);
        return label === fallbackLabel;
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

    if (rawLine && !existingLines.includes(rawLine)) {
      return res.status(409).json({error:'习惯记录已变化，请刷新日记后重新确认'});
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

    commitDiary(date, updated, operationId);
    return res.json({
      success: true,
      minutes: nextMinutes,
      completed,
      rawLine: nextLine,
    });
  } catch (error) {
    return sendWriteError(res, error);
  }
});

router.post('/happiness', async (req, res) => {
  try {
    assertWriteInput(req.body);
    const { content, tags, operationId } = req.body;
    const requestedEntryId = req.body.entryId == null ? null : validateOperationId(req.body.entryId);
    if (req.body.entryId != null && !requestedEntryId) {
      return res.status(400).json({ error: '记录关联标识无效' });
    }
    const entryId = requestedEntryId ?? undefined;
    const date = getRequestDate(req.body.date);
    const time = getRequestTime(req.body.time, date);

    const originalContent = readDiary(date);

    if (operationId && validateOperationId(operationId)) {
      if (hasOpRecord(date, originalContent, operationId)) {
        return res.json({ success: true, dedup: true });
      }
    }

    const formattedContent = formatTimelineEntry('>', time, content, tags, entryId);
    const updated = appendToSection(originalContent, 'happiness', formattedContent);
    commitDiary(date, updated, operationId);

    res.json({ success: true });
  } catch (error) {
    sendWriteError(res, error);
  }
});

router.post('/reflection', async (req, res) => {
  try {
    assertWriteInput(req.body);
    const { content, tags, operationId } = req.body;
    const date = getRequestDate(req.body.date);
    const time = getRequestTime(req.body.time, date);

    const originalContent = readDiary(date);

    if (operationId && validateOperationId(operationId)) {
      if (hasOpRecord(date, originalContent, operationId)) {
        return res.json({ success: true, dedup: true });
      }
    }

    const formattedContent = formatTimelineEntry('-', time, content, tags);

    // Replace template placeholder "- " bullet on first write, else fall through to append
    const replaced = replaceEmptyBulletInSection(originalContent, 'reflection', formattedContent);
    if (replaced) {
      const updated = sortTimelineEntriesInSection(replaced, 'reflection');
      commitDiary(date, updated, operationId);
      return res.json({ success: true });
    }

    const updated = appendToSection(originalContent, 'reflection', formattedContent);
    commitDiary(date, updated, operationId);

    res.json({ success: true });
  } catch (error) {
    sendWriteError(res, error);
  }
});

router.post('/anxiety', async (req, res) => {
  try {
    assertWriteInput(req.body);
    const { content, tags, operationId } = req.body;
    safeAnxietyContent(content);
    const date = getRequestDate(req.body.date);

    const originalContent = readDiary(date);

    if (operationId && validateOperationId(operationId)) {
      if (hasOpRecord(date, originalContent, operationId)) {
        return res.json({ success: true, dedup: true });
      }
    }

    const tagStr = tags?.length > 0 ? ' ' + tags.map((t: string) => `#${t}`).join(' ') : '';
    const formattedContent = `${safeAnxietyContent(content)}${tagStr}`;
    const updated = appendToSection(originalContent, 'anxiety', formattedContent);
    commitDiary(date, updated, operationId);

    res.json({ success: true });
  } catch (error) {
    sendWriteError(res, error);
  }
});

// 替换焦虑四问区块
router.post('/anxiety/replace', async (req, res) => {
  try {
    assertWriteInput(req.body);
    const { content, operationId } = req.body;
    const date = getRequestDate(req.body.date);

    if (!content || typeof content !== 'string' || !content.trim()) {
      return res.status(400).json({ error: '内容不能为空' });
    }

    const originalContent = readDiary(date);

    if (operationId && validateOperationId(operationId)) {
      if (hasOpRecord(date, originalContent, operationId)) {
        return res.json({ success: true, dedup: true });
      }
    }

    const updated = replaceAnxietySection(originalContent, content);
    commitDiary(date, updated, operationId);

    res.json({ success: true });
  } catch (error) {
    sendWriteError(res, error);
  }
});

// 替换荔枝喵说区块
router.post('/lizhi-says', async (req, res) => {
  try {
    assertWriteInput(req.body);
    const { date, content } = req.body;
    const diaryDate = getRequestDate(date);

    const originalContent = readDiary(diaryDate);

    const updated = replaceLizhiSaysSection(originalContent, content);
    writeDiary(diaryDate, updated);

    res.json({ success: true });
  } catch (error) {
    sendWriteError(res, error);
  }
});

// 追加明日寄语
router.post('/tomorrow', async (req, res) => {
  try {
    assertWriteInput(req.body);
    const { date, content } = req.body;
    const diaryDate = getRequestDate(date);

    const originalContent = readDiary(diaryDate);

    const updated = replaceTomorrowSection(originalContent, content);
    writeDiary(diaryDate, updated);

    res.json({ success: true });
  } catch (error) {
    sendWriteError(res, error);
  }
});

// 上传图片（远程模式）：接收 base64 压缩图片，保存到 assets 并追加 WikiLink
router.post('/image/upload', async (req, res) => {
  try {
    assertWriteInput(req.body);
    const { date: dateStr, imageData, operationId, imagePrefix } = req.body;
    if (dateStr === undefined) {
      throw new DiaryWriteError('缺少上传日期，请使用 YYYY-MM-DD', 400);
    }
    if (typeof imageData !== 'string' || !imageData.trim()) {
      throw new DiaryWriteError('图片数据无效，请重新选择照片', 400);
    }
    const entryId = req.body.entryId == null ? undefined : validateOperationId(req.body.entryId);
    if (req.body.entryId != null && !entryId) {
      return res.status(400).json({ error: '记录关联标识无效' });
    }
    const uploadDate = getRequestDate(dateStr);
    const [year, monthNum, day] = dateStr.split('-').map(Number);

    const originalContent = readDiary(uploadDate);

    if (operationId && validateOperationId(operationId)) {
      if (hasOpRecord(uploadDate, originalContent, operationId)) {
        return res.json({
          success: true,
          dedup: true,
          filename: filenameForUploadOperation(originalContent, operationId),
        });
      }
    }

    if (entryId && !findTimelineEntryById(originalContent, entryId)) {
      return res.status(404).json({ error: '关联记录不存在，请刷新后重试' });
    }
    if (entryId && !validateOperationId(operationId)) {
      return res.status(400).json({ error: '照片上传操作标识无效' });
    }
    if (entryId && countPhotosForEntry(originalContent, entryId) >= 9) {
      return res.status(409).json({ error: '每条记录最多添加 9 张照片' });
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
    writeFileSync(imagePath, buffer, { flag: 'wx' });

    // WikiLink 保持在影像记录章节，隐藏注释只记录所属条目和重试标识。
    const wikiLink = `![[${filename}]]`;
    const photoBlock = entryId
      ? `${wikiLink}\n<!-- litchi-photo-of:${entryId};op:${validateOperationId(operationId)} -->`
      : operationId ? `${wikiLink}\n<!-- litchi-upload-op:${operationId} -->` : wikiLink;
    const contentWithImages = ensureImagesSection(originalContent);
    const updated = appendToSection(contentWithImages, 'images', photoBlock);
    try {
      commitDiary(uploadDate, updated, operationId);
    } catch (error) {
      unlinkSync(imagePath);
      throw error;
    }

    res.json({ success: true, filename });
  } catch (error) {
    sendWriteError(res, error);
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

  if (startIndex === -1) throw new DiaryWriteError('日记缺少目标区块，请检查模板后重试');

  for (let i = startIndex + 1; i < lines.length; i++) {
    if (/^#{1,6}\s/.test(lines[i])) {
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

  if (startIndex === -1) throw new DiaryWriteError('日记缺少目标区块，请检查模板后重试');

  for (let i = startIndex + 1; i < lines.length; i++) {
    if (/^#{1,6}\s/.test(lines[i])) {
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

function builtInHabitKind(line: string): string | null {
  if (isWaterLine(line)) return 'water';
  if (isStepsLine(line)) return 'steps';
  if (isReadingLine(line)) return 'reading';
  if (isLanguageLine(line)) return 'language';
  if (isSupplementLine(line)) return 'supplements';
  return null;
}

function readHabitLines(content: string): string[] {
  const lines = content.split('\n');
  const bounds = findSectionBounds(lines, sectionHeaders.habits);
  if (!bounds) throw new DiaryWriteError('日记缺少习惯区块，请检查模板后重试');
  return lines.slice(bounds.start + 1, bounds.end);
}

function updateHabitsSection(content: string, habits: string[], sourceLines: Map<string, string>): string {
  let updated = content;
  for (const nextLine of habits) {
    const lines = updated.split('\n');
    const bounds = findSectionBounds(lines, sectionHeaders.habits);
    if (!bounds) throw new DiaryWriteError('日记缺少习惯区块，请检查模板后重试');
    const kind = builtInHabitKind(nextLine);
    const label = habitLabelFromLine(nextLine);
    const source = sourceLines.get(label);
    const candidates = lines.slice(bounds.start + 1, bounds.end).filter(line =>
      source !== undefined ? line === source : kind !== null ? builtInHabitKind(line) === kind :
        (/^\s*-\s*\[[ xX]\]/.test(line) || durationFromHabitLine(line) !== null) &&
          habitLabelFromLine(line) === label);
    if (source !== undefined && candidates.length === 0) {
      throw new DiaryWriteError('习惯原始内容已变化，请刷新后重试');
    }
    if (candidates.length > 1) throw new DiaryWriteError('习惯存在重复记录，请整理后重试');
    updated = replaceHabitLineInSection(updated, candidates[0] ?? null, nextLine)!;
  }
  return updated;
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
    if (/^#{1,6}\s/.test(lines[i])) {
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

  for (let i = 0; i < lines.length; i++) {
    if (lines[i].startsWith(header)) {
      startIndex = i;
      break;
    }
  }

  const newLines = safeAnxietyContent(newText).split('\n');
  if (startIndex === -1) {
    return insertMissingAnxietySection(lines, header, newLines);
  }

  let endIndex = lines.length;
  for (let i = startIndex + 1; i < lines.length; i++) {
    if (/^#{1,6}\s/.test(lines[i])) {
      endIndex = i;
      break;
    }
  }

  const suffix = anxietySectionSuffix(lines, endIndex);
  return [
    ...lines.slice(0, startIndex + 1),
    ...newLines,
    ...(suffix.length === 0 ? [] : ['', ...suffix]),
  ].join('\n');
}

function insertMissingAnxietySection(
  lines: string[],
  header: string,
  newLines: string[],
): string {
  const anchors = new Set([
    '## 📈 每日复盘',
    '### 💡 觉察与迭代',
    '### 🧠 人生教练',
    '### 🧠 荔枝喵说',
    '### 🌙 明日寄语',
    '## 📸 影像记录',
  ]);
  const anchorIndex = lines.findIndex(line =>
    [...anchors].some(anchor => line.startsWith(anchor)));
  if (anchorIndex === -1) {
    const before = trimTrailingBlankLines([...lines]);
    if (before.length > 0 && before[before.length - 1].trim() !== '---') {
      before.push('', '---');
    }
    return [...before, header, ...newLines].join('\n');
  }

  const separatorIndex = previousNonBlankIndex(lines, anchorIndex);
  const hasSeparator = separatorIndex >= 0 && lines[separatorIndex].trim() === '---';
  const before = hasSeparator
    ? lines.slice(0, separatorIndex + 1)
    : trimTrailingBlankLines(lines.slice(0, anchorIndex));
  const after = hasSeparator
    ? trimLeadingBlankLines(lines.slice(separatorIndex + 1))
    : trimLeadingBlankLines(lines.slice(anchorIndex));
  if (!hasSeparator && before.length > 0 && before[before.length - 1].trim() !== '---') {
    before.push('', '---');
  }

  return [...before, header, ...newLines, '', '---', ...after].join('\n');
}

function anxietySectionSuffix(lines: string[], nextHeadingIndex: number): string[] {
  if (nextHeadingIndex >= lines.length) return [];
  const separatorIndex = previousNonBlankIndex(lines, nextHeadingIndex);
  if (separatorIndex >= 0 && lines[separatorIndex].trim() === '---') {
    return trimLeadingBlankLines(lines.slice(separatorIndex));
  }
  return lines.slice(nextHeadingIndex);
}

function previousNonBlankIndex(lines: string[], beforeIndex: number): number {
  for (let index = beforeIndex - 1; index >= 0; index--) {
    if (lines[index].trim() !== '') return index;
  }
  return -1;
}

function trimTrailingBlankLines(lines: string[]): string[] {
  while (lines.length > 0 && lines[lines.length - 1].trim() === '') lines.pop();
  return lines;
}

function trimLeadingBlankLines(lines: string[]): string[] {
  let first = 0;
  while (first < lines.length && lines[first].trim() === '') first++;
  return lines.slice(first);
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
    res.status(500).json({ error: '图片读取失败，请检查服务器状态' });
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
    res.status(500).json({ error: '图片读取失败，请检查服务器状态' });
  }
});

function getFirstLine(grouped: string): string {
  return grouped.split(/\r?\n/, 1)[0];
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

function findSectionBounds(lines: string[], header: string): { start: number; end: number } | null {
  let start = -1;
  for (let i = 0; i < lines.length; i++) {
    if (lines[i].startsWith(header)) { start = i; break; }
  }
  if (start === -1) return null;
  let end = lines.length;
  for (let i = start + 1; i < lines.length; i++) {
    if (/^#{1,6}\s/.test(lines[i])) { end = i; break; }
  }
  return { start, end };
}

function detachPhotosForEntry(lines: string[], entryId: string): string[] {
  const bounds = findSectionBounds(lines, sectionHeaders.images);
  if (!bounds) return [];

  const removed: string[] = [];
  for (let index = bounds.end - 1; index > bounds.start; index--) {
    const association = PHOTO_ASSOCIATION_PATTERN.exec(lines[index].trim());
    if (association?.[1]?.toLowerCase() !== entryId.toLowerCase()) continue;
    const filename = extractImageName(lines[index - 1]?.trim() ?? '');
    if (!filename) continue;
    removed.push(filename);
    lines.splice(index - 1, 2);
    index--;
  }
  return removed;
}

function isImageReferencedInVault(filename: string): boolean {
  const needles = [filename.toLowerCase(), encodeURIComponent(filename).toLowerCase()];
  const pendingDirs = [config.vaultPath];
  while (pendingDirs.length > 0) {
    const dir = pendingDirs.pop()!;
    for (const entry of readdirSync(dir, { withFileTypes: true })) {
      // 无法证明符号链接目标未引用图片时，保留附件比误删更安全。
      if (entry.isSymbolicLink()) return true;
      const path = join(dir, entry.name);
      if (entry.isDirectory()) {
        pendingDirs.push(path);
      } else if (entry.isFile() && /\.(md|canvas)$/i.test(entry.name)) {
        const text = readFileSync(path, 'utf8').toLowerCase();
        if (needles.some(needle => text.includes(needle))) return true;
      }
    }
  }
  return false;
}

function deleteUnreferencedImageFiles(date: Date, filenames: string[], content: string): void {
  for (const filename of new Set(filenames)) {
    if (!isSafeImageName(filename) || content.includes(`![[${filename}]]`)) continue;
    try {
      if (isImageReferencedInVault(filename)) continue;
      const imagePath = getSafeAssetPath(getAssetsDir(date), filename);
      if (existsSync(imagePath)) unlinkSync(imagePath);
    } catch {
      // 图片路径异常或清理失败时保留文件，不能回滚已完成的日记写入。
    }
  }
}

function findEntryRangeInSection(
  lines: string[], startIdx: number, endIdx: number,
  targetLine: string, matches: number[]
): { startIndex: number; endIndexExclusive: number } | null {
  const starts = new Set<number>();
  for (let index = startIdx; index < endIdx;) {
    if (!lines[index].trim()) { index++; continue; }
    starts.add(index);
    index = isTimelineEntryStart(lines[index].trim())
      ? findTimelineEntryBlockEnd(lines, index, endIdx)
      : findNonTimelineEntryEnd(lines, index, endIdx);
  }
  matches = matches.filter(index => starts.has(index));
  if (matches.length === 0) return null;

  const firstMatch = matches[0];
  if (isTimelineEntryStart(lines[firstMatch].trim())) {
    const normalize = (value: string) => value.replace(/\r\n/g, '\n').trimEnd();
    const exactMatch = matches.find((matchIndex) => {
      const blockEnd = findTimelineEntryBlockEnd(lines, matchIndex, endIdx);
      const block = lines.slice(matchIndex, blockEnd).join('\n');
      return normalize(block) === normalize(targetLine);
    });
    if (exactMatch === undefined) return null;
    const matchedIndex = exactMatch;
    const blockEnd = findTimelineEntryBlockEnd(lines, matchedIndex, endIdx);
    return { startIndex: matchedIndex, endIndexExclusive: blockEnd };
  }

  const normalized = targetLine.replace(/\r\n/g, '\n').trimEnd();
  const matchedIndex = matches.find(index => {
    const end = findNonTimelineEntryEnd(lines, index, endIdx);
    return lines.slice(index, end).join('\n').replace(/\r\n/g, '\n').trimEnd() === normalized;
  });
  if (matchedIndex === undefined) return null;
  return { startIndex: matchedIndex, endIndexExclusive: findNonTimelineEntryEnd(lines, matchedIndex, endIdx) };
}

function findNonTimelineEntryEnd(lines: string[], start: number, limit: number): number {
  const first = lines[start].trim();
  if (first.startsWith('<!--')) return start + 1;
  if (extractImageName(first)) {
    // 独立图片后的手写说明不属于照片；关联标记属于同一原始块。
    return start + 1 < limit && /^<!-- litchi-photo-of:.* -->$/.test(lines[start + 1].trim())
      ? start + 2 : start + 1;
  }
  const quoted = first.startsWith('>');
  let end = start + 1;
  while (end < limit) {
    const line = lines[end];
    if (/^\s/.test(line)) { end++; continue; }
    if (quoted) {
      if (!line.startsWith('>') || line.startsWith('> [!') || isTimelineEntryStart(line)) break;
    } else if (isTimelineEntryStart(line) || /^(?:#{1,6}\s|[-*+]\s|>\s|<!--|!\[\[|---\s*$)/.test(line)) {
      break;
    }
    end++;
  }
  while (end > start + 1 && !lines[end - 1].trim()) end--;
  return end;
}

router.post('/delete-entry', async (req, res) => {
  try {
    assertWriteInput(req.body);
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

    const entryId = section === 'quick_notes' || section === 'happiness'
      ? entryIdFromLines(lines.slice(range.startIndex, range.endIndexExclusive))
      : null;
    const imageName = section === 'images' ? extractImageName(firstLine) : null;
    lines.splice(range.startIndex, range.endIndexExclusive - range.startIndex);
    const removedPhotos = entryId ? detachPhotosForEntry(lines, entryId) : [];
    const updatedContent = lines.join('\n');
    writeDiary(date, updatedContent);
    deleteUnreferencedImageFiles(date, [...removedPhotos, ...(imageName ? [imageName] : [])], updatedContent);
    res.json({ success: true, deletedPhotoCount: removedPhotos.length });
  } catch (error) {
    sendWriteError(res, error);
  }
});

router.post('/edit-entry', async (req, res) => {
  try {
    assertWriteInput(req.body);
    const { date: dateStr, section, target, replacement } = req.body;
    if (!dateStr || !section || !target || !replacement) return res.status(400).json({ error: '缺少参数' });
    const requestedEntryId = req.body.entryId == null ? undefined : validateOperationId(req.body.entryId);
    if (req.body.entryId != null && !requestedEntryId) {
      return res.status(400).json({ error: '记录关联标识无效' });
    }
    if (requestedEntryId && section !== 'quick_notes' && section !== 'happiness') {
      return res.status(400).json({ error: '该区块不支持照片关联' });
    }
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

    const existingEntryId = section === 'quick_notes' || section === 'happiness'
      ? entryIdFromLines(lines.slice(range.startIndex, range.endIndexExclusive))
      : null;
    const suppliedEntryId = requestedEntryId;
    if (existingEntryId && suppliedEntryId && existingEntryId !== suppliedEntryId.toLowerCase()) {
      return res.status(409).json({ error: '记录关联标识已变化，请刷新后重试' });
    }
    const entryId = existingEntryId ?? suppliedEntryId;
    if (typeof replacement !== 'string') throw new DiaryWriteError('替换内容无效', 400);
    rejectSystemMarkers(replacement);
    const newLines = replacement.split('\n');
    if (!entryId && newLines.some(line => ENTRY_ID_MARKER_PATTERN.test(line.trimEnd()))) {
      return res.status(400).json({ error: '正文包含系统保留标记，请移除后重试' });
    }
    if (entryId) newLines.push(`<!-- litchi-entry-id:${entryId} -->`);
    lines.splice(range.startIndex, range.endIndexExclusive - range.startIndex, ...newLines);
    writeDiary(date, sortTimelineEntriesInSection(lines.join('\n'), section));
    res.json({ success: true });
  } catch (error) {
    sendWriteError(res, error);
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
