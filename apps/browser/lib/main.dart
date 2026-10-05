import 'dart:async';
import 'dart:io';

// ignore_for_file: invalid_use_of_protected_member

import 'package:context_menus/context_menus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:infocutter_app/infocutter/application/block_rules/save_picked_block_rule_use_case.dart';
import 'package:infocutter_app/infocutter/ai_config_service.dart';
import 'package:infocutter_app/infocutter/ai_rule_service.dart';
import 'package:infocutter_app/infocutter/evidence_service.dart';
import 'package:infocutter_app/infocutter/infocutter_providers.dart';
import 'package:infocutter_app/infocutter/infocutter_service.dart';
import 'package:infocutter_app/infocutter/network_filter_service.dart';
import 'package:infocutter_app/infocutter/text_block_service.dart';
import 'package:infocutter_app/infocutter/watch_service.dart';
import 'package:infocutter_app/l10n/generated/app_localizations.dart';
import 'package:infocutter_app/models/browser_model.dart';
import 'package:infocutter_app/models/webview_model.dart';
import 'package:infocutter_app/models/window_model.dart';
import 'package:infocutter_app/services/app_automation_bridge.dart';
import 'package:infocutter_app/services/app_runtime.dart';
import 'package:infocutter_app/services/app_automation_controller.dart';
import 'package:infocutter_app/services/browser_persistence.dart';
import 'package:infocutter_app/services/download_service.dart';
import 'package:infocutter_app/services/web_archive_service.dart';
import 'package:infocutter_app/services/window_manager_window_service.dart';
import 'package:infocutter_app/services/window_service.dart';
import 'package:infocutter_app/theme/infocutter_theme.dart';
import 'package:infocutter_app/util.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:window_manager_plus/window_manager_plus.dart';
import 'package:path/path.dart' as p;

import 'browser.dart';

int windowId = 0;

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  final bootstrap = await _bootstrapApp(args);
  runApp(
    MultiProvider(
      providers: _appProviders(bootstrap),
      child: const FlutterBrowserApp(),
    ),
  );
}

Future<_AppBootstrap> _bootstrapApp(List<String> args) async {
  await _initializeDesktopWindow(args);
  _configureDesktopDatabase();
  final browserPersistence = SqfliteBrowserPersistence(
    database: await _openBrowserDatabase(),
    initialWindowId: _initialWindowModelId(args),
  );
  await _configureDesktopWindow();
  final appRuntime = await _appRuntime();
  await _initializeMobileServices();
  return _AppBootstrap(
    appRuntime: appRuntime,
    browserPersistence: browserPersistence,
  );
}

Future<void> _initializeDesktopWindow(List<String> args) async {
  if (Util.isDesktop()) {
    windowId = args.isNotEmpty ? int.tryParse(args[0]) ?? 0 : 0;
    await WindowManagerPlus.ensureInitialized(windowId);
  }
}

void _configureDesktopDatabase() {
  if (!Util.isDesktop()) return;
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
}

String? _initialWindowModelId(List<String> args) =>
    Util.isDesktop() && args.length > 1 ? args[1] : null;

Future<Database> _openBrowserDatabase() async {
  final appDocumentsDir = await getApplicationDocumentsDirectory();
  return databaseFactory.openDatabase(
    p.join(appDocumentsDir.path, "databases", "myDb.db"),
    options: OpenDatabaseOptions(
      version: 1,
      singleInstance: false,
      onCreate: _createBrowserDatabase,
    ),
  );
}

Future<void> _createBrowserDatabase(Database db, int version) async {
  await db.execute('CREATE TABLE browser (id INTEGER PRIMARY KEY, json TEXT)');
  await db.execute('CREATE TABLE windows (id TEXT PRIMARY KEY, json TEXT)');
}

Future<void> _configureDesktopWindow() async {
  if (!Util.isDesktop()) return;
  WindowManagerPlus.current.waitUntilReadyToShow(
    _desktopWindowOptions(),
    () async {
      if (!Util.isWindows()) {
        await WindowManagerPlus.current.setAsFrameless();
        await WindowManagerPlus.current.setHasShadow(true);
      }
      await WindowManagerPlus.current.show();
      await WindowManagerPlus.current.focus();
      await Future<void>.delayed(const Duration(milliseconds: 300));
      await _restoreDesktopWindowVisibility();
    },
  );
}

Future<void> _restoreDesktopWindowVisibility() async {
  final bounds = await WindowManagerPlus.current.getBounds();
  if (bounds.top >= 0 && bounds.left >= 0) return;
  await WindowManagerPlus.current.setPosition(const Offset(160, 120));
  await WindowManagerPlus.current.focus();
}

WindowOptions _desktopWindowOptions() => WindowOptions(
      center: true,
      backgroundColor: Colors.transparent,
      titleBarStyle:
          Util.isWindows() ? TitleBarStyle.normal : TitleBarStyle.hidden,
      minimumSize: const Size(1280, 720),
      size: const Size(1280, 720),
    );

Future<AppRuntime> _appRuntime() async {
  final webArchiveDirectory = (await getApplicationSupportDirectory()).path;
  return AppRuntime(
    webArchiveDirectory: webArchiveDirectory,
    webViewEnvironment: await _webViewEnvironment(),
  );
}

Future<WebViewEnvironment?> _webViewEnvironment() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.windows) return null;
  final availableVersion = await WebViewEnvironment.getAvailableVersion();
  assert(
    availableVersion != null,
    'Failed to find an installed WebView2 Runtime or non-stable Microsoft Edge installation.',
  );

  return WebViewEnvironment.create(
    settings: WebViewEnvironmentSettings(userDataFolder: 'infocutter_app'),
  );
}

Future<void> _initializeMobileServices() async {
  if (!Util.isMobile()) return;
  await FlutterDownloader.initialize(debug: kDebugMode);
  // 카메라·마이크·저장소를 여기서 미리 요청하지 않는다(upstream 잔재였다).
  // 브라우저를 열자마자 문맥 없이 카메라를 물으면 사용자는 거절하거나 앱을 지운다.
  // 페이지가 실제로 요청할 때 WebView 가 OS 프롬프트를 띄우므로 사전 요청은 불필요하다.
}

List<SingleChildWidget> _appProviders(_AppBootstrap bootstrap) => [
      ..._coreProviders(bootstrap),
      ..._browserProviders(bootstrap.browserPersistence),
      ...infocutterProviders(),
      Provider<AppAutomationController>(
        create: (context) => AppAutomationController(
          browser: context.read<BrowserModel>(),
          window: context.read<WindowModel>(),
          infocutter: context.read<InfocutterService>(),
          watch: context.read<WatchService>(),
          evidence: context.read<EvidenceService>(),
          textBlocks: context.read<TextBlockService>(),
          networkFilters: context.read<NetworkFilterService>(),
          aiConfig: context.read<AiConfigService>(),
          aiRules: context.read<AiRuleService>(),
          savePickedBlockRule: context.read<SavePickedBlockRuleUseCase>(),
        ),
      ),
      Provider<AppAutomationBridge>(
        lazy: false,
        create: (context) {
          final bridge = AppAutomationBridge.forController(
            context.read<AppAutomationController>(),
          );
          unawaited(bridge.start());
          return bridge;
        },
        dispose: (_, bridge) => unawaited(bridge.stop()),
      ),
    ];

List<SingleChildWidget> _coreProviders(_AppBootstrap bootstrap) => [
      Provider<AppRuntime>.value(value: bootstrap.appRuntime),
      Provider<DownloadService>.value(
        value: const FlutterDownloadService(),
      ),
      Provider<WindowLauncher>.value(
        value: const WindowManagerPlusWindowLauncher(),
      ),
      Provider<WindowControls>.value(
        value: const WindowManagerPlusWindowControls(),
      ),
      ProxyProvider<AppRuntime, WebArchiveService>(
        update: (context, runtime, previous) =>
            InAppWebViewArchiveService(runtime: runtime),
      ),
    ];

List<SingleChildWidget> _browserProviders(
  SqfliteBrowserPersistence browserPersistence,
) =>
    [
      ChangeNotifierProvider(
        create: (context) => BrowserModel(
          persistence: browserPersistence,
          windowPersistence: browserPersistence,
          windowLauncher: context.read<WindowLauncher>(),
        ),
      ),
      ChangeNotifierProvider(
        create: (context) => WebViewModel(),
      ),
      ChangeNotifierProxyProvider<WebViewModel, WindowModel>(
        update: (context, webViewModel, windowModel) {
          windowModel!.setCurrentWebViewModel(webViewModel);
          return windowModel;
        },
        create: (BuildContext context) => WindowModel(
          persistence: browserPersistence,
        ),
      ),
    ];

class _AppBootstrap {
  const _AppBootstrap({
    required this.appRuntime,
    required this.browserPersistence,
  });

  final AppRuntime appRuntime;
  final SqfliteBrowserPersistence browserPersistence;
}

class FlutterBrowserApp extends StatefulWidget {
  const FlutterBrowserApp({super.key});

  @override
  State<FlutterBrowserApp> createState() => _FlutterBrowserAppState();
}

class _FlutterBrowserAppState extends State<FlutterBrowserApp>
    with WindowListener {
  // https://github.com/pichillilorenzo/window_manager_plus/issues/5
  AppLifecycleListener? _appLifecycleListener;

  @override
  void initState() {
    super.initState();
    // WindowManagerPlus 는 데스크톱 전용이다. 모바일에서는 ensureInitialized 를
    // 부르지 않으므로 current 가 없다 — 여기서 무조건 만지면 첫 프레임에서 죽는다.
    if (!Util.isDesktop()) return;
    WindowManagerPlus.current.addListener(this);

    // https://github.com/pichillilorenzo/window_manager_plus/issues/5
    if (WindowManagerPlus.current.id > 0 && Platform.isMacOS) {
      _appLifecycleListener = AppLifecycleListener(
        onStateChange: _handleStateChange,
      );
    }
  }

  void _handleStateChange(AppLifecycleState state) {
    // https://github.com/pichillilorenzo/window_manager_plus/issues/5
    if (WindowManagerPlus.current.id > 0 &&
        Platform.isMacOS &&
        state == AppLifecycleState.hidden) {
      SchedulerBinding.instance
          .handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    }
  }

  @override
  void dispose() {
    if (Util.isDesktop()) {
      WindowManagerPlus.current.removeListener(this);
    }
    _appLifecycleListener?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = context.select<BrowserModel, ThemeMode>(
      (browserModel) =>
          browserModel.settingsSnapshot.themeMode.materialThemeMode,
    );
    final materialApp = MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      theme: infocutterTheme(Brightness.light),
      darkTheme: infocutterTheme(Brightness.dark),
      themeMode: themeMode,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      initialRoute: '/',
      routes: {
        '/': (context) => const Browser(),
      },
    );

    return Util.isMobile()
        ? materialApp
        : ContextMenuOverlay(
            child: materialApp,
          );
  }

  @override
  void onWindowFocus([int? windowId]) {
    setState(() {});
    if (Util.isDesktop() && !Util.isWindows()) {
      WindowManagerPlus.current.setMovable(false);
    }
  }

  @override
  void onWindowBlur([int? windowId]) {
    if (Util.isDesktop() && !Util.isWindows()) {
      WindowManagerPlus.current.setMovable(true);
    }
  }
}
