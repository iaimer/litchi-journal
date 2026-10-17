export function isWaterLine(line: string): boolean {
  return /^\s*-\s*(?:🥛(?:🥤)*\s*)?饮水\s+\d+\s*mL\s*$/i.test(line);
}

export function isStepsLine(line: string): boolean {
  return /^\s*-\s*(?:🧘\s*)?(?:运动|运动\s*\/\s*拉伸\s*\/\s*快走)\s+\d+\s*步\s*$/.test(line);
}

export function checkboxHabitLabel(line: string): string | null {
  const match = line.match(/^\s*-\s*\[[ xX]\]\s*(.+?)\s*$/);
  if (!match) return null;
  return match[1]
    .replace(/\s+\d+\s*(?:分钟|min)\s*$/i, '')
    .replace(/\s*\/\s*/g, '/')
    .replace(/\s+/g, ' ')
    .trim();
}

export function isCheckedLine(line: string): boolean {
  return /^\s*-\s*\[[xX]\]/.test(line);
}

export function isReadingLine(line: string): boolean {
  const label = checkboxHabitLabel(line);
  return label != null && new Set([
    '阅读',
    '亲子共读',
    '亲子阅读',
    '阅读/亲子共读',
    '📖 阅读',
    '📖 亲子共读',
    '📖 阅读/亲子共读',
  ]).has(label);
}

export function isLanguageLine(line: string): boolean {
  const label = checkboxHabitLabel(line);
  return label === '学语言' || label === '🇬🇧 学语言';
}

export function isSupplementLine(line: string): boolean {
  const label = checkboxHabitLabel(line);
  return label != null && new Set([
    '鱼油',
    '植物甾醇',
    '鱼油/植物甾醇',
    '补充剂',
    '💊 鱼油',
    '💊 植物甾醇',
    '💊 鱼油/植物甾醇',
    '💊 补充剂',
  ]).has(label);
}

export function isBuiltInHabitLine(line: string): boolean {
  return isWaterLine(line) ||
    isStepsLine(line) ||
    isReadingLine(line) ||
    isLanguageLine(line) ||
    isSupplementLine(line);
}
