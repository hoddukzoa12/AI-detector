import 'package:flutter/material.dart';
import 'package:infocutter_app/models/webview_model.dart';
import 'package:infocutter_app/pages/developers/storage/cookie_storage_section.dart';
import 'package:infocutter_app/pages/developers/storage/platform_storage_sections.dart';
import 'package:infocutter_app/pages/developers/storage/storage_manager_widgets.dart';
import 'package:infocutter_app/pages/developers/storage/web_storage_rows.dart';
import 'package:infocutter_app/services/app_runtime.dart';
import 'package:infocutter_app/services/developer_storage_service.dart';
import 'package:infocutter_app/util.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:provider/provider.dart';

class StorageManager extends StatefulWidget {
  const StorageManager({super.key});

  @override
  State<StorageManager> createState() => _StorageManagerState();
}

class _StorageManagerState extends State<StorageManager> {
  late final DeveloperStorageService _storageService;

  var localStorageKeyTrackingEdit = <bool>[];
  var localStorageValueTrackingEdit = <bool>[];
  var sessionStorageKeyTrackingEdit = <bool>[];
  var sessionStorageValueTrackingEdit = <bool>[];

  final TextEditingController _newLocalStorageKeyController =
      TextEditingController();
  final TextEditingController _newLocalStorageValueController =
      TextEditingController();

  final TextEditingController _newSessionStorageKeyController =
      TextEditingController();
  final TextEditingController _newSessionStorageValueController =
      TextEditingController();

  final _newLocalStorageItemFormKey = GlobalKey<FormState>();
  final _newSessionStorageItemFormKey = GlobalKey<FormState>();
  var _storageServiceInitialized = false;

  @override
  void initState() {
    super.initState();

    localStorageKeyTrackingEdit = [];
    localStorageValueTrackingEdit = [];
    sessionStorageKeyTrackingEdit = [];
    sessionStorageValueTrackingEdit = [];
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_storageServiceInitialized) {
      return;
    }

    final appRuntime = Provider.of<AppRuntime>(context, listen: false);
    _storageService = DeveloperStorageService.fromRuntime(appRuntime);
    _storageServiceInitialized = true;
  }

  @override
  void dispose() {
    _newLocalStorageKeyController.dispose();
    _newLocalStorageValueController.dispose();
    _newSessionStorageKeyController.dispose();
    _newSessionStorageValueController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _buildStorageManager();
  }

  Widget _buildStorageManager() {
    return LayoutBuilder(
      builder: (context, constraints) {
        var entryItems = <Widget>[
          _buildCookiesExpansionTile(constraints),
          _buildWebLocalStorageExpansionTile(constraints),
          _buildWebSessionStorageExpansionTile(constraints),
        ];

        if (!Util.isWindows()) {
          entryItems
              .add(_buildHttpAuthCredentialDatabaseExpansionTile(constraints));
        }

        if (Util.isAndroid()) {
          entryItems.add(_buildAndroidWebStorageExpansionTile(constraints));
        } else if (Util.isIOS() || Util.isMacOS()) {
          entryItems.add(_buildIOSWebStorageExpansionTile(constraints));
        }

        return ListView.builder(
          itemCount: entryItems.length,
          itemBuilder: (context, index) {
            return entryItems[index];
          },
        );
      },
    );
  }

  Widget _buildCookiesExpansionTile(BoxConstraints constraints) {
    return CookieStorageSection(
      constraints: constraints,
      cookies: _storageService.cookies,
    );
  }

  Widget _buildWebLocalStorageExpansionTile(BoxConstraints constraints) {
    return Consumer<WebViewModel>(
      builder: (context, webViewModel, child) {
        var webViewController = webViewModel.webViewController;

        return FutureBuilder(
          future: webViewController?.webStorage.localStorage.getItems(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return Container();
            }

            return _buildLocalStorageContent(
              constraints,
              webViewController,
              snapshot.data ?? <WebStorageItem>[],
            );
          },
        );
      },
    );
  }

  Widget _buildWebSessionStorageExpansionTile(BoxConstraints constraints) {
    return Consumer<WebViewModel>(
      builder: (context, webViewModel, child) {
        var webViewController = webViewModel.webViewController;

        return FutureBuilder(
          future: webViewController?.webStorage.sessionStorage.getItems(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return Container();
            }

            return _buildSessionStorageContent(
              constraints,
              webViewController,
              snapshot.data ?? <WebStorageItem>[],
            );
          },
        );
      },
    );
  }

  Widget _buildLocalStorageContent(
    BoxConstraints constraints,
    InAppWebViewController? webViewController,
    List<WebStorageItem> webStorageItems,
  ) {
    if (localStorageValueTrackingEdit.length != webStorageItems.length) {
      localStorageKeyTrackingEdit = List.filled(webStorageItems.length, false);
      localStorageValueTrackingEdit =
          List.filled(webStorageItems.length, false);
    }

    final rowContext = WebStorageRowContext(
      constraints: constraints,
      storage: webViewController?.webStorage.localStorage,
      keyTrackingEdit: localStorageKeyTrackingEdit,
      valueTrackingEdit: localStorageValueTrackingEdit,
      onRefresh: () => setState(() {}),
    );
    final rows = webStorageItems.map((webStorageItem) {
      return buildWebStorageRow(
        rowContext,
        webStorageItem,
        webStorageItems.indexOf(webStorageItem),
      );
    }).toList();

    return _buildWebStorageContent(
      constraints: constraints,
      title: "Local Storage",
      rows: rows,
      form: AddWebStorageItemForm(
        formKey: _newLocalStorageItemFormKey,
        nameController: _newLocalStorageKeyController,
        valueController: _newLocalStorageValueController,
        labelName: "Local Item Key",
        labelValue: "Local Item Value",
        onAdded: (name, value) async {
          await webViewController?.webStorage.localStorage
              .setItem(key: name, value: value);
        },
        onRefresh: () => setState(() {}),
      ),
      onClear: () async {
        await webViewController?.webStorage.localStorage.clear();
        setState(() {});
      },
    );
  }

  Widget _buildSessionStorageContent(
    BoxConstraints constraints,
    InAppWebViewController? webViewController,
    List<WebStorageItem> webStorageItems,
  ) {
    if (sessionStorageValueTrackingEdit.length != webStorageItems.length) {
      sessionStorageKeyTrackingEdit =
          List.filled(webStorageItems.length, false);
      sessionStorageValueTrackingEdit =
          List.filled(webStorageItems.length, false);
    }

    final rowContext = WebStorageRowContext(
      constraints: constraints,
      storage: webViewController?.webStorage.sessionStorage,
      keyTrackingEdit: sessionStorageKeyTrackingEdit,
      valueTrackingEdit: sessionStorageValueTrackingEdit,
      onRefresh: () => setState(() {}),
    );
    final rows = webStorageItems.map((webStorageItem) {
      return buildWebStorageRow(
        rowContext,
        webStorageItem,
        webStorageItems.indexOf(webStorageItem),
      );
    }).toList();

    return _buildWebStorageContent(
      constraints: constraints,
      title: "Session Storage",
      rows: rows,
      form: AddWebStorageItemForm(
        formKey: _newSessionStorageItemFormKey,
        nameController: _newSessionStorageKeyController,
        valueController: _newSessionStorageValueController,
        labelName: "Session Item Key",
        labelValue: "Session Item Value",
        onAdded: (name, value) async {
          await webViewController?.webStorage.sessionStorage
              .setItem(key: name, value: value);
        },
        onRefresh: () => setState(() {}),
      ),
      onClear: () async {
        await webViewController?.webStorage.sessionStorage.clear();
        setState(() {});
      },
    );
  }

  Widget _buildWebStorageContent({
    required BoxConstraints constraints,
    required String title,
    required List<DataRow> rows,
    required Widget form,
    required Future<void> Function() onClear,
  }) {
    return ExpansionTile(
      onExpansionChanged: (value) {
        FocusScope.of(context).unfocus();
      },
      title: Text(
        title,
        style: const TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold),
      ),
      children: <Widget>[
        SizedBox(
          width: constraints.minWidth,
          child: DataTable(
            columnSpacing: 0.0,
            columns: const <DataColumn>[
              DataColumn(
                label: Text(
                  "Key",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.0),
                ),
              ),
              DataColumn(
                label: Text(
                  "Value",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.0),
                ),
              ),
              DataColumn(
                label: Text(
                  "Delete",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.0),
                ),
              ),
            ],
            rows: rows,
          ),
        ),
        form,
        SizedBox(
          width: MediaQuery.of(context).size.width,
          child: TextButton(
            onPressed: onClear,
            child: const Text("Clear items"),
          ),
        ),
      ],
    );
  }

  Widget _buildAndroidWebStorageExpansionTile(BoxConstraints constraints) {
    return AndroidWebStorageSection(
      webStorage: _storageService.webStorage,
      onRefresh: () => setState(() {}),
    );
  }

  Widget _buildIOSWebStorageExpansionTile(BoxConstraints constraints) {
    return AppleWebStorageSection(
      constraints: constraints,
      webStorage: _storageService.webStorage,
      onRefresh: () => setState(() {}),
    );
  }

  Widget _buildHttpAuthCredentialDatabaseExpansionTile(
      BoxConstraints constraints) {
    return HttpAuthCredentialsSection(
      constraints: constraints,
      httpAuthCredentials: _storageService.httpAuthCredentials,
      onRefresh: () => setState(() {}),
    );
  }
}
