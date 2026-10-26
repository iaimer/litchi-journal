import { readFileSync } from 'node:fs';
import { describe, expect, it } from 'vitest';
import { createObsidianDiaryContent } from './template.js';
import { appendToSection, parseDiary, replaceEmptyBulletInSection } from './markdown.js';

const sharedTemplates = JSON.parse(
  readFileSync(new URL('../../../test/fixtures/diary_templates.json', import.meta.url), 'utf8'),
) as { legacy: string[]; current: string[] };

describe('new diary template', () => {
  const template = createObsidianDiaryContent(new Date('2026-10-25T12:00:00+08:00'));

  it('omits anxiety without disturbing section order or separators', () => {
    expect(template.split('\n')).toEqual(sharedTemplates.current);
    expect(template).not.toContain('焦虑');
    expect(template).not.toContain('我做了什么？');
    expect(template.match(/^#{2,3} .+$/gm)).toEqual([
      '## 🏃 习惯打卡',
      '## ✍️ 随手记 & 灵感',
      '## ✨ 每日小确幸',
      '## 📈 每日复盘',
      '### 💡 觉察与迭代',
      '### 🧠 人生教练',
      '### 🌙 明日寄语',
      '## 📸 影像记录',
    ]);
    expect(template).not.toMatch(/---\s*\n---/);
    expect(template).toContain('> \n\n---\n## 📈 每日复盘');
    expect(template).toContain('<!-- 记录情绪、想法或自己的反应，还没想明白也可以写。 -->');
  });

  it('supports first reflection and other entries in the generated template', () => {
    let diary = replaceEmptyBulletInSection(template, 'reflection', '- **10:00** 有点紧张 #生活')!;
    diary = appendToSection(diary, 'quick_notes', '- **09:00** 随手记');
    diary = appendToSection(diary, 'happiness', '- **11:00** 开心的事');
    const { sections } = parseDiary(diary);
    expect(sections.reflection).toContain('- **10:00** 有点紧张 #生活');
    expect(sections.quick_notes).toContain('- **09:00** 随手记');
    expect(sections.happiness).toContain('- **11:00** 开心的事');
    expect(diary).not.toContain('焦虑');
  });
});
