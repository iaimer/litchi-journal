import { describe, expect, it } from 'vitest';
import {
  extractGalleryImageNames,
  hasDiaryContent,
  parseGalleryLimit,
  parseMonthCursor,
} from './gallery.js';

describe('gallery helpers', () => {
  it('extracts safe image links in source order and keeps repeated links', () => {
    expect(
      extractGalleryImageNames([
        '![[first.jpg]] and ![[second.png]]',
        '![[../outside.jpg]] ![[first.jpg]] ![[notes.txt]]',
      ]),
    ).toEqual(['first.jpg', 'second.png', 'first.jpg']);
  });

  it('does not treat template placeholders as diary content', () => {
    expect(
      hasDiaryContent({
        sections: {
          quick_notes: ['<!-- note -->', '- **HH:MM** 内容 #标签'],
          happiness: ['> [!success] 总有事件值得感恩🙏♥️', '> '],
          reflection: ['<!-- reflection -->', '- '],
          anxiety: ['- 今天什么时候我感到焦虑/紧张？'],
        },
      }),
    ).toBe(false);
  });

  it('recognizes real content in any supported section', () => {
    expect(
      hasDiaryContent({
        sections: {
          quick_notes: [],
          happiness: [],
          reflection: ['- 今天学会了放慢一点'],
          anxiety: [],
        },
      }),
    ).toBe(true);
  });

  it('validates month cursors and page limits', () => {
    expect(parseMonthCursor('2026-08')).toEqual({ year: 2026, month: 8 });
    expect(parseMonthCursor('2026-13')).toBeNull();
    expect(parseMonthCursor('2026/08')).toBeNull();
    expect(parseGalleryLimit(undefined)).toBe(3);
    expect(parseGalleryLimit('6')).toBe(6);
    expect(parseGalleryLimit('0')).toBeNull();
    expect(parseGalleryLimit('7')).toBeNull();
  });
});
