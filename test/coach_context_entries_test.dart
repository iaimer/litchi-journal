import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_journal_flutter/screens/home_screen.dart';

void main() {
  for (final title in ['随手记', '小确幸', '觉察']) {
    test('$title 的无时间旧正文也进入回顾上下文', () {
      final context = buildCoachDiaryContext('## $title\n今天和孩子一起散步，心情很好。\n');
      expect(context, contains('今天和孩子一起散步，心情很好。'));
      expect(context, isNot(contains('今天暂无日记内容')));
    });
    test('$title 的系统身份注释不应导致整条真实记录从回顾上下文消失', () {
      final context = buildCoachDiaryContext('''
## $title
- **12:33** 今天记录了一个有趣的梦 #生活
  梦里我和孩子一起比赛，醒来后很开心。
<!-- litchi-entry-id:11111111-1111-4111-8111-111111111111 -->
### 影像记录
![[dream.jpg]]
<!-- litchi-photo-of:11111111-1111-4111-8111-111111111111;op:22222222-2222-4222-8222-222222222222 -->
''');
      expect(context, contains('今天记录了一个有趣的梦'));
      expect(context, contains('梦里我和孩子一起比赛，醒来后很开心。'));
      expect(context, contains('12:33'));
      expect(context, contains('生活'));
      expect(context, isNot(contains('<!--')));
      expect(context, isNot(contains('11111111')));
      expect(context, isNot(contains('dream.jpg')));
    });
  }
}
