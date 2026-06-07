enum EntryType {
  quickNote('随手记', '写点想法...'),
  reflection('觉察', '觉察到了什么？'),
  happiness('小确幸', '今天有什么小确幸？'),
  anxiety('焦虑', '记录焦虑时刻...');

  final String label;
  final String placeholder;

  const EntryType(this.label, this.placeholder);
}
