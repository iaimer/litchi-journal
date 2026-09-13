import '../models/diary_document.dart';

/// 返回日记章节在 Flutter 界面中的规范展示标题。
///
/// Markdown 标题仍由 Parser 原样保留，这里只负责展示层的语义收敛。
String diarySectionDisplayTitle(DiarySection section) {
  switch (section.sectionType) {
    case 'habit':
      return '习惯打卡';
    case 'quickNote':
      return '随手记';
    case 'happiness':
      return '小确幸';
    case 'anxiety':
      return '焦虑时刻';
    case 'review':
      return '觉察';
    case 'coach':
      return '今日回顾';
    case 'tomorrow':
      return '明日寄语';
    case 'media':
      return '影像记录';
    default:
      return section.title;
  }
}
