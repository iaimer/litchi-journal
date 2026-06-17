const shanghaiDateFormatter = new Intl.DateTimeFormat('en-CA', {
  timeZone: 'Asia/Shanghai',
  year: 'numeric',
  month: '2-digit',
  day: '2-digit'
});

const shanghaiWeekdayFormatter = new Intl.DateTimeFormat('zh-CN', {
  timeZone: 'Asia/Shanghai',
  weekday: 'long'
});

export function getShanghaiDateParts(date: Date): { year: number; month: number; day: number } {
  const parts = shanghaiDateFormatter.formatToParts(date);
  const values = Object.fromEntries(parts.map(part => [part.type, part.value]));

  return {
    year: Number(values.year),
    month: Number(values.month),
    day: Number(values.day)
  };
}

export function getShanghaiDateString(date: Date): string {
  const { year, month, day } = getShanghaiDateParts(date);
  return `${year}-${month.toString().padStart(2, '0')}-${day.toString().padStart(2, '0')}`;
}

export function getShanghaiWeekdayName(date: Date): string {
  return shanghaiWeekdayFormatter.format(date);
}

export function parseShanghaiDate(dateStr: string): Date {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(dateStr)) {
    throw new Error('Invalid date format. Expected YYYY-MM-DD.');
  }

  const date = new Date(`${dateStr}T12:00:00+08:00`);
  if (getShanghaiDateString(date) !== dateStr) {
    throw new Error('Invalid date.');
  }

  return date;
}
