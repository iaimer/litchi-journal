enum EntryType {
  quickNote('随手记', '有什么想记下来的？\n一句话也可以。'),
  reflection('觉察', '发生了什么？\n当时我在想什么、在意什么？\n现在有什么需要？'),
  happiness('小确幸', '有什么让你开心的小事？\n记下那个瞬间就好。');

  final String label;
  final String placeholder;

  const EntryType(this.label, this.placeholder);
}
