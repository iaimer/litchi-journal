part of '../widget_test.dart';

void registerPreferencesTests() {
  group('HabitVisualConfig', () {
    test('supplements displayName is 补充剂', () {
      final config = HabitVisualConfig.of('supplements');
      expect(config.displayName, '补充剂');
      expect(config.icon, FloraIcons.habitPill);
    });

    test('default habit icons resolve to Flora assets', () {
      for (final config in HabitVisualConfig.defaults.values) {
        expect(FloraIcons.hasAsset(config.icon), isTrue);
      }
    });

    test('each habit has unique color', () {
      final colors = HabitVisualConfig.defaults.values
          .map((c) => c.color)
          .toSet();
      expect(colors.length, 5);
    });

    test('water and steps are body group', () {
      expect(HabitVisualConfig.of('water').group, HabitGroup.body);
      expect(HabitVisualConfig.of('steps').group, HabitGroup.body);
    });

    test('reading and language are growth group', () {
      expect(HabitVisualConfig.of('reading').group, HabitGroup.growth);
      expect(HabitVisualConfig.of('language').group, HabitGroup.growth);
    });

    testWidgets('habit edit saves quantitative target', (tester) async {
      FlutterSecureStorage.setMockInitialValues({});

      await tester.pumpWidget(
        const MaterialApp(home: HabitEditScreen(habitKey: 'water')),
      );
      await tester.pumpAndSettle();

      expect(find.text('每日目标'), findsOneWidget);
      expect(find.text('mL'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('habit_target_field')),
        '1800',
      );
      await tester.ensureVisible(find.text('保存'));
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      final settings = await HabitSettingsRepository().load();
      expect(settings.targetFor('water'), 1800);
    });

    testWidgets('habit edit rejects a quantitative target outside limits', (
      tester,
    ) async {
      FlutterSecureStorage.setMockInitialValues({});

      await tester.pumpWidget(
        const MaterialApp(home: HabitEditScreen(habitKey: 'steps')),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('habit_target_field')),
        '500001',
      );
      await tester.ensureVisible(find.text('保存'));
      await tester.tap(find.text('保存'));
      await tester.pump();

      expect(find.text('每日目标请输入 1–500000 的整数'), findsOneWidget);
      expect(
        await HabitSettingsRepository().load().then(
          (s) => s.targetFor('steps'),
        ),
        6000,
      );
    });

    testWidgets('habit edit target candidate uses Flora icon and is tappable', (
      tester,
    ) async {
      FlutterSecureStorage.setMockInitialValues({});

      await tester.pumpWidget(
        const MaterialApp(home: HabitEditScreen(habitKey: 'water')),
      );
      await tester.pumpAndSettle();

      final targetIcon = find.byWidgetPredicate(
        (w) => w is FloraIcon && w.name == FloraIcons.candidateStar,
      );
      expect(targetIcon, findsOneWidget);

      await tester.tap(targetIcon);
      await tester.pump();

      final selectedContainer = tester.widget<Container>(
        find.ancestor(of: targetIcon, matching: find.byType(Container)).first,
      );
      final decoration = selectedContainer.decoration as BoxDecoration;
      final border = decoration.border as Border;
      expect(border.top.width, 2);
    });
  });

  group('SettingsPage', () {
    Widget buildPage() {
      return MaterialApp(
        home: SettingsPage(
          apiConfig: ApiConfig(
            baseUrl: 'https://obsidian.femkits.org',
            token: '',
          ),
        ),
      );
    }

    testWidgets('shows app bar and section groups', (tester) async {
      await tester.pumpWidget(buildPage());

      expect(find.text('设置'), findsOneWidget);
      expect(_floraIcon(FloraIcons.back), findsOneWidget);
      expect(find.text('管理你的日记应用'), findsNothing);
      expect(find.text('常用'), findsOneWidget);
      expect(find.text('连接与智能'), findsOneWidget);

      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pumpAndSettle();

      expect(find.text('媒体与应用'), findsOneWidget);
    });

    testWidgets('does not expose removed backup settings', (tester) async {
      await tester.pumpWidget(buildPage());

      expect(find.text('数据与安全'), findsNothing);
      expect(find.text('数据与备份'), findsNothing);
    });

    testWidgets('back button pops SettingsPage', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => SettingsPage(
                        apiConfig: ApiConfig(
                          baseUrl: 'https://obsidian.femkits.org',
                          token: '',
                        ),
                      ),
                    ),
                  );
                },
                child: const Text('打开设置'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('打开设置'));
      await tester.pumpAndSettle();
      expect(find.text('设置'), findsOneWidget);

      await tester.tap(_floraIcon(FloraIcons.back));
      await tester.pumpAndSettle();

      expect(find.text('打开设置'), findsOneWidget);
      expect(find.text('设置'), findsNothing);
    });

    testWidgets('shows all menu items', (tester) async {
      await tester.pumpWidget(buildPage());

      expect(find.text('外观'), findsOneWidget);
      expect(find.text('习惯设置'), findsOneWidget);
      expect(find.text('标签设置'), findsOneWidget);
      expect(find.text('服务器连接'), findsOneWidget);
      expect(find.text('AI 服务配置'), findsOneWidget);
      expect(find.text('润色提示词'), findsOneWidget);
      expect(find.byType(Card), findsNWidgets(3));
      expect(
        tester.getSize(find.byKey(const ValueKey('settings-item-外观'))).height,
        56,
      );
      expect(find.text('跟随系统'), findsNothing);
      expect(find.text('已启用 5 项'), findsNothing);
      expect(find.text('标签管理'), findsNothing);
      expect(find.text('https://obsidian.femkits.org'), findsNothing);
      expect(find.text('未配置'), findsNothing);
      expect(find.text('编辑润色与人生教练提示词'), findsNothing);

      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pumpAndSettle();

      expect(find.text('图片设置'), findsOneWidget);
      expect(find.text('关于'), findsOneWidget);
      expect(find.text('压缩与文件命名'), findsNothing);
      expect(find.text('荔枝日记 Flutter 客户端'), findsNothing);
    });

    testWidgets('remote api page shows token configured state', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: RemoteApiPage(
            apiConfig: ApiConfig(
              baseUrl: 'https://obsidian.femkits.org',
              token: '',
            ),
            tokenConfigured: false,
          ),
        ),
      );

      expect(find.text('Token 状态'), findsOneWidget);
      expect(find.text('未配置'), findsOneWidget);
      expect(find.text('已配置'), findsNothing);
    });

    testWidgets('remote api save notifies new config immediately', (
      tester,
    ) async {
      FlutterSecureStorage.setMockInitialValues({});
      ApiConfig? changedConfig;
      final client = ApiClient(
        ApiConfig(baseUrl: 'https://old.local', token: 'test'),
        httpClient: _FakeHttpClient(statusCode: 200, body: '{}'),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: RemoteApiPage(
            apiConfig: ApiConfig(baseUrl: 'https://old.local', token: 'test'),
            apiClient: client,
            onConfigChanged: (config) => changedConfig = config,
            createApiClient: (config) => ApiClient(
              config,
              httpClient: _FakeHttpClient(statusCode: 200, body: '{}'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('修改服务器地址'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'https://new.local');
      await tester.tap(find.widgetWithText(FilledButton, '保存'));
      await tester.pumpAndSettle();

      expect(changedConfig?.baseUrl, 'https://new.local');
      expect(changedConfig?.token, 'test');
      expect(find.text('服务器地址已保存并生效'), findsOneWidget);
      expect(find.text('保存后重启 App 生效。'), findsNothing);
    });

    testWidgets('tapping appearance navigates to appearance settings', (
      tester,
    ) async {
      await tester.pumpWidget(buildPage());

      await tester.tap(find.text('外观'));
      await tester.pumpAndSettle();

      expect(find.text('选择你喜欢的显示方式'), findsNothing);
    });

    testWidgets('tapping AI config navigates to AI settings', (tester) async {
      await tester.pumpWidget(buildPage());

      await tester.tap(find.text('AI 服务配置'));
      await tester.pumpAndSettle();

      expect(find.text('保存 AI 配置'), findsOneWidget);
    });

    testWidgets('tapping about navigates to about page', (tester) async {
      await tester.pumpWidget(buildPage());

      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pumpAndSettle();

      await tester.tap(find.text('关于'));
      await tester.pumpAndSettle();

      expect(find.text('荔枝日记'), findsOneWidget);
    });

    testWidgets('tapping tag settings opens with fallback config', (
      tester,
    ) async {
      FlutterSecureStorage.setMockInitialValues({});
      final client = ApiClient(
        ApiConfig(baseUrl: 'https://test.local', token: 'test'),
        httpClient: _FakeHttpClient(statusCode: 500, body: '{}'),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: SettingsPage(
            apiConfig: ApiConfig(baseUrl: 'https://test.local', token: 'test'),
            apiClient: client,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('标签设置'));
      await tester.pumpAndSettle();

      expect(find.text('标签管理'), findsWidgets);
      expect(find.text('领域'), findsOneWidget);
      expect(find.text('方法'), findsOneWidget);
      expect(find.text('亲子'), findsOneWidget);
    });

    testWidgets('safe area prevents status bar overlap', (tester) async {
      await tester.pumpWidget(buildPage());

      expect(find.byType(SafeArea), findsWidgets);
    });
  });

  group('TagSettingsPage', () {
    final config = TagConfig(
      domains: [
        TagDomain(
          id: 'parenting',
          name: '亲子',
          description: '领域说明不应直接显示',
          order: 0,
          topics: [
            TagTopic(
              id: 'p-bonding',
              name: '陪伴互动',
              description: '主题说明不应直接显示',
              order: 0,
            ),
          ],
        ),
      ],
      methods: [
        TagMethod(
          id: 'reflect',
          name: '反思',
          description: '方法说明不应直接显示',
          order: 0,
        ),
      ],
    );

    Widget buildPage() {
      return MaterialApp(
        theme: AppTheme.light,
        home: TagSettingsPage(
          initialSettings: TagSettings.fromTagConfig(config),
          tagConfig: config,
        ),
      );
    }

    testWidgets('shows names without descriptions, switches, or edit icons', (
      tester,
    ) async {
      await tester.pumpWidget(buildPage());

      expect(find.text('亲子'), findsOneWidget);
      expect(find.text('领域说明不应直接显示'), findsNothing);
      expect(find.text('主题说明不应直接显示'), findsNothing);
      expect(find.text('方法说明不应直接显示'), findsNothing);
      expect(find.byType(FloraSwitch), findsNothing);
      expect(
        find.byWidgetPredicate(
          (widget) => widget is FloraIcon && widget.name == FloraIcons.edit,
        ),
        findsNothing,
      );
    });

    testWidgets('domain arrow expands independently from name action menu', (
      tester,
    ) async {
      await tester.pumpWidget(buildPage());
      expect(find.text('陪伴互动'), findsNothing);

      await tester.tap(find.byTooltip('展开'));
      await tester.pumpAndSettle();
      expect(find.text('陪伴互动'), findsOneWidget);

      await tester.tap(find.text('亲子'));
      await tester.pumpAndSettle();
      expect(find.text('#亲子'), findsNothing);
      expect(find.text('取消'), findsNothing);
      final sheetDividers = find.descendant(
        of: find.byType(BottomSheet),
        matching: find.byType(Divider),
      );
      expect(sheetDividers, findsNWidgets(3));
      for (final divider in tester.widgetList<Divider>(sheetDividers)) {
        expect(divider.thickness, 1);
      }
      expect(find.text('停用'), findsOneWidget);
      expect(find.text('编辑'), findsOneWidget);
      expect(find.text('永久删除'), findsOneWidget);
    });

    testWidgets('edit action opens a bottom sheet with only the name field', (
      tester,
    ) async {
      await tester.pumpWidget(buildPage());
      await tester.tap(find.text('亲子'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('编辑'));
      await tester.pumpAndSettle();

      expect(find.text('编辑领域'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('可选说明'), findsNothing);
      expect(find.text('确定'), findsOneWidget);
    });

    testWidgets('add and permanently delete a local domain', (tester) async {
      FlutterSecureStorage.setMockInitialValues({});
      await tester.pumpWidget(buildPage());

      await tester.tap(find.text('＋ 添加领域'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '旅行');
      await tester.tap(find.text('确定'));
      await tester.pumpAndSettle();
      expect(find.text('旅行'), findsOneWidget);

      await tester.tap(find.text('旅行'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('永久删除'));
      await tester.pumpAndSettle();
      expect(find.text('已有日记中的标签不会被修改。'), findsOneWidget);
      await tester.tap(find.text('永久删除'));
      await tester.pumpAndSettle();
      expect(find.text('旅行'), findsNothing);
    });

    testWidgets('keeps add and restore controls when all labels are deleted', (
      tester,
    ) async {
      final settings = TagSettings.fromTagConfig(config);
      for (final domain in settings.domainSettings) {
        domain.deleted = true;
        domain.enabled = false;
        for (final topic in domain.topics) {
          topic.deleted = true;
          topic.enabled = false;
        }
      }
      for (final method in settings.methodSettings) {
        method.deleted = true;
        method.enabled = false;
      }

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: TagSettingsPage(initialSettings: settings, tagConfig: config),
        ),
      );

      expect(find.text('＋ 添加领域'), findsOneWidget);
      expect(find.text('恢复全部默认'), findsOneWidget);
      await tester.tap(find.text('方法'));
      await tester.pumpAndSettle();
      expect(find.text('＋ 添加方法'), findsOneWidget);
    });
  });

  group('AboutPage changelog parsing', () {
    test('parses current version without v prefix', () {
      const raw = '''
# Changelog

## 1.1.0

- 当前版本内容

## 1.0.0

- 旧版本内容
''';

      expect(AboutPage.parseCurrentVersion(raw, '1.1.0'), '- 当前版本内容');
    });

    test('parses current version with v prefix', () {
      const raw = '''
# Changelog

## v1.1.0

- 当前版本内容
''';

      expect(AboutPage.parseCurrentVersion(raw, '1.1.0'), '- 当前版本内容');
    });

    testWidgets('shows redesigned brand copy', (tester) async {
      PackageInfo.setMockInitialValues(
        appName: '荔枝日记',
        packageName: 'org.femkits.lizhidiary',
        version: '1.1.0',
        buildNumber: '1',
        buildSignature: '',
      );

      await tester.pumpWidget(const MaterialApp(home: AboutPage()));
      await tester.pumpAndSettle();

      expect(find.text('荔枝日记'), findsOneWidget);
      expect(find.text('记录生活里的点滴，'), findsOneWidget);
      expect(find.text('看见自己的成长。'), findsOneWidget);
      expect(find.textContaining('版本 v1.1.0 (1)'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('更新内容'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('更新内容'), findsOneWidget);
      expect(find.textContaining('荔枝日记不是效率工具'), findsNothing);
      expect(find.textContaining('Flutter 客户端'), findsNothing);
    });
  });

  group('FloraIcon brand icon', () {
    testWidgets('renders brand PNG without theme tint', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FloraIcon(
              FloraIcons.brandIcon,
              size: 80,
              color: Colors.green,
            ),
          ),
        ),
      );

      final image = tester.widget<Image>(find.byType(Image));
      expect(FloraIcons.path(FloraIcons.brandIcon), 'assets/icon/app-icon.png');
      expect(image.image, isA<AssetImage>());
      expect((image.image as AssetImage).assetName, 'assets/icon/app-icon.png');
      expect(image.color, isNull);
    });
  });

  // ── TagSettings ──

  // ── AppearanceSettings ──

  group('AppearanceSettings', () {
    test('default themeMode is system', () {
      final settings = AppearanceSettings();
      expect(settings.themeMode, ThemeMode.system);
    });

    test('toJson / fromJson round-trip', () {
      final settings = AppearanceSettings(themeMode: ThemeMode.dark);
      final json = settings.toJson();
      final restored = AppearanceSettings.fromJson(json);
      expect(restored.themeMode, ThemeMode.dark);
    });

    test('fromJson broken falls back to system', () {
      final restored = AppearanceSettings.fromJson({'themeMode': null});
      expect(restored.themeMode, ThemeMode.system);
    });

    test('copyWith preserves other fields', () {
      final settings = AppearanceSettings(themeMode: ThemeMode.light);
      final updated = settings.copyWith(themeMode: ThemeMode.dark);
      expect(updated.themeMode, ThemeMode.dark);
      expect(updated.schemaVersion, settings.schemaVersion);
    });
  });

  group('AppearanceSettingsRepository', () {
    test('load returns defaults when no storage', () async {
      final storage = _TestStorage();
      final repo = AppearanceSettingsRepository(storage: storage);
      final settings = await repo.load();
      expect(settings.themeMode, ThemeMode.system);
    });

    test('save and reload preserves choice', () async {
      final storage = _TestStorage();
      final repo = AppearanceSettingsRepository(storage: storage);
      await repo.save(AppearanceSettings(themeMode: ThemeMode.dark));
      final reloaded = await repo.load();
      expect(reloaded.themeMode, ThemeMode.dark);
    });

    test('corrupted JSON falls back to system', () async {
      final storage = _TestStorage({'appearance_settings': 'broken!!!'});
      final repo = AppearanceSettingsRepository(storage: storage);
      final settings = await repo.load();
      expect(settings.themeMode, ThemeMode.system);
    });
  });

  group('ImageCompressPage', () {
    testWidgets('shows filename preview', (tester) async {
      final repo = ImageSettingsRepository(storage: _TestStorage());

      await tester.pumpWidget(
        MaterialApp(home: ImageCompressPage(repository: repo)),
      );
      await tester.pumpAndSettle();

      expect(find.text('图片设置'), findsOneWidget);
      expect(find.text('图片压缩'), findsOneWidget);
      expect(find.text('文件命名'), findsOneWidget);
      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pumpAndSettle();
      expect(find.text('Image-YYYYMMDD-NNN.jpg'), findsOneWidget);
    });

    testWidgets('reset default restores changed prefix preview', (
      tester,
    ) async {
      final repo = ImageSettingsRepository(storage: _TestStorage());

      await tester.pumpWidget(
        MaterialApp(home: ImageCompressPage(repository: repo)),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Litchi');
      await tester.pump();
      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pumpAndSettle();
      expect(find.text('Litchi-YYYYMMDD-NNN.jpg'), findsOneWidget);

      await tester.tap(find.text('恢复默认'));
      await tester.pumpAndSettle();

      expect(find.text('Image-YYYYMMDD-NNN.jpg'), findsOneWidget);
    });
  });

  group('AppearanceSettingsPage', () {
    testWidgets('shows three options with correct defaults', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: const AppearanceSettingsPage()),
      );

      expect(find.text('选择你喜欢的显示方式'), findsNothing);
      expect(find.text('跟随系统'), findsOneWidget);
      expect(find.text('浅色'), findsOneWidget);
      expect(find.text('深色'), findsOneWidget);
    });

    testWidgets('tapping option changes selection', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: const AppearanceSettingsPage()),
      );

      await tester.tap(find.text('深色'));
      await tester.pumpAndSettle();

      expect(find.text('外观'), findsOneWidget);
    });
  });

  group('TagSettings', () {
    test(
      'TagRepository falls back to default config on remote failure',
      () async {
        FlutterSecureStorage.setMockInitialValues({});
        final repo = TagRepository(
          apiClient: ApiClient(
            ApiConfig(baseUrl: 'https://test.local', token: 'test'),
            httpClient: _FakeHttpClient(statusCode: 500, body: '{}'),
          ),
        );

        final config = await repo.loadTagConfig();

        expect(config.domains.length, DefaultTagConfig.value.domains.length);
        expect(config.domains.first.name, '亲子');
        expect(config.methods.map((m) => m.name), contains('反思'));
      },
    );

    test('fromTagConfig creates all enabled defaults', () async {
      final config = fullTagConfig();
      final settings = TagSettings.fromTagConfig(config);
      expect(settings.domainSettings.length, 2);
      expect(settings.domainSettings.every((d) => d.enabled), true);
      expect(settings.domainSettings[0].displayName, '亲子');
      expect(settings.domainSettings[1].displayName, '工作');
      expect(settings.methodSettings.length, 2);
      expect(settings.methodSettings.every((m) => m.enabled), true);
    });

    test('toJson / fromJson round-trip preserves data', () async {
      final config = fullTagConfig();
      final settings = TagSettings.fromTagConfig(config);
      settings.domainSettings[0].displayName = '育儿';
      settings.domainSettings[0].enabled = false;
      settings.domainSettings[0].deleted = true;
      final json = settings.toJson();
      final restored = TagSettings.fromJson(json);
      expect(restored.schemaVersion, 1);
      expect(restored.domainSettings[0].displayName, '育儿');
      expect(restored.domainSettings[0].enabled, false);
      expect(restored.domainSettings[0].deleted, true);
      expect(restored.domainSettings[0].defaultName, '亲子');
      expect(restored.domainSettings[0].topics.length, 2);
      expect(restored.methodSettings.length, 2);
    });

    test(
      'toEffectiveTagConfig includes local additions and excludes tombstones',
      () {
        final config = fullTagConfig();
        final settings = TagSettings.fromTagConfig(config);
        settings.domainSettings[0].topics[0].deleted = true;
        settings.domainSettings.add(
          DomainSetting(
            key: 'local-domain',
            defaultName: '生活',
            displayName: '生活',
            topics: [
              TopicSetting(
                key: 'local-topic',
                defaultName: '日常',
                displayName: '日常',
              ),
            ],
          ),
        );
        settings.domainSettings.add(
          DomainSetting(
            key: 'empty-domain',
            defaultName: '待整理',
            displayName: '待整理',
            topics: [],
          ),
        );
        settings.methodSettings.add(
          MethodSetting(
            key: 'local-method',
            defaultName: '记录',
            displayName: '记录',
          ),
        );
        settings.domainSettings[1].deleted = true;

        final effective = settings.toEffectiveTagConfig(config);

        expect(effective.domains.map((domain) => domain.id), [
          'parenting',
          'local-domain',
          'empty-domain',
        ]);
        expect(effective.domains.first.topics.map((topic) => topic.name), [
          '亲子沟通',
        ]);
        expect(effective.domains[1].topics.map((topic) => topic.name), ['日常']);
        expect(effective.domains[2].topics, isEmpty);
        expect(effective.methods.map((method) => method.name), [
          '反思',
          '方法论',
          '记录',
        ]);
      },
    );

    test('local additions are available to the AI tag parser', () {
      final config = fullTagConfig();
      final settings = TagSettings.fromTagConfig(config);
      settings.domainSettings.add(
        DomainSetting(
          key: 'local-domain',
          defaultName: '生活',
          displayName: '生活',
          topics: [
            TopicSetting(
              key: 'local-topic',
              defaultName: '日常',
              displayName: '日常',
            ),
          ],
        ),
      );
      settings.methodSettings.add(
        MethodSetting(
          key: 'local-method',
          defaultName: '记录',
          displayName: '记录',
        ),
      );

      final result = const PolishResultParser().parse(
        '今天整理生活。 #生活 #日常 #记录',
        settings.toEffectiveTagConfig(config),
        tagSettings: settings,
      );

      expect(result.tags, ['生活', '日常', '记录']);
    });

    test('AI parser maps renamed labels returned with default names', () {
      final config = fullTagConfig();
      final settings = TagSettings.fromTagConfig(config);
      settings.domainSettings[0].displayName = '育儿';
      settings.domainSettings[0].topics[0].displayName = '陪伴';
      settings.methodSettings[0].displayName = '复盘';

      final result = const PolishResultParser().parse(
        '今天的记录。 #亲子 #陪伴互动 #反思',
        settings.toEffectiveTagConfig(config),
        tagSettings: settings,
      );

      expect(result.tags, ['育儿', '陪伴', '复盘']);
    });

    test('broken JSON falls back with fromJson defaults', () async {
      final restored = TagSettings.fromJson({
        'schemaVersion': 0,
        'domainSettings': null,
        'methodSettings': null,
      });
      expect(restored.domainSettings, isEmpty);
      expect(restored.methodSettings, isEmpty);
    });

    test(
      'toEffectiveTagConfig filters disabled and applies displayName',
      () async {
        final config = fullTagConfig();
        final settings = TagSettings.fromTagConfig(config);
        settings.domainSettings[1].enabled = false;
        settings.domainSettings[0].displayName = '育儿';
        settings.domainSettings[0].topics[0].displayName = '共处时光';
        final effective = settings.toEffectiveTagConfig(config);
        expect(effective.domains.length, 1);
        expect(effective.domains[0].name, '育儿');
        expect(effective.domains[0].topics[0].name, '共处时光');
        expect(effective.methods.length, 2);
      },
    );

    test('countEnabled counts all enabled items', () async {
      final config = fullTagConfig();
      final settings = TagSettings.fromTagConfig(config);
      expect(TagSettingsHelper.countEnabled(settings), 7);
      settings.domainSettings[0].enabled = false;
      expect(TagSettingsHelper.countEnabled(settings), 4);
    });

    test(
      'hiddenInitialTags finds disabled tags by displayName or defaultName',
      () async {
        final config = fullTagConfig();
        final settings = TagSettings.fromTagConfig(config);
        settings.domainSettings[0].enabled = false;
        final hidden = TagSettingsHelper.hiddenInitialTags([
          '亲子',
          '陪伴互动',
          '反思',
        ], settings);
        expect(hidden, contains('亲子'));
        expect(hidden, contains('陪伴互动'));
        expect(hidden.length, 2);
      },
    );

    test('hiddenInitialTags with renamed displayName still matches', () async {
      final config = fullTagConfig();
      final settings = TagSettings.fromTagConfig(config);
      settings.domainSettings[0].enabled = false;
      settings.domainSettings[0].displayName = '育儿';
      final hidden = TagSettingsHelper.hiddenInitialTags([
        '亲子',
        '陪伴互动',
        '反思',
      ], settings);
      expect(hidden, contains('亲子'));
    });

    test(
      'hiddenInitialTags preserves deleted tags but ignores recreated names',
      () {
        final settings = TagSettings.fromTagConfig(fullTagConfig());
        settings.domainSettings[0].deleted = true;
        final hidden = TagSettingsHelper.hiddenInitialTags([
          '亲子',
          '陪伴互动',
        ], settings);
        expect(hidden, containsAll(['亲子', '陪伴互动']));

        settings.domainSettings.add(
          DomainSetting(
            key: 'new-parenting',
            defaultName: '亲子',
            displayName: '亲子',
            topics: [
              TopicSetting(
                key: 'new-bonding',
                defaultName: '陪伴互动',
                displayName: '陪伴互动',
              ),
            ],
          ),
        );
        expect(
          TagSettingsHelper.hiddenInitialTags(['亲子', '陪伴互动'], settings),
          isEmpty,
        );
      },
    );

    test('validateDisplayName rejects invalid names', () async {
      expect(TagSettingsHelper.validateDisplayName(''), isNotNull);
      expect(TagSettingsHelper.validateDisplayName('  '), isNotNull);
      expect(TagSettingsHelper.validateDisplayName('#tag'), isNotNull);
      expect(TagSettingsHelper.validateDisplayName('with space'), isNotNull);
      expect(TagSettingsHelper.validateDisplayName('with\nnewline'), isNotNull);
      expect(TagSettingsHelper.validateDisplayName('with\ttab'), isNotNull);
      expect(TagSettingsHelper.validateDisplayName('valid'), isNull);
    });

    test(
      'effectiveTagConfig helper works same as toEffectiveTagConfig',
      () async {
        final config = fullTagConfig();
        final settings = TagSettings.fromTagConfig(config);
        settings.methodSettings[0].enabled = false;
        final result = TagSettingsHelper.effectiveTagConfig(config, settings);
        expect(result.methods.length, 1);
        expect(result.methods[0].id, 'methodology');
      },
    );

    test('loadTagSettings returns defaults when no storage', () async {
      final storage = _TestStorage();
      final repo = TagSettingsRepository(storage: storage);
      final config = fullTagConfig();
      final settings = await repo.loadTagSettings(config);
      expect(settings.domainSettings.length, 2);
      expect(settings.domainSettings[0].enabled, true);
    });

    test('save and reload preserves changes', () async {
      final storage = _TestStorage();
      final repo = TagSettingsRepository(storage: storage);
      final config = fullTagConfig();
      var settings = await repo.loadTagSettings(config);
      settings.domainSettings[0].displayName = '育儿';
      await repo.saveTagSettings(settings);
      final reloaded = await repo.loadTagSettings(config);
      expect(reloaded.domainSettings[0].displayName, '育儿');
    });

    test('corrupted JSON falls back to defaults', () async {
      final storage = _TestStorage({'tag_settings': 'not json at all!!!'});
      final repo = TagSettingsRepository(storage: storage);
      final config = fullTagConfig();
      final settings = await repo.loadTagSettings(config);
      expect(settings.domainSettings.length, 2);
    });
  });
}
