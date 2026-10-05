# Infocutter Module Boundaries

Use this map when reviewing or refactoring `main/apps/infocutter-app`.

## Current Ownership Map

| Path | Owns | Must Not Own |
| --- | --- | --- |
| `lib/main.dart` | app bootstrap, platform initialization, provider wiring | domain rules, SQL calls, WebView event behavior, UI workflows |
| `lib/browser.dart` | top-level browser shell, tab rendering boundary | persisted tab data, menu action logic, domain rules |
| `lib/webview_tab.dart` | active WebView widget and lifecycle callbacks | selector generation, archive path policy, storage policy, large dialog workflows |
| `lib/app_bar/` | app bars, menu rendering, button layout | persistence, plugin storage calls, WebView policy, domain mutation rules |
| `lib/pages/` | screens and forms | repository implementations, raw plugin managers, domain codecs |
| `lib/models/` | serializable app state and runtime state holders | `Widget`, `BuildContext`, routes/dialogs, SQL, native window creation |
| `lib/infocutter/` | selector/domain rules, rule store, content blockers, picker protocol | Flutter UI, page layout, browser chrome |
| `lib/services/` | app ports/adapters, persistence, platform integrations, factories | arbitrary UI widgets or presentation layout |
| `lib/l10n/` | user-visible text resources | business rules |

## Required Boundaries

### Tab state

- `WindowModel` exposes tab data as `WebViewModel` or future `TabSession` data.
- `WindowModel` must not import `webview_tab.dart`.
- `WindowModel` must not store `Widget`, `GlobalKey`, or `BuildContext`.
- `Browser` is the render boundary that may create `WebViewTab(webViewModel: ...)`.

### WebView runtime

- `WebViewModel` may temporarily hold runtime handles:
  - `InAppWebViewController`
  - `PullToRefreshController`
  - `FindInteractionController`
  - screenshot bytes
  - settings
- Persisted representations must not depend on those handles.
- If a persisted/runtime split is touched, prefer adding:
  - `TabSession` for persisted fields
  - `WebViewRuntimeState` for controller handles

### App runtime

- Web archive directory and `WebViewEnvironment` belong behind `AppRuntime`.
- WebView setting defaults belong behind `WebViewSettingsFactory`.
- Do not import `main.dart` outside bootstrap.

### Persistence

- Browser/window SQL belongs in `BrowserPersistence` / `WindowPersistence` implementations.
- Infocutter rule storage belongs in `InfocutterStore`.
- UI must call services or models, not raw database methods.

### Plugin adapters

Introduce narrow interfaces when UI directly touches plugin managers:

- `BrowserStorageService`: cookies, local storage, session storage, web storage, auth credentials.
- `WebArchiveService`: path generation and `saveWebArchive` orchestration.
- `WindowLauncher`: native `WindowManagerPlus.createWindow` behavior.
- `DownloadService`: mobile download setup and request handling.

## Refactor Targets

| Current hotspot | Target split |
| --- | --- |
| `lib/app_bar/webview_tab_app_bar.dart` | `BrowserCommand`, `MenuActionDescriptor`, `WebArchiveService`, focused popup widgets |
| `lib/webview_tab.dart` | `WebViewEventCoordinator`, `ErrorPageBuilder`, `DownloadHandler`, `InfocutterPickerFlow` |
| `lib/pages/developers/storage_manager.dart` | `BrowserStorageService` + small table/editor widgets |
| `lib/pages/settings/*_settings.dart` | setting row builders + `WebViewSettingsMutator` |
| `lib/models/browser_model.dart` | move native window launch to `WindowLauncher` |
| `lib/models/webview_model.dart` | split serializable `TabSession` from runtime handles |

## Forbidden Import Checks

- `lib/models/**` must not import:
  - `package:flutter/material.dart`
  - `package:flutter/widgets.dart`
  - `webview_tab.dart`
  - page/app-bar files
- `lib/infocutter/**` must not import:
  - app bars
  - pages
  - `main.dart`
- `lib/pages/**` and `lib/app_bar/**` must not import:
  - `main.dart`
  - raw database packages
  - new storage implementations directly

Existing legacy exceptions must be reduced when touched; do not add new ones.
