import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:infocutter_app/models/webview_model.dart';
import 'package:infocutter_app/services/developer_storage_service.dart';
import 'package:provider/provider.dart';

class AndroidWebStorageSection extends StatelessWidget {
  const AndroidWebStorageSection({
    required this.webStorage,
    required this.onRefresh,
    super.key,
  });

  final BrowserWebStorage? webStorage;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      onExpansionChanged: (value) => FocusScope.of(context).unfocus(),
      title: const Text(
        "Web Storage Android",
        style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold),
      ),
      children: <Widget>[
        _buildQuotaTile(),
        _buildUsageTile(),
      ],
    );
  }

  Widget _buildQuotaTile() => ListTile(
        title: const Text("Quota"),
        subtitle: _originSelector(
          (url) => _storageValue(webStorage?.getQuotaForOrigin(
            origin: url.origin,
          )),
        ),
      );

  Widget _buildUsageTile() => _originSelector(
        (url) => ListTile(
          title: const Text("Usage"),
          subtitle: _storageValue(webStorage?.getUsageForOrigin(
            origin: url.origin,
          )),
          trailing: IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () async {
              await webStorage?.deleteOrigin(origin: url.origin);
              onRefresh();
            },
          ),
        ),
      );

  Widget _originSelector(Widget Function(Uri url) builder) {
    return Selector<WebViewModel, Uri>(
      selector: (context, webViewModel) => webViewModel.url!,
      builder: (context, url, child) => builder(url),
    );
  }

  Widget _storageValue(Future<int>? future) => FutureBuilder(
        future: future,
        builder: (context, snapshot) {
          return Text(snapshot.hasData ? snapshot.data.toString() : "");
        },
      );
}

class AppleWebStorageSection extends StatelessWidget {
  const AppleWebStorageSection({
    required this.constraints,
    required this.webStorage,
    required this.onRefresh,
    super.key,
  });

  final BoxConstraints constraints;
  final BrowserWebStorage? webStorage;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: webStorage?.fetchDataRecords(dataTypes: WebsiteDataType.ALL),
      builder: (context, snapshot) {
        final dataRecords = snapshot.hasData
            ? (snapshot.data as List<WebsiteDataRecord>)
            : <WebsiteDataRecord>[];
        final rows = _buildRows(context, dataRecords);

        return _buildDataRecordsTile(context, rows);
      },
    );
  }

  Widget _buildDataRecordsTile(BuildContext context, List<DataRow> rows) {
    return ExpansionTile(
      onExpansionChanged: (value) => FocusScope.of(context).unfocus(),
      title: const Text(
        "Web Storage iOS",
        style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold),
      ),
      children: <Widget>[
        _storageTable(
          width: constraints.minWidth,
          columns: _appleStorageColumns(),
          rows: rows,
        ),
        _clearAllButton(context),
      ],
    );
  }

  List<DataColumn> _appleStorageColumns() => const <DataColumn>[
        DataColumn(label: _StorageHeader("Display Name")),
        DataColumn(label: _StorageHeader("Data Types")),
        DataColumn(label: _StorageHeader("Delete")),
      ];

  Widget _clearAllButton(BuildContext context) => SizedBox(
        width: MediaQuery.of(context).size.width,
        child: TextButton(
          child: const Text("Clear all"),
          onPressed: () async {
            await webStorage?.removeDataModifiedSince(
              dataTypes: WebsiteDataType.ALL,
              date: DateTime.fromMillisecondsSinceEpoch(0),
            );
            onRefresh();
          },
        ),
      );

  List<DataRow> _buildRows(
    BuildContext context,
    List<WebsiteDataRecord> dataRecords,
  ) {
    return dataRecords.map((dataRecord) {
      return DataRow(cells: <DataCell>[
        _copyableTextCell(
          width: constraints.maxWidth / 3,
          value: dataRecord.displayName ?? "",
          style: const TextStyle(fontSize: 12.0),
        ),
        DataCell(
          SizedBox(
            width: constraints.maxWidth / 3,
            child: Text(
              dataRecord.dataTypes?.join(", ") ?? "",
              style: const TextStyle(fontSize: 12.0),
              softWrap: true,
            ),
          ),
          onTap: () => _showDataTypesDialog(context, dataRecord),
        ),
        _deleteCell(() => _deleteDataRecord(dataRecord)),
      ]);
    }).toList();
  }

  void _showDataTypesDialog(
    BuildContext context,
    WebsiteDataRecord dataRecord,
  ) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          content: Text(
            dataRecord.dataTypes?.join(",\n") ?? "",
            style: const TextStyle(fontSize: 12.0),
            softWrap: true,
          ),
        );
      },
    );
  }

  Future<void> _deleteDataRecord(WebsiteDataRecord dataRecord) async {
    if (dataRecord.dataTypes != null) {
      await webStorage?.removeDataFor(
        dataTypes: dataRecord.dataTypes!,
        dataRecords: [dataRecord],
      );
    }
    onRefresh();
  }
}

class HttpAuthCredentialsSection extends StatelessWidget {
  const HttpAuthCredentialsSection({
    required this.constraints,
    required this.httpAuthCredentials,
    required this.onRefresh,
    super.key,
  });

  final BoxConstraints constraints;
  final HttpAuthCredentials? httpAuthCredentials;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: httpAuthCredentials?.getAllAuthCredentials(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Container();
        }

        final credentialsByProtectionSpace =
            snapshot.data ?? <URLProtectionSpaceHttpAuthCredentials>[];
        return _buildCredentialsTile(context, credentialsByProtectionSpace);
      },
    );
  }

  Widget _buildCredentialsTile(
    BuildContext context,
    List<URLProtectionSpaceHttpAuthCredentials> credentialsByProtectionSpace,
  ) {
    return ExpansionTile(
      onExpansionChanged: (value) => FocusScope.of(context).unfocus(),
      title: const Text(
        "Http Auth Credentials Database",
        style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold),
      ),
      children: [
        ..._buildDataTables(credentialsByProtectionSpace),
        TextButton(
          child: const Text("Clear all"),
          onPressed: () async {
            await httpAuthCredentials?.clearAllAuthCredentials();
            onRefresh();
          },
        ),
      ],
    );
  }

  List<Widget> _buildDataTables(
    List<URLProtectionSpaceHttpAuthCredentials> credentialsByProtectionSpace,
  ) {
    return credentialsByProtectionSpace.map((protectionSpaceCredentials) {
      final protectionSpace = protectionSpaceCredentials.protectionSpace;
      return _buildProtectionSpaceTable(
        protectionSpace,
        _authRows(protectionSpaceCredentials),
      );
    }).toList();
  }

  List<DataRow> _authRows(
    URLProtectionSpaceHttpAuthCredentials protectionSpaceCredentials,
  ) {
    final protectionSpace = protectionSpaceCredentials.protectionSpace;
    return protectionSpaceCredentials.credentials
            ?.map((credential) => _authRow(protectionSpace, credential))
            .toList() ??
        <DataRow>[];
  }

  DataRow _authRow(
    URLProtectionSpace? protectionSpace,
    URLCredential credential,
  ) {
    return DataRow(cells: <DataCell>[
      _copyableTextCell(
        width: constraints.maxWidth / 3,
        value: credential.username ?? "",
      ),
      _copyableTextCell(
        width: constraints.maxWidth / 3,
        value: credential.password ?? "",
      ),
      _deleteCell(() => _deleteCredential(protectionSpace, credential)),
    ]);
  }

  Future<void> _deleteCredential(
    URLProtectionSpace? protectionSpace,
    URLCredential credential,
  ) async {
    if (protectionSpace != null) {
      await httpAuthCredentials?.removeHttpAuthCredential(
        protectionSpace: protectionSpace,
        credential: credential,
      );
    }
    onRefresh();
  }

  Widget _buildProtectionSpaceTable(
    URLProtectionSpace? protectionSpace,
    List<DataRow> rows,
  ) {
    return Column(
      children: <Widget>[
        const Text(
          "Protection Space",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20.0),
        ),
        const SizedBox(height: 10.0),
        Text(_protectionSpaceLabel(protectionSpace)),
        _storageTable(
          width: constraints.minWidth,
          columns: _authColumns(),
          rows: rows,
        )
      ],
    );
  }

  String _protectionSpaceLabel(URLProtectionSpace? protectionSpace) {
    final port = protectionSpace?.port;
    final portLabel = port != null && port > 0 ? port.toString() : "";
    return "Protocol: ${protectionSpace?.protocol ?? ""}, "
        "Host: ${protectionSpace?.host ?? ""}, "
        "Port: $portLabel, "
        "Realm: ${protectionSpace?.realm ?? ""}";
  }

  List<DataColumn> _authColumns() => const <DataColumn>[
        DataColumn(label: _StorageHeader("Username")),
        DataColumn(label: _StorageHeader("Password")),
        DataColumn(label: _StorageHeader("Delete")),
      ];
}

Widget _storageTable({
  required double width,
  required List<DataColumn> columns,
  required List<DataRow> rows,
}) =>
    SizedBox(
      width: width,
      child: DataTable(
        columnSpacing: 0.0,
        columns: columns,
        rows: rows,
      ),
    );

DataCell _copyableTextCell({
  required double width,
  required String value,
  TextStyle style = const TextStyle(fontSize: 16.0),
}) =>
    DataCell(
      SizedBox(
        width: width,
        child: Text(value, style: style, softWrap: true),
      ),
      onTap: () {
        Clipboard.setData(ClipboardData(text: value));
      },
    );

DataCell _deleteCell(Future<void> Function() onDelete) => DataCell(
      IconButton(
        icon: const Icon(Icons.cancel),
        onPressed: onDelete,
      ),
    );

class _StorageHeader extends StatelessWidget {
  const _StorageHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16.0),
      );
}
