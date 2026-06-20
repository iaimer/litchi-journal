import { Router } from 'express';
import { readDiary, writeDiary, getDateString, getDiaryPath, existsDiary, getAssetsDir } from '../services/vault.js';
import { readFileSync, existsSync, mkdirSync, writeFileSync, readdirSync, unlinkSync } from 'fs';
import { isAbsolute, join, relative, resolve } from 'path';
import config from '../config/index.js';
import { parseDiary, appendToSection, sectionHeaders, replaceEmptyBulletInSection } from '../services/markdown.js';
import { createObsidianDiaryContent } from '../services/template.js';
import { parseShanghaiDate } from '../utils/date.js';

const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const OLD_OP_MARKER_PATTERN = /^<!-- diary-op:[0-9a-f-]+ -->$/i;
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

const monthNames = ['January', 'February', 'March', 'April', 'May', 'June',
                    'July', 'August', 'September', 'October', 'November', 'December'];

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
    const { water, steps, reading, language, supplements, operationId, extraCheckboxes } = req.body;
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

    const waterEmoji = '🥤';
    const waterCount = Math.floor(water / 250);
    const waterStr = waterCount > 0
      ? `- 🥛${waterEmoji.repeat(waterCount)}饮水 ${water} mL`
      : `- 🥛饮水 ${water} mL`;

    const habits = [
      waterStr,
      `- 🧘 运动/拉伸/快走 ${steps} 步`,
      `- [${reading ? 'x' : ' '}] 📖 阅读/亲子共读`,
      `- [${language ? 'x' : ' '}] 🇬🇧 学语言`,
      `- [${supplements ? 'x' : ' '}] 💊 鱼油/植物甾醇`
    ];

    // 追加自定义 checkbox 习惯行
    if (extraCheckboxes && typeof extraCheckboxes === 'object') {
      for (const [_, info] of Object.entries(extraCheckboxes)) {
        const item = info as any;
        const mark = item.checked ? 'x' : ' ';
        const label = item.label || '?';
        habits.push(`- [${mark}] ${label}`);
      }
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

router.post('/anxiety/replace', async (req, res) => {
  try {
    const { content, operationId } = req.body;
    if (!content) return res.status(400).json({ error: 'content is required' });
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

    const updated = stripOldOpMarkers(replaceAnxietySection(originalContent, content));
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

// 替换明日寄语中的行动建议
router.post('/tomorrow/action', async (req, res) => {
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

    // 写入图片文件
    const imagePath = join(assetsDir, filename);
    writeFileSync(imagePath, buffer);

    // 追加 WikiLink；幂等索引写入旁路文件，避免污染日记正文
    const wikiLink = `![[${filename}]]`;
    const updated = stripOldOpMarkers(appendToSection(originalContent, 'images', wikiLink));
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

// 替换明日寄语中的行动建议（删除旧的带标记的内容，添加新的）
function replaceTomorrowAction(content: string, newAction: string): string {
  const lines = content.split('\n');
  const header = '### 🌙 明日寄语';

  // 删除旧的行动建议（带 <!-- action --> 标记的内容，或以 🎯 开头的行）
  const newLines: string[] = [];
  let inActionBlock = false;
  for (const line of lines) {
    if (line.includes('<!-- action -->')) {
      inActionBlock = true;
      continue;
    }
    if (line.includes('<!-- /action -->')) {
      inActionBlock = false;
      continue;
    }
    // 也删除以 🎯 开头的行（旧的未标记的行动建议）
    if (line.includes('🎯')) {
      continue;
    }
    if (!inActionBlock) {
      newLines.push(line);
    }
  }

  // 在明日寄语区块末尾添加新的行动建议（带标记）
  const actionMarkerStart = '<!-- action -->';
  const actionMarkerEnd = '<!-- /action -->';
  const actionLine = `- ${newAction}`;

  const allHeaders = ['## 🏃 习惯打卡', '## ✍️ 随手记', '## ✨ 每日小确幸',
    '## 😰 焦虑时刻', '### 💡 觉察与迭代', '### 🧠 人生教练', '### 🧠 荔枝喵说', header, '## 📸 影像记录'];

  // 找到插入位置：明日寄语区块末尾（下一个区块之前）
  let insertIndex = -1;
  for (let i = 0; i < newLines.length; i++) {
    if (newLines[i].startsWith(header)) {
      // 找到明日寄语标题后，找到下一个区块或末尾
      for (let j = i + 1; j < newLines.length; j++) {
        if (allHeaders.some(h => newLines[j].startsWith(h))) {
          insertIndex = j;
          break;
        }
      }
      if (insertIndex === -1) {
        insertIndex = newLines.length;
      }
      break;
    }
  }

  // 插入新的行动建议
  if (insertIndex !== -1) {
    newLines.splice(insertIndex, 0, actionMarkerStart, actionLine, actionMarkerEnd);
  }

  return newLines.join('\n');
}

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

    let imagePath: string | null = null;

    if (month) {
      const monthDirName = `${month.toString().padStart(2, '0')}.${monthNames[month - 1]}`;
      const monthAssetsDir = join(
        config.vaultPath,
        '01.日记',
        year.toString(),
        monthDirName,
        'assets'
      );
      const monthAssetsPath = getSafeAssetPath(monthAssetsDir, imageName);
      if (existsSync(monthAssetsPath)) {
        imagePath = monthAssetsPath;
      }
    }

    if (!imagePath) {
      const yearAssetsDir = join(
        config.vaultPath,
        '01.日记',
        year.toString(),
        'assets'
      );
      const yearAssetsPath = getSafeAssetPath(yearAssetsDir, imageName);
      if (existsSync(yearAssetsPath)) {
        imagePath = yearAssetsPath;
      }
    }

    if (!imagePath) {
      return res.status(404).json({ error: 'Image not found' });
    }

    const imageBuffer = readFileSync(imagePath);
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
      const imagePath = getSafeAssetPath(getAssetsDir(date), imageName);
      if (existsSync(imagePath)) unlinkSync(imagePath);
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
    writeDiary(date, lines.join('\n'));
    res.json({ success: true });
  } catch (error) {
    res.status(500).json({ error: (error as Error).message });
  }
});

function isSafeImageName(imageName: string): boolean {
  return /^[^/\\]+\.(jpg|jpeg|png|gif|webp|heic|heif)$/i.test(imageName);
}

function getSafeAssetPath(assetsDir: string, imageName: string): string {
  const resolvedAssetsDir = resolve(assetsDir);
  const imagePath = resolve(resolvedAssetsDir, imageName);
  const relativePath = relative(resolvedAssetsDir, imagePath);

  if (!relativePath || relativePath.startsWith('..') || isAbsolute(relativePath)) {
    throw new Error('Invalid image path');
  }

  return imagePath;
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
