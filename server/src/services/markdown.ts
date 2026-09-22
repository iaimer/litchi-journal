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

export function sortTimelineEntriesInSection(content: string, section: string): string {
  const header = sectionHeaders[section];
  if (!header) return content;

  const lines = content.split('\n');
  const start = lines.findIndex(line => line.startsWith(header));
  if (start === -1) return content;

  const allHeaders = [...Object.values(sectionHeaders), '### 🧠 荔枝喵说', '## 📈 每日复盘'];
  let end = lines.length;
  for (let i = start + 1; i < lines.length; i++) {
    if (allHeaders.some(sectionHeader => lines[i].startsWith(sectionHeader))) {
      end = i;
      break;
    }
  }

  const timeline = /^(?:-\s*|>\s*)\*\*((?:[01]\d|2[0-3]):[0-5]\d)\*\*/;
  const entryStarts = [] as Array<{ index: number; time: string }>;
  for (let i = start + 1; i < end; i++) {
    const time = timeline.exec(lines[i].trim())?.[1];
    if (time != null) entryStarts.push({ index: i, time });
  }
  if (entryStarts.length < 2) return content;

  const prefix = lines.slice(start + 1, entryStarts[0].index);
  const blocks: Array<{ index: number; time: string; lines: string[] }> = [];
  const separators: string[][] = [];

  for (let i = 0; i < entryStarts.length; i++) {
    const entry = entryStarts[i];
    const rawEnd = i + 1 < entryStarts.length ? entryStarts[i + 1].index : end;
    let trimmedEnd = rawEnd;
    while (trimmedEnd > entry.index && lines[trimmedEnd - 1].trim() === '') {
      trimmedEnd--;
    }
    blocks.push({
      index: i,
      time: entry.time,
      lines: lines.slice(entry.index, trimmedEnd),
    });
    if (i + 1 < entryStarts.length) {
      separators.push(lines.slice(trimmedEnd, rawEnd));
    }
  }

  // The last block owns the section separator only after its actual content.
  const lastEntryStart = entryStarts[entryStarts.length - 1].index;
  let lastContentEnd = end;
  while (lastContentEnd > lastEntryStart && lines[lastContentEnd - 1].trim() === '') {
    lastContentEnd--;
  }
  if (lastContentEnd > lastEntryStart && lines[lastContentEnd - 1].trim() === '---') {
    lastContentEnd--;
    while (lastContentEnd > lastEntryStart && lines[lastContentEnd - 1].trim() === '') {
      lastContentEnd--;
    }
  }
  blocks[blocks.length - 1].lines = lines.slice(lastEntryStart, lastContentEnd);
  const suffix = lines.slice(lastContentEnd, end);

  blocks.sort((a, b) => a.time.localeCompare(b.time) || a.index - b.index);
  const replacement = [...prefix];
  for (let i = 0; i < blocks.length; i++) {
    replacement.push(...blocks[i].lines);
    if (i < blocks.length - 1) replacement.push(...(separators[i] ?? []));
  }
  replacement.push(...suffix);

  lines.splice(start + 1, end - start - 1, ...replacement);

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
