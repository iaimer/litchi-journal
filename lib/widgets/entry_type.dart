enum EntryType {
  quickNote('随手记', '写点想法...'),
  reflection('觉察', '发生了什么？\n当时我在想什么、在意什么？\n现在有什么需要？'),
  happiness('小确幸', '今天有什么小确幸？');

  final String label;
  final String placeholder;

  const EntryType(this.label, this.placeholder);
}
