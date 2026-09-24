export const sectionHeaders: Record<string, string> = {
  habits: '## 🏃 习惯打卡',
  quick_notes: '## ✍️ 随手记 & 灵感',
  happiness: '## ✨ 每日小确幸',
  anxiety: '## 😰 焦虑时刻',
  reflection: '### 💡 觉察与迭代',
  lizhi_says: '### 🧠 人生教练',
  tomorrow: '### 🌙 明日寄语',
  images: '## 📸 影像记录'
};

// 旧版标题（向后兼容）
const LEGACY_LIZHI_SAYS = '### 🧠 荔枝喵说';
const TIMELINE_ENTRY_PATTERN = /^(?:-\s*|>\s*)\*\*((?:[01]\d|2[0-3]):[0-5]\d)\*\*/;
const ENTRY_ID_MARKER_PATTERN = /^<!-- litchi-entry-id:[0-9a-f-]{36} -->$/i;

interface TimelineEntryBlock {
  originalIndex: number;
  time: string;
  lines: string[];
}

interface TimelineSectionParts {
  entries: TimelineEntryBlock[];
  staticSegments: string[][];
}

export function isTimelineEntryStart(line: string): boolean {
  return TIMELINE_ENTRY_PATTERN.test(line.trim());
}

function isTimelineBlockBoundary(line: string): boolean {
  const trimmed = line.trim();
  if (!trimmed) return false;
  if (ENTRY_ID_MARKER_PATTERN.test(trimmed)) return false;
  return isTimelineEntryStart(trimmed) ||
    trimmed.startsWith('##') ||
    trimmed.startsWith('###') ||
    trimmed === '---' ||
    trimmed.startsWith('<!--') ||
    trimmed.startsWith('> [!') ||
    trimmed.startsWith('![[') ||
    /^-\s*\[[ xX]\]/.test(trimmed);
}

export function findTimelineEntryBlockEnd(
  lines: string[],
  startIndex: number,
  endIndex: number,
): number {
  let end = startIndex + 1;
  while (end < endIndex && !isTimelineBlockBoundary(lines[end])) end++;
  while (end > startIndex + 1 && lines[end - 1].trim() === '') end--;
  return end;
}

export function parseDiary(content: string) {
  const lines = content.split('\n');

  let frontmatter: Record<string, any> = {};
  let startIndex = 0;

  if (lines[0] === '---') {
    const endIndex = lines.indexOf('---', 1);
    if (endIndex !== -1) {
      const yamlContent = lines.slice(1, endIndex).join('\n');
      frontmatter = parseYaml(yamlContent);
      startIndex = endIndex + 1;
    }
  }

  let title = '';
  let quote = '';

  for (let i = startIndex; i < lines.length; i++) {
    if (lines[i].startsWith('# ')) {
      title = lines[i].slice(2);
      startIndex = i + 1;
      break;
    }
  }

  for (let i = startIndex; i < lines.length; i++) {
    if (lines[i].startsWith('> [!quote]')) {
      quote = lines[i].slice(11).trim();
      startIndex = i + 1;
      break;
    }
  }

  const sections = {
    habits: [] as string[],
    quick_notes: [] as string[],
    happiness: [] as string[],
    anxiety: [] as string[],
    reflection: [] as string[],
    lizhi_says: [] as string[],
    tomorrow: [] as string[],
    images: [] as string[]
  };

  let currentSection: keyof typeof sections | null = null;

  const sectionKeys = Object.keys(sectionHeaders) as (keyof typeof sections)[];

  for (let i = startIndex; i < lines.length; i++) {
    const line = lines[i];

    for (const section of sectionKeys) {
      const header = sectionHeaders[section];
      if (line.startsWith(header) || (section === 'lizhi_says' && line.startsWith(LEGACY_LIZHI_SAYS))) {
        currentSection = section;
        break;
      }
    }

    if (Object.values(sectionHeaders).some(h => line.startsWith(h)) || line.startsWith(LEGACY_LIZHI_SAYS)) {
      continue;
    }

    if (currentSection && line.trim()) {
      if (line.trim() === '---') continue;
      if (line.startsWith('> [!') && !line.startsWith('> [!quote]')) continue;
      if (line.startsWith('## 📈 每日复盘')) continue;
      sections[currentSection].push(line);
    }
  }

  return {
    date: '',
    frontmatter,
    title,
    quote,
    sections,
    raw: content
  };
}

function parseYaml(yaml: string): Record<string, any> {
  const result: Record<string, any> = {};
  let currentListKey: string | null = null;
  const lines = yaml.split('\n');

  for (const line of lines) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('#')) continue;

    // 缩进的列表项（如 tags 下的 "- 日记"）追加到当前列表键
    if (trimmed.startsWith('- ')) {
      if (currentListKey) {
        result[currentListKey].push(
          trimmed.slice(2).trim().replace(/'/g, '').replace(/"/g, '')
        );
      }
      continue;
    }

    currentListKey = null;
    const colonIndex = trimmed.indexOf(':');
    if (colonIndex === -1) continue;

    const key = trimmed.slice(0, colonIndex).trim();
    const value = trimmed.slice(colonIndex + 1).trim();

    if (value === '') {
      result[key] = [];
      currentListKey = key;
    } else if (value.startsWith('-')) {
      result[key] = [value.slice(1).trim().replace(/'/g, '').replace(/"/g, '')];
    } else {
      result[key] = value.replace(/'/g, '').replace(/"/g, '');
    }
  }

  return result;
}

export function appendToSection(content: string, section: string, newLine: string): string {
  const lines = content.split('\n');
  const header = sectionHeaders[section];

  let startIndex = -1;
  let endIndex = -1;

  for (let i = 0; i < lines.length; i++) {
    if (lines[i].startsWith(header)) {
      startIndex = i;
      break;
    }
  }

  if (startIndex === -1) return content;

  // 如果是随手记区块，删除模板中的示例行
  if (section === 'quick_notes') {
    for (let i = startIndex + 1; i < lines.length; i++) {
      if (lines[i].includes('- **HH:MM** 内容 #标签')) {
        lines.splice(i, 1);
        break;
      }
    }
  }

  const allHeaders = [...Object.values(sectionHeaders), '## 📈 每日复盘'];
  for (let i = startIndex + 1; i < lines.length; i++) {
    if (allHeaders.some(h => lines[i].startsWith(h))) {
      endIndex = i;
      break;
    }
  }

  if (endIndex === -1) endIndex = lines.length;

  let insertIndex = endIndex;

  while (insertIndex > startIndex + 1) {
    const prevLine = lines[insertIndex - 1];
    if (prevLine.trim() === '' || prevLine.trim() === '---') {
      insertIndex--;
    } else {
      break;
    }
  }

  lines.splice(insertIndex, 0, newLine);

  return sortTimelineEntriesInSection(lines.join('\n'), section);
}

function findSectionEnd(lines: string[], start: number): number {
  const allHeaders = [...Object.values(sectionHeaders), '### 🧠 荔枝喵说', '## 📈 每日复盘'];
  for (let i = start + 1; i < lines.length; i++) {
    if (allHeaders.some(header => lines[i].startsWith(header))) return i;
  }
  return lines.length;
}

function splitTimelineSection(lines: string[], start: number, end: number): TimelineSectionParts {
  const entries: TimelineEntryBlock[] = [];
  const staticSegments: string[][] = [];
  let cursor = start + 1;

  while (cursor < end) {
    let entryStart = cursor;
    while (entryStart < end && !isTimelineEntryStart(lines[entryStart])) entryStart++;
    staticSegments.push(lines.slice(cursor, entryStart));
    if (entryStart === end) break;

    const blockEnd = findTimelineEntryBlockEnd(lines, entryStart, end);
    const time = TIMELINE_ENTRY_PATTERN.exec(lines[entryStart].trim())?.[1];
    if (time == null) break;
    entries.push({
      originalIndex: entries.length,
      time,
      lines: lines.slice(entryStart, blockEnd),
    });
    cursor = blockEnd;
  }
  if (staticSegments.length === entries.length) staticSegments.push(lines.slice(cursor, end));
  return { entries, staticSegments };
}

function rebuildTimelineSection(parts: TimelineSectionParts): string[] {
  const sortedEntries = [...parts.entries].sort(
    (a, b) => a.time.localeCompare(b.time) || a.originalIndex - b.originalIndex,
  );
  const rebuilt: string[] = [];
  for (let i = 0; i < sortedEntries.length; i++) {
    rebuilt.push(...parts.staticSegments[i], ...sortedEntries[i].lines);
  }
  rebuilt.push(...parts.staticSegments[sortedEntries.length]);
  return rebuilt;
}

export function sortTimelineEntriesInSection(content: string, section: string): string {
  const header = sectionHeaders[section];
  if (!header) return content;

  const lines = content.split('\n');
  const start = lines.findIndex(line => line.startsWith(header));
  if (start === -1) return content;

  const end = findSectionEnd(lines, start);
  const parts = splitTimelineSection(lines, start, end);
  if (parts.entries.length < 2) return content;
  lines.splice(start + 1, end - start - 1, ...rebuildTimelineSection(parts));
  return lines.join('\n');
}

export function replaceEmptyBulletInSection(content: string, section: string, newLine: string): string | null {
  const header = sectionHeaders[section];
  if (!header) return null;

  const lines = content.split('\n');
  let sectionStart = -1;

  for (let i = 0; i < lines.length; i++) {
    if (lines[i].startsWith(header)) {
      sectionStart = i;
      break;
    }
  }

  if (sectionStart === -1) return null;

  const allHeaders = [...Object.values(sectionHeaders), '### 🧠 荔枝喵说', '## 📈 每日复盘'];
  let sectionEnd = lines.length;
  for (let i = sectionStart + 1; i < lines.length; i++) {
    if (allHeaders.some(h => lines[i].startsWith(h))) {
      sectionEnd = i;
      break;
    }
  }

  const sectionLines = lines.slice(sectionStart + 1, sectionEnd);
  const emptyBulletIdx = sectionLines.findIndex(l => l.trim() === '-');

  if (emptyBulletIdx === -1) return null;

  const idx = sectionStart + 1 + emptyBulletIdx;
  lines[idx] = newLine;
  return lines.join('\n');
}
