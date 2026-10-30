import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_journal_flutter/widgets/flora_dock_pages.dart';
import 'package:litchi_journal_flutter/widgets/flora_origin_transform.dart';

class CounterPage extends StatefulWidget {
  final int id;
  const CounterPage(this.id, {super.key});
  @override
  State<CounterPage> createState() => _CounterPageState();
}

class _CounterPageState extends State<CounterPage> {
  int count = 0;
  @override
  Widget build(BuildContext context) => Material(
    child: TextButton(
      onPressed: () => setState(() => count++),
      child: Text('${widget.id}:$count'),
    ),
  );
}

void main() {
  for (final reduced in [false, true]) {
    testWidgets('Dock 来源展开保留页面状态和最后切换目标 reduced=$reduced', (tester) async {
      var selected = 0;
      late StateSetter update;
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: reduced),
            child: StatefulBuilder(
              builder: (context, setState) {
                update = setState;
                return FloraDockPages(
                  selectedIndex: selected,
                  origin: const Rect.fromLTWH(260, 540, 24, 24),
                  children: List.generate(
                    4,
                    (i) => CounterPage(i, key: ValueKey(i)),
                  ),
                );
              },
            ),
          ),
        ),
      );
      await tester.tap(find.text('0:0'));
      await tester.pump();
      update(() => selected = 1);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      if (!reduced) {
        final transform = tester.widget<FloraOriginTransform>(
          find.byType(FloraOriginTransform).last,
        );
        expect(transform.progress, inExclusiveRange(0, 1));
        expect(
          transform.source!.width / transform.source!.height,
          closeTo(
            tester.getSize(find.byType(FloraDockPages)).aspectRatio,
            0.001,
          ),
        );
      }
      update(() => selected = 2);
      await tester.pump();
      update(() => selected = 3);
      await tester.pumpAndSettle();
      expect(find.text('3:0'), findsOneWidget);
      update(() => selected = 0);
      await tester.pumpAndSettle();
      expect(find.text('0:1'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
