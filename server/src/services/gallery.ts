const IMAGE_LINK_PATTERN = /!\[\[([^/\\\]]+\.(?:jpg|jpeg|png|gif|webp|heic|heif))\]\]/gi;
const SAFE_IMAGE_NAME_PATTERN = /^[^/\\\u0000-\u001F\u007F]+\.(jpg|jpeg|png|gif|webp|heic|heif)$/i;
const ANXIETY_QUESTION_PATTERN = /^-\s*(今天什么时候我感到焦虑\/紧张？|当时我在担心什么？.*|我做了什么？|这个应对是帮我面对了，还是帮我躲开了？)$/;

export interface GalleryDay {
  date: string;
  images: string[];
  hasContent: boolean;
}

export interface GalleryMonth {
  year: number;
  month: number;
  totalDays: number;
  totalImages: number;
  days: GalleryDay[];
}

/** 从 Markdown 行中提取图片 WikiLink，保留原始顺序和重复引用。 */
export function extractGalleryImageNames(lines: readonly string[]): string[] {
  const names: string[] = [];
  for (const line of lines) {
    for (const match of line.matchAll(IMAGE_LINK_PATTERN)) {
      const name = match[1];
      if (name && SAFE_IMAGE_NAME_PATTERN.test(name)) names.push(name);
    }
  }
  return names;
}

/** 与历史月历相同的“实际内容”判断，不把模板占位文字算作内容。 */
export function hasDiaryContent(entry: {
  sections: Record<string, string[]>;
}): boolean {
  const sections = entry.sections;
  const hasQuickNotes = (sections.quick_notes ?? []).some(
    line =>
      line.trim() &&
      !line.includes('<!--') &&
      !line.includes('- **HH:MM** 内容 #标签') &&
      line.length > 2,
  );
  const hasHappiness = (sections.happiness ?? []).some(
    line =>
      line.trim() &&
      !line.includes('<!--') &&
      !/^>\s*$/.test(line) &&
      !line.includes('总有事件值得感恩'),
  );
  const hasReflection = (sections.reflection ?? []).some(
    line =>
      line.trim() &&
      !line.includes('<!--') &&
      line.trim() !== '-',
  );
  const hasAnxiety = (sections.anxiety ?? []).some(
    line =>
      line.trim() &&
      !line.includes('<!--') &&
      !/^>\s*$/.test(line) &&
      !ANXIETY_QUESTION_PATTERN.test(line.trim()),
  );

  return hasQuickNotes || hasHappiness || hasReflection || hasAnxiety;
}

export function parseMonthCursor(value: unknown): { year: number; month: number } | null {
  if (typeof value !== 'string') return null;
  const match = value.match(/^(\d{4})-(\d{2})$/);
  if (!match) return null;

  const year = Number(match[1]);
  const month = Number(match[2]);
  if (year < 1000 || year > 9999 || month < 1 || month > 12) return null;
  return { year, month };
}

export function parseGalleryLimit(value: unknown): number | null {
  if (value == null) return 3;
  if (typeof value !== 'string' || !/^\d+$/.test(value)) return null;
  const limit = Number(value);
  return Number.isInteger(limit) && limit >= 1 && limit <= 6 ? limit : null;
}

export function monthIndex(year: number, month: number): number {
  return year * 12 + (month - 1);
}

export function monthFromIndex(index: number): { year: number; month: number } {
  const year = Math.floor(index / 12);
  const month = index % 12 + 1;
  return { year, month };
}

export function formatMonthCursor(year: number, month: number): string {
  return `${year}-${month.toString().padStart(2, '0')}`;
}
