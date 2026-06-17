import { describe, it, expect } from 'vitest';
import { appendToSection, replaceEmptyBulletInSection } from './markdown.js';

const template = [
  '---',
  'tags:',
  '  - 日记',
  '---',
  '',
  '# 🌿 星期一 · 此时此刻',
  '> [!quote] 2026 年，如果只选一件事：**让健康和记录成为习惯。**',
  '',
  '---',
  '## 🏃 习惯打卡',
  '- 🥛饮水 0 mL',
  '',
  '---',
  '## ✍️ 随手记 & 灵感',
  '<!-- 随手记和灵感，文案喵会自动添加合适的标签 -->',
  '- **HH:MM** 内容 #标签',
  '',
  '---',
  '## ✨ 每日小确幸',
  '> [!success] 总有事件值得感恩🙏♥️',
  '> ',
  '',
  '---',
  '## 😰 焦虑时刻',
  '- 今天什么时候我感到焦虑/紧张？',
  '',
  '---',
  '## 📈 每日复盘',
  '### 💡 觉察与迭代',
  '<!-- 这里是你的观点和思考，荔枝喵会重点提取 -->',
  '- ',
  '',
  '### 🧠 人生教练',
  '<!-- 基于当天日记的客观反馈：模式识别、矛盾指出、批判性问题 -->',
  '- ',
  '',
  '### 🌙 明日寄语',
  '- ',
  '',
  '---',
  '## 📸 影像记录',
].join('\n');

const formattedContent = '- **17:17** 正文 #生活 #情绪感受 #反思';

describe('appendToSection', () => {
  it('appends content to a section', () => {
    const result = appendToSection(template, 'happiness', '- **12:00** 小确幸');
    expect(result).toContain('- **12:00** 小确幸');
    // original empty template lines preserved
    expect(result).toContain('## 😰 焦虑时刻');
  });

  it('removes quick_notes template example', () => {
    const result = appendToSection(template, 'quick_notes', '- **10:00** 新笔记');
    expect(result).not.toContain('- **HH:MM** 内容 #标签');
    expect(result).toContain('- **10:00** 新笔记');
  });
});

describe('replaceEmptyBulletInSection', () => {
  it('replaces empty bullet in reflection section on first write', () => {
    const result = replaceEmptyBulletInSection(template, 'reflection', formattedContent);
    expect(result).not.toBeNull();
    expect(result!).toContain(formattedContent);
    // reflection section should no longer have "- " bullet
    const reflectionSection = result!.split('### 💡 觉察与迭代')[1].split('### 🧠')[0];
    expect(reflectionSection).not.toMatch(/\n- $/m);
    // HTML comment preserved
    expect(result!).toContain('<!-- 这里是你的观点和思考，荔枝喵会重点提取 -->');
  });

  it('returns null when section already has real content (second write)', () => {
    const once = replaceEmptyBulletInSection(template, 'reflection', formattedContent)!;
    const result = replaceEmptyBulletInSection(once, 'reflection', '- **18:00** 新觉察');
    expect(result).toBeNull();
  });

  it('does not affect empty bullets in other sections', () => {
    const result = replaceEmptyBulletInSection(template, 'reflection', formattedContent);
    expect(result!).not.toBeNull();
    // Tomorrow section's empty bullet should remain
    const lines = result!.split('\n');
    const tomorrowIdx = lines.findIndex(l => l.startsWith('### 🌙 明日寄语'));
    const tomorrowContent = lines.slice(tomorrowIdx + 1, tomorrowIdx + 5).join('\n');
    expect(tomorrowContent).toContain('- ');
  });

  it('returns null for non-existent section', () => {
    const result = replaceEmptyBulletInSection(template, 'nonexistent', formattedContent);
    expect(result).toBeNull();
  });

  it('replaces empty bullet in reflection with HTML comment preserved — real template', () => {
    const result = replaceEmptyBulletInSection(template, 'reflection', formattedContent);
    expect(result).not.toBeNull();
    const lines = result!.split('\n');
    const reflectionIdx = lines.findIndex(l => l.startsWith('### 💡 觉察与迭代'));
    const sectionLines = lines.slice(reflectionIdx + 1);
    const firstRealLine = sectionLines.find(l => l.trim() && !l.startsWith('<!--'));
    expect(firstRealLine).toBe(formattedContent);
  });

  it('replaces empty bullet in 人生教练 section', () => {
    const coachLine = '- 今天你的一个明显模式是……';
    const result = replaceEmptyBulletInSection(template, 'lizhi_says', coachLine);
    expect(result).not.toBeNull();
    expect(result!).toContain(coachLine);
    // HTML comment preserved
    expect(result!).toContain('<!-- 基于当天日记的客观反馈：模式识别、矛盾指出、批判性问题 -->');
    // Empty bullet should be gone from 人生教练 section
    const coachSection = result!.split('### 🧠 人生教练')[1].split('### 🌙')[0];
    expect(coachSection).not.toMatch(/\n- $/m);
    // Tomorrow section's empty bullet remains untouched
    const tomorrowSection = result!.split('### 🌙 明日寄语')[1].split('---')[0];
    expect(tomorrowSection).toMatch(/\n- /);
  });

  it('replaces empty bullet in 明日寄语 section', () => {
    const tomorrowLine = '- 愿你明天更轻松地开始。';
    const result = replaceEmptyBulletInSection(template, 'tomorrow', tomorrowLine);
    expect(result).not.toBeNull();
    expect(result!).toContain(tomorrowLine);
    // Empty bullet should be gone from 明日寄语 section
    const tomorrowSection = result!.split('### 🌙 明日寄语')[1].split('---')[0];
    expect(tomorrowSection).not.toMatch(/\n- $/m);
    // 人生教练 empty bullet remains
    const coachSection = result!.split('### 🧠 人生教练')[1].split('### 🌙')[0];
    expect(coachSection).toMatch(/\n- /);
  });
});
