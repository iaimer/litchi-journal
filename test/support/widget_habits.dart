part of '../widget_test.dart';

void registerHabitsTests() {
  group('HabitCard', () {
    test('HabitStatus.fromHabitSection maps 5 fields', () {
      final section = HabitSection(
        title: '习惯打卡',
        contents: [],
        habits: [
          const HabitItem(
            kind: HabitKind.checkbox,
            label: '阅读/亲子共读',
            checked: true,
            checkable: true,
            rawLine: '- [x] 阅读/亲子共读',
          ),
          const HabitItem(
            kind: HabitKind.checkbox,
            label: '学语言',
            checked: false,
            checkable: true,
            rawLine: '- [ ] 学语言',
          ),
          const HabitItem(
            kind: HabitKind.checkbox,
            label: '鱼油/植物甾醇',
            checked: true,
            checkable: true,
            rawLine: '- [x] 鱼油/植物甾醇',
          ),
          const HabitItem(
            kind: HabitKind.counter,
            label: '饮水',
            checked: false,
            checkable: false,
            rawLine: '- 饮水 500 mL',
            value: 500,
            unit: 'mL',
          ),
          const HabitItem(
            kind: HabitKind.counter,
            label: '运动/拉伸/快走',
            checked: false,
            checkable: false,
            rawLine: '- 运动/拉伸/快走 8000 步',
            value: 8000,
            unit: '步',
          ),
        ],
      );

      final status = HabitStatus.fromHabitSection(section);
      expect(status.water, 500);
      expect(status.steps, 8000);
      expect(status.reading, isTrue);
      expect(status.language, isFalse);
      expect(status.supplements, isTrue);
    });

    test('HabitStatus.fromHabitSection defaults missing fields', () {
      final section = HabitSection(title: '习惯打卡', contents: [], habits: []);

      final status = HabitStatus.fromHabitSection(section);
      expect(status.water, 0);
      expect(status.steps, 0);
      expect(status.reading, isFalse);
      expect(status.language, isFalse);
      expect(status.supplements, isFalse);
    });

    test('HabitStatus.copyWith updates individual fields', () {
      const status = HabitStatus(
        water: 0,
        steps: 0,
        reading: false,
        language: false,
        supplements: false,
      );

      final next = status.copyWith(reading: true, water: 500);
      expect(next.reading, isTrue);
      expect(next.water, 500);
      expect(next.steps, 0);
      expect(next.language, isFalse);
      expect(next.supplements, isFalse);
    });

    testWidgets('checkbox tap toggles reading and calls onUpdate', (
      tester,
    ) async {
      final section = HabitSection(
        title: '习惯打卡',
        contents: [],
        habits: [
          const HabitItem(
            kind: HabitKind.checkbox,
            label: '阅读/亲子共读',
            checked: false,
            checkable: true,
            rawLine: '- [ ] 阅读/亲子共读',
          ),
        ],
      );

      HabitStatus? called;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HabitCard(
              section: section,
              onUpdate: (status) async {
                called = status;
                return true;
              },
            ),
          ),
        ),
      );

      expect(find.text('亲子共读'), findsOneWidget);
      await tester.tap(find.text('亲子共读'));
      await tester.pump();

      expect(called, isNotNull);
      expect(called!.reading, isTrue);
      expect(called!.language, isFalse);
      expect(called!.supplements, isFalse);
      expect(called!.water, 0);
      expect(called!.steps, 0);
    });

    testWidgets('saving a habit is silent and plays feedback after success', (
      tester,
    ) async {
      final section = HabitSection(
        title: '习惯打卡',
        contents: [],
        habits: [
          const HabitItem(
            kind: HabitKind.checkbox,
            label: '阅读/亲子共读',
            checked: false,
            checkable: true,
            rawLine: '- [ ] 阅读/亲子共读',
          ),
          const HabitItem(
            kind: HabitKind.checkbox,
            label: '学语言',
            checked: false,
            checkable: true,
            rawLine: '- [ ] 学语言',
          ),
          const HabitItem(
            kind: HabitKind.counter,
            label: '饮水',
            checked: false,
            checkable: false,
            rawLine: '- 饮水 500 mL',
            value: 500,
            unit: 'mL',
          ),
        ],
      );
      var updateCount = 0;
      var feedbackCount = 0;
      final save = Completer<bool>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HabitCard(
              section: section,
              onUpdate: (_) {
                updateCount++;
                return save.future;
              },
              onPositiveFeedback: () => feedbackCount++,
            ),
          ),
        ),
      );

      await tester.tap(find.text('亲子共读'));
      await tester.pump();

      expect(updateCount, 1);
      expect(feedbackCount, 0);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      // 保存一组完整习惯状态时，第二个请求会被锁住。
      await tester.tap(find.text('学语言'));
      await tester.pump();
      expect(updateCount, 1);

      save.complete(true);
      await tester.pumpAndSettle();
      expect(feedbackCount, 1);
    });

    testWidgets(
      'counter updates optimistically and only increases play sound',
      (tester) async {
        final section = HabitSection(
          title: '习惯打卡',
          contents: [],
          habits: [
            const HabitItem(
              kind: HabitKind.counter,
              label: '饮水',
              checked: false,
              checkable: false,
              rawLine: '- 饮水 500 mL',
              value: 500,
              unit: 'mL',
            ),
          ],
        );
        var feedbackCount = 0;
        var updateCount = 0;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: HabitCard(
                section: section,
                onUpdate: (_) async {
                  updateCount++;
                  return true;
                },
                onPositiveFeedback: () => feedbackCount++,
              ),
            ),
          ),
        );

        expect(find.text('+250'), findsNothing);
        await tester.tap(find.byKey(const ValueKey('habit_progress_water')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('+250'));
        await tester.pumpAndSettle();
        expect(find.text('750/1500 mL'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('habit_progress_water')),
          findsOneWidget,
        );
        expect(updateCount, 1);
        expect(feedbackCount, 1);
        expect(find.byType(CircularProgressIndicator), findsNothing);

        await tester.tap(find.byKey(const ValueKey('habit_progress_water')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('清零'));
        await tester.pumpAndSettle();
        expect(find.text('0/1500 mL'), findsOneWidget);
        expect(feedbackCount, 1);
      },
    );

    testWidgets('failed optimistic update rolls back without feedback', (
      tester,
    ) async {
      final section = HabitSection(
        title: '习惯打卡',
        contents: [],
        habits: [
          const HabitItem(
            kind: HabitKind.counter,
            label: '饮水',
            checked: false,
            checkable: false,
            rawLine: '- 饮水 500 mL',
            value: 500,
            unit: 'mL',
          ),
        ],
      );
      var feedbackCount = 0;
      final save = Completer<bool>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HabitCard(
              section: section,
              onUpdate: (_) => save.future,
              onPositiveFeedback: () => feedbackCount++,
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const ValueKey('habit_progress_water')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('+250'));
      await tester.pump();
      expect(find.text('750/1500 mL'), findsOneWidget);
      expect(feedbackCount, 0);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      save.complete(false);
      await tester.pumpAndSettle();
      expect(find.text('500/1500 mL'), findsOneWidget);
      expect(find.text('更新失败'), findsOneWidget);
      expect(feedbackCount, 0);
    });

    testWidgets('custom checkbox sends current built-in status and feedback', (
      tester,
    ) async {
      final settings = const HabitSettings(
        statusMap: {'custom_meditate': true},
        extraHabits: {'custom_meditate': '冥想'},
      );
      final section = HabitSection(
        title: '习惯打卡',
        contents: [],
        habits: [
          const HabitItem(
            kind: HabitKind.checkbox,
            label: '阅读/亲子共读',
            checked: true,
            checkable: true,
            rawLine: '- [x] 阅读/亲子共读',
          ),
        ],
      );
      HabitStatus? submittedStatus;
      Map<String, bool>? submittedCustomStates;
      var feedbackCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HabitCard(
              section: section,
              habitSettings: settings,
              onUpdate: (_) async => true,
              onCustomCheckboxToggle: (status, states) async {
                submittedStatus = status;
                submittedCustomStates = states;
                return true;
              },
              onPositiveFeedback: () => feedbackCount++,
            ),
          ),
        ),
      );

      await tester.tap(find.text('冥想'));
      await tester.pumpAndSettle();

      expect(submittedStatus?.reading, isTrue);
      expect(submittedCustomStates, {'custom_meditate': true});
      expect(feedbackCount, 1);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('unchecking a habit does not play feedback', (tester) async {
      final section = HabitSection(
        title: '习惯打卡',
        contents: [],
        habits: [
          const HabitItem(
            kind: HabitKind.checkbox,
            label: '阅读/亲子共读',
            checked: true,
            checkable: true,
            rawLine: '- [x] 阅读/亲子共读',
          ),
        ],
      );
      var feedbackCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HabitCard(
              section: section,
              onUpdate: (_) async => true,
              onPositiveFeedback: () => feedbackCount++,
            ),
          ),
        ),
      );

      await tester.tap(find.text('亲子共读'));
      await tester.pumpAndSettle();
      expect(feedbackCount, 0);
    });

    testWidgets('shows default habit icons', (tester) async {
      final section = HabitSection(
        title: '习惯打卡',
        contents: [],
        habits: [
          const HabitItem(
            kind: HabitKind.checkbox,
            label: '阅读/亲子共读',
            checked: false,
            checkable: true,
            rawLine: '- [ ] 阅读/亲子共读',
          ),
          const HabitItem(
            kind: HabitKind.counter,
            label: '饮水',
            checked: false,
            checkable: false,
            rawLine: '- 饮水 500 mL',
            value: 500,
            unit: 'mL',
          ),
          const HabitItem(
            kind: HabitKind.counter,
            label: '运动/拉伸/快走',
            checked: false,
            checkable: false,
            rawLine: '- 运动/拉伸/快走 8000 步',
            value: 8000,
            unit: '步',
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HabitCard(section: section, onUpdate: (_) async => true),
          ),
        ),
      );

      expect(
        find.byWidgetPredicate(
          (w) => w is FloraIcon && w.name == FloraIcons.habitRead,
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (w) => w is FloraIcon && w.name == FloraIcons.habitWater,
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (w) => w is FloraIcon && w.name == FloraIcons.habitWalk,
        ),
        findsOneWidget,
      );
    });

    testWidgets('water +250 button increments water and calls onUpdate', (
      tester,
    ) async {
      final section = HabitSection(
        title: '习惯打卡',
        contents: [],
        habits: [
          const HabitItem(
            kind: HabitKind.counter,
            label: '饮水',
            checked: false,
            checkable: false,
            rawLine: '- 饮水 500 mL',
            value: 500,
            unit: 'mL',
          ),
        ],
      );

      HabitStatus? called;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HabitCard(
              section: section,
              onUpdate: (status) async {
                called = status;
                return true;
              },
            ),
          ),
        ),
      );

      expect(find.text('+250'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('habit_progress_water')));
      await tester.pumpAndSettle();
      expect(find.text('+250'), findsOneWidget);
      await tester.tap(find.text('+250'));
      await tester.pump();

      expect(called, isNotNull);
      expect(called!.water, 750);
      expect(called!.steps, 0);
      expect(called!.reading, isFalse);
      expect(called!.language, isFalse);
      expect(called!.supplements, isFalse);
    });

    testWidgets('water 清零 button sets water to 0', (tester) async {
      final section = HabitSection(
        title: '习惯打卡',
        contents: [],
        habits: [
          const HabitItem(
            kind: HabitKind.counter,
            label: '饮水',
            checked: false,
            checkable: false,
            rawLine: '- 饮水 500 mL',
            value: 500,
            unit: 'mL',
          ),
        ],
      );

      HabitStatus? called;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HabitCard(
              section: section,
              onUpdate: (status) async {
                called = status;
                return true;
              },
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const ValueKey('habit_progress_water')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('清零'));
      await tester.pump();

      expect(called, isNotNull);
      expect(called!.water, 0);
    });

    testWidgets('water sheet uses two aligned rows and manual input inline', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      final section = HabitSection(
        title: '习惯打卡',
        contents: [],
        habits: [
          const HabitItem(
            kind: HabitKind.counter,
            label: '饮水',
            checked: false,
            checkable: false,
            rawLine: '- 饮水 500 mL',
            value: 500,
            unit: 'mL',
          ),
        ],
      );
      HabitStatus? called;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: HabitCard(
              section: section,
              onUpdate: (status) async {
                called = status;
                return true;
              },
              onWaterQuickAmountsChanged: (_) async => true,
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const ValueKey('habit_progress_water')));
      await tester.pumpAndSettle();
      expect(find.text('手动输入'), findsOneWidget);
      expect(find.text('自定义预设'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) => widget is FloraIcon && widget.name == FloraIcons.settings,
        ),
        findsNothing,
      );
      expect(find.bySemanticsLabel('自定义饮水预设'), findsOneWidget);
      semantics.dispose();
      final firstRowWidths = [250, 475, 500]
          .map(
            (amount) => tester
                .getSize(find.byKey(ValueKey('habit_water_quick_$amount')))
                .width,
          )
          .toList();
      final secondRowWidths = [
        tester.getSize(find.byKey(const ValueKey('habit_water_custom'))).width,
        tester.getSize(find.byKey(const ValueKey('habit_water_clear'))).width,
        tester
            .getSize(find.byKey(const ValueKey('habit_water_settings')))
            .width,
      ];
      for (final width in [...firstRowWidths, ...secondRowWidths]) {
        expect(width, closeTo(firstRowWidths.first, 0.01));
      }

      await tester.tap(find.text('手动输入'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('habit_water_sheet_custom')),
        findsOneWidget,
      );
      expect(find.text('手动输入饮水量'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('habit_water_custom_input')),
        '300',
      );
      await tester.tap(find.text('添加'));
      await tester.pumpAndSettle();
      expect(called?.water, 800);
    });

    testWidgets('water quick settings validate, sort, and return to actions', (
      tester,
    ) async {
      final section = HabitSection(
        title: '习惯打卡',
        contents: [],
        habits: [
          const HabitItem(
            kind: HabitKind.counter,
            label: '饮水',
            checked: false,
            checkable: false,
            rawLine: '- 饮水 500 mL',
            value: 500,
            unit: 'mL',
          ),
        ],
      );
      List<int>? saved;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HabitCard(
              section: section,
              onUpdate: (_) async => true,
              onWaterQuickAmountsChanged: (amounts) async {
                saved = amounts;
                return true;
              },
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const ValueKey('habit_progress_water')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('habit_water_settings')));
      await tester.pumpAndSettle();
      expect(find.text('自定义饮水预设'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('habit_water_setting_1')),
        '600',
      );
      await tester.enterText(
        find.byKey(const ValueKey('habit_water_setting_2')),
        '300',
      );
      await tester.enterText(
        find.byKey(const ValueKey('habit_water_setting_3')),
        '300',
      );
      await tester.tap(find.text('保存'));
      await tester.pump();
      expect(find.text('三个快捷量不能重复'), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey('habit_water_setting_3')),
        '450',
      );
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      expect(saved, [300, 450, 600]);
      expect(find.text('+300'), findsOneWidget);
      expect(find.text('+450'), findsOneWidget);
      expect(find.text('+600'), findsOneWidget);
    });

    testWidgets('water quick settings keep editor open when saving fails', (
      tester,
    ) async {
      final section = HabitSection(
        title: '习惯打卡',
        contents: [],
        habits: [
          const HabitItem(
            kind: HabitKind.counter,
            label: '饮水',
            checked: false,
            checkable: false,
            rawLine: '- 饮水 500 mL',
            value: 500,
            unit: 'mL',
          ),
        ],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HabitCard(
              section: section,
              onUpdate: (_) async => true,
              onWaterQuickAmountsChanged: (_) async => false,
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const ValueKey('habit_progress_water')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('habit_water_settings')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      expect(find.text('保存失败，请重试'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('habit_water_sheet_settings')),
        findsOneWidget,
      );
    });

    testWidgets('water save keeps habit row spacing stable while pending', (
      tester,
    ) async {
      final pendingSave = Completer<bool>();
      final section = HabitSection(
        title: '习惯打卡',
        contents: [],
        habits: [
          const HabitItem(
            kind: HabitKind.counter,
            label: '饮水',
            checked: false,
            checkable: false,
            rawLine: '- 饮水 500 mL',
            value: 500,
            unit: 'mL',
          ),
          const HabitItem(
            kind: HabitKind.counter,
            label: '运动/拉伸/快走',
            checked: false,
            checkable: false,
            rawLine: '- 运动/拉伸/快走 3000 步',
            value: 3000,
            unit: '步',
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HabitCard(
              section: section,
              onUpdate: (_) => pendingSave.future,
            ),
          ),
        ),
      );

      double rowSpacing() =>
          tester.getTopLeft(find.text('运动')).dy -
          tester.getTopLeft(find.text('饮水')).dy;

      final before = rowSpacing();
      await tester.tap(find.byKey(const ValueKey('habit_progress_water')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('+250'));
      await tester.pump();

      expect(rowSpacing(), closeTo(before, 0.01));

      pendingSave.complete(true);
      await tester.pumpAndSettle();
    });

    testWidgets('steps edit uses a bottom sheet and calls onUpdate', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final section = HabitSection(
        title: '习惯打卡',
        contents: [],
        habits: [
          const HabitItem(
            kind: HabitKind.counter,
            label: '运动/拉伸/快走',
            checked: false,
            checkable: false,
            rawLine: '- 运动/拉伸/快走 8000 步',
            value: 8000,
            unit: '步',
          ),
        ],
      );

      HabitStatus? called;
      var feedbackCount = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HabitCard(
              section: section,
              onUpdate: (status) async {
                called = status;
                return true;
              },
              onPositiveFeedback: () => feedbackCount++,
            ),
          ),
        ),
      );

      expect(find.text('8000/6000 步'), findsOneWidget);
      expect(find.text('编辑'), findsNothing);
      await tester.tap(find.text('运动'));
      await tester.pump();
      expect(find.text('输入今日步数'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('habit_progress_steps')));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byKey(const ValueKey('habit_steps_sheet')), findsOneWidget);
      final stepsInput = find.byKey(const ValueKey('habit_steps_input'));
      final input = tester.widget<TextField>(stepsInput);
      expect(input.controller?.text, '8000');
      expect(input.controller?.selection.start, 0);
      expect(input.controller?.selection.end, 4);
      expect(tester.takeException(), isNull);

      await tester.tap(find.byKey(const ValueKey('habit_steps_cancel')));
      await tester.pumpAndSettle();
      expect(called, isNull);

      await tester.tap(find.byKey(const ValueKey('habit_progress_steps')));
      await tester.pumpAndSettle();
      await tester.enterText(stepsInput, '6000');
      await tester.tap(find.byKey(const ValueKey('habit_steps_save')));
      await tester.pumpAndSettle();

      expect(called, isNotNull);
      expect(called!.steps, 6000);
      expect(called!.water, 0);
      expect(feedbackCount, 0);

      await tester.tap(find.byKey(const ValueKey('habit_progress_steps')));
      await tester.pumpAndSettle();
      await tester.enterText(stepsInput, '9000');
      await tester.tap(find.byKey(const ValueKey('habit_steps_save')));
      await tester.pumpAndSettle();

      expect(find.text('9000/6000 步'), findsOneWidget);
      expect(called!.steps, 9000);
      expect(feedbackCount, 1);
    });

    testWidgets('steps sheet validates before closing', (tester) async {
      final section = HabitSection(
        title: '习惯打卡',
        contents: [],
        habits: [
          const HabitItem(
            kind: HabitKind.counter,
            label: '运动/拉伸/快走',
            checked: false,
            checkable: false,
            rawLine: '- 运动/拉伸/快走 3552 步',
            value: 3552,
            unit: '步',
          ),
        ],
      );
      HabitStatus? called;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HabitCard(
              section: section,
              onUpdate: (status) async {
                called = status;
                return true;
              },
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const ValueKey('habit_progress_steps')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('habit_steps_input')),
        '500001',
      );
      await tester.tap(find.byKey(const ValueKey('habit_steps_save')));
      await tester.pump();

      expect(find.text('请输入 0–500000 的整数'), findsOneWidget);
      expect(find.byKey(const ValueKey('habit_steps_sheet')), findsOneWidget);
      expect(called, isNull);

      await tester.enterText(
        find.byKey(const ValueKey('habit_steps_input')),
        '0',
      );
      await tester.tap(find.byKey(const ValueKey('habit_steps_save')));
      await tester.pumpAndSettle();

      expect(called?.steps, 0);
    });

    testWidgets('quantitative habit tracks align', (tester) async {
      await tester.binding.setSurfaceSize(const Size(393, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final semantics = tester.ensureSemantics();
      final section = HabitSection(
        title: '习惯打卡',
        contents: [],
        habits: [
          const HabitItem(
            kind: HabitKind.counter,
            label: '饮水',
            checked: false,
            checkable: false,
            rawLine: '- 饮水 3000 mL',
            value: 3000,
            unit: 'mL',
          ),
          const HabitItem(
            kind: HabitKind.counter,
            label: '运动/拉伸/快走',
            checked: false,
            checkable: false,
            rawLine: '- 运动/拉伸/快走 3000 步',
            value: 3000,
            unit: '步',
          ),
          const HabitItem(
            kind: HabitKind.checkbox,
            label: '阅读/亲子共读',
            checked: false,
            checkable: true,
            rawLine: '- [ ] 阅读/亲子共读',
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: HabitCard(section: section, onUpdate: (_) async => true),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('3000/1500 mL'), findsOneWidget);
      expect(find.text('3000/6000 步'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('habit_progress_water')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('habit_progress_steps')),
        findsOneWidget,
      );
      final progressValue = tester.widget<Text>(find.text('3000/6000 步'));
      expect(progressValue.style?.color, AppColors.textSecondary);
      final progressSemantics = tester.getSemantics(
        find.byKey(const ValueKey('habit_progress_steps')),
      );
      expect(progressSemantics.label, contains('运动进度'));
      expect(progressSemantics.label, isNot(contains('3000/6000 步')));
      expect(progressSemantics.value, '3000/6000 步');
      expect(progressSemantics.hint, '点击编辑步数');
      expect(HabitVisualConfig.of('steps').color, AppColors.success);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      final waterProgressWidth = tester
          .getSize(find.byKey(const ValueKey('habit_progress_track_饮水')))
          .width;
      final stepsProgressWidth = tester
          .getSize(find.byKey(const ValueKey('habit_progress_track_运动')))
          .width;
      expect(waterProgressWidth, stepsProgressWidth);
      final waterTrackRect = tester.getRect(
        find.byKey(const ValueKey('habit_progress_track_饮水')),
      );
      final stepsTrackRect = tester.getRect(
        find.byKey(const ValueKey('habit_progress_track_运动')),
      );
      final waterValueRect = tester.getRect(find.text('3000/1500 mL'));
      final stepsValueRect = tester.getRect(find.text('3000/6000 步'));
      expect(waterTrackRect.left, closeTo(stepsTrackRect.left, 1));
      expect(waterTrackRect.right, closeTo(stepsTrackRect.right, 1));
      expect(waterTrackRect.width, greaterThan(130));
      expect(waterValueRect.left - waterTrackRect.right, closeTo(6, 1));
      expect(stepsValueRect.left - stepsTrackRect.right, closeTo(6, 1));
      semantics.dispose();
    });

    testWidgets(
      'maximum quantitative target stays readable on narrow screens',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(320, 700));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final section = HabitSection(
          title: '习惯打卡',
          contents: [],
          habits: [
            const HabitItem(
              kind: HabitKind.counter,
              label: '饮水',
              checked: false,
              checkable: false,
              rawLine: '- 饮水 500000 mL',
              value: 500000,
              unit: 'mL',
            ),
          ],
        );
        const settings = HabitSettings(
          statusMap: {'water': true},
          targetMap: {'water': 500000},
        );

        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
            child: MaterialApp(
              theme: AppTheme.light,
              home: Scaffold(
                body: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: HabitCard(
                    section: section,
                    habitSettings: settings,
                    onUpdate: (_) async => true,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('500000/500000 mL'), findsOneWidget);
        expect(tester.takeException(), isNull);
        expect(find.text('+250'), findsNothing);
        await tester.tap(find.byKey(const ValueKey('habit_progress_water')));
        await tester.pumpAndSettle();
        expect(find.text('+250'), findsOneWidget);
        expect(find.text('+475'), findsOneWidget);
        expect(find.text('+500'), findsOneWidget);
        expect(find.text('手动输入'), findsOneWidget);
        expect(find.text('清零'), findsOneWidget);
        expect(find.text('自定义预设'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('habit_water_settings')),
          findsOneWidget,
        );
        expect(
          tester
              .getSize(find.byKey(const ValueKey('habit_progress_track_饮水')))
              .width,
          greaterThan(48),
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('onUpdate failure shows SnackBar, keeps old state', (
      tester,
    ) async {
      final section = HabitSection(
        title: '习惯打卡',
        contents: [],
        habits: [
          const HabitItem(
            kind: HabitKind.checkbox,
            label: '阅读/亲子共读',
            checked: false,
            checkable: true,
            rawLine: '- [ ] 阅读/亲子共读',
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HabitCard(
              section: section,
              onUpdate: (status) async => false,
            ),
          ),
        ),
      );

      await tester.tap(find.text('亲子共读'));
      await tester.pumpAndSettle();

      expect(find.text('更新失败'), findsOneWidget);
    });

    testWidgets('onUpdate exception shows SnackBar and clears loading', (
      tester,
    ) async {
      final section = HabitSection(
        title: '习惯打卡',
        contents: [],
        habits: [
          const HabitItem(
            kind: HabitKind.checkbox,
            label: '阅读/亲子共读',
            checked: false,
            checkable: true,
            rawLine: '- [ ] 阅读/亲子共读',
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HabitCard(
              section: section,
              onUpdate: (_) async => throw Exception('network error'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('亲子共读'));
      await tester.pumpAndSettle();

      expect(find.text('更新失败'), findsOneWidget);
      // Verify no lingering spinner (loading cleared)
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });

  group('HabitSettings targets', () {
    test('migrates, persists, and resets built-in quantitative targets', () {
      final migrated = HabitSettings.fromJson(const {
        'schemaVersion': 4,
        'statusMap': {'water': true, 'steps': true},
      });
      expect(migrated.targetFor('water'), 1500);
      expect(migrated.targetFor('steps'), 6000);
      expect(migrated.targetFor('custom_meditate'), isNull);

      final settings = const HabitSettings(
        statusMap: {'water': true, 'steps': true},
        targetMap: {'water': 1800, 'steps': 7000, 'custom_meditate': 30},
      );
      final json = settings.toJson();
      expect(json['schemaVersion'], HabitSettings.schemaVersion);
      expect(json['targetMap'], {'water': 1800, 'steps': 7000});

      final restored = HabitSettings.fromJson(json);
      expect(restored.targetFor('water'), 1800);
      expect(restored.targetFor('steps'), 7000);

      final oversized = HabitSettings.fromJson(const {
        'schemaVersion': 5,
        'targetMap': {'water': 500001, 'steps': 500000},
      });
      expect(oversized.targetFor('water'), 1500);
      expect(oversized.targetFor('steps'), 500000);

      final reset = settings.resetHabit('water');
      expect(reset.targetFor('water'), 1500);
      expect(reset.targetFor('steps'), 7000);
    });

    test('migrates, validates, persists, and resets water quick amounts', () {
      final migrated = HabitSettings.fromJson(const {
        'schemaVersion': 5,
        'statusMap': {'water': true},
      });
      expect(
        migrated.waterQuickAmounts,
        HabitSettings.defaultWaterQuickAmounts,
      );

      final restored = HabitSettings.fromJson(const {
        'schemaVersion': 6,
        'statusMap': {'water': true},
        'waterQuickAmounts': [600, 300, 450],
      });
      expect(restored.waterQuickAmounts, [300, 450, 600]);
      expect(restored.toJson()['waterQuickAmounts'], [300, 450, 600]);
      expect(
        restored.resetHabit('water').waterQuickAmounts,
        HabitSettings.defaultWaterQuickAmounts,
      );

      for (final invalid in [
        [250, 250, 500],
        [0, 250, 500],
        [250, 500, 500001],
        [250, 475.5, 500],
        [250, 500],
      ]) {
        final settings = HabitSettings.fromJson({
          'schemaVersion': 6,
          'waterQuickAmounts': invalid,
        });
        expect(
          settings.waterQuickAmounts,
          HabitSettings.defaultWaterQuickAmounts,
        );
      }
    });
  });
}
