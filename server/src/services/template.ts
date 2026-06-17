import { getShanghaiDateString, getShanghaiWeekdayName } from '../utils/date.js';

export function getDateString(date: Date): string {
  return getShanghaiDateString(date);
}

export function getWeekdayName(date: Date): string {
  return getShanghaiWeekdayName(date);
}

export function createObsidianDiaryContent(date: Date): string {
  const weekday = getWeekdayName(date);
  const lines: string[] = [];

  lines.push('---');
  lines.push('tags:');
  lines.push('  - 日记');
  lines.push('---');
  lines.push('');
  lines.push('# 🌿 ' + weekday + ' · 此时此刻');
  lines.push('> [!quote] 2026 年，如果只选一件事：**让健康和记录成为习惯。**');
  lines.push('');
  lines.push('---');
  lines.push('## 🏃 习惯打卡');
  lines.push('- 🥛饮水 0 mL');
  lines.push('- 🧘 运动/拉伸/快走 0 步');
  lines.push('- [ ] 📖 阅读/亲子共读');
  lines.push('- [ ] 🇬🇧 学语言');
  lines.push('- [ ] 💊 鱼油/植物甾醇');
  lines.push('');
  lines.push('---');
  lines.push('## ✍️ 随手记 & 灵感');
  lines.push('<!-- 随手记和灵感，文案喵会自动添加合适的标签 -->');
  lines.push('- **HH:MM** 内容 #标签');
  lines.push('');
  lines.push('---');
  lines.push('## ✨ 每日小确幸');
  lines.push('> [!success] 总有事件值得感恩🙏♥️');
  lines.push('> ');
  lines.push('');
  lines.push('---');
  lines.push('## 😰 焦虑时刻');
  lines.push('- 今天什么时候我感到焦虑/紧张？');
  lines.push('> ');
  lines.push('- 当时我在担心什么？（具体到一句话)');
  lines.push('> ');
  lines.push('- 我做了什么？');
  lines.push('> ');
  lines.push('- 这个应对是帮我面对了，还是帮我躲开了？');
  lines.push('>  ');
  lines.push('');
  lines.push('---');
  lines.push('## 📈 每日复盘');
  lines.push('### 💡 觉察与迭代');
  lines.push('<!-- 这里是你的观点和思考，荔枝喵会重点提取 -->');
  lines.push('- ');
  lines.push('');
  lines.push('### 🧠 人生教练');
  lines.push('<!-- 基于当天日记的客观反馈：模式识别、矛盾指出、批判性问题 -->');
  lines.push('- ');
  lines.push('');
  lines.push('### 🌙 明日寄语');
  lines.push('- ');
  lines.push('');
  lines.push('---');
  lines.push('## 📸 影像记录');

  return lines.join('\n');
}
