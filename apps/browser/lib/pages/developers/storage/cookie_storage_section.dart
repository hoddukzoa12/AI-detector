import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:infocutter_app/models/webview_model.dart';
import 'package:infocutter_app/pages/developers/storage/storage_manager_widgets.dart';
import 'package:infocutter_app/services/developer_storage_service.dart';
import 'package:provider/provider.dart';

class CookieStorageSection extends StatefulWidget {
  const CookieStorageSection({
    required this.constraints,
    required this.cookies,
    super.key,
  });

  final BoxConstraints constraints;
  final CookieStorage cookies;

  @override
  State<CookieStorageSection> createState() => _CookieStorageSectionState();
}

class _CookieStorageSectionState extends State<CookieStorageSection> {
  var _cookieNameTrackingEdit = <bool>[];
  var _cookieValueTrackingEdit = <bool>[];

  final _newCookieNameController = TextEditingController();
  final _newCookieValueController = TextEditingController();
  final _newCookiePathController = TextEditingController(text: "/");
  final _newCookieDomainController = TextEditingController();

  bool _newCookieIsSecure = false;
  DateTime? _newCookieExpiresDate;

  final _newCookieFormKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _newCookieNameController.dispose();
    _newCookieValueController.dispose();
    _newCookiePathController.dispose();
    _newCookieDomainController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Selector<WebViewModel, WebUri>(
      selector: (context, webViewModel) => webViewModel.url!,
      builder: (context, url, child) {
        return FutureBuilder(
          future: widget.cookies.getCookies(url: url),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return Container();
            }

            final cookies = snapshot.data ?? <Cookie>[];
            final rows = _buildRows(url, cookies);
            return _buildCookiesTile(context, url, rows);
          },
        );
      },
    );
  }

  Widget _buildCookiesTile(
    BuildContext context,
    WebUri url,
    List<DataRow> rows,
  ) =>
      ExpansionTile(
        onExpansionChanged: (value) => FocusScope.of(context).unfocus(),
        title: const Text(
          "Cookies",
          style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold),
        ),
        children: <Widget>[
          _buildCookieTable(rows),
          _buildNewCookieForm(context, url),
          _buildCookieActions(url),
        ],
      );

  Widget _buildCookieTable(List<DataRow> rows) => SizedBox(
        width: widget.constraints.minWidth,
        child: DataTable(
          columnSpacing: 0.0,
          columns: _cookieColumns(),
          rows: rows,
        ),
      );

  List<DataColumn> _cookieColumns() => const <DataColumn>[
        DataColumn(label: _CookieHeader("Name")),
        DataColumn(label: _CookieHeader("Value")),
        DataColumn(label: _CookieHeader("Delete")),
      ];

  Widget _buildCookieActions(WebUri url) => Row(
        children: <Widget>[
          Expanded(
            child: TextButton(
              child: const Text("Clear cookies"),
              onPressed: () async {
                await widget.cookies.deleteCookies(url: url);
                setState(() {});
              },
            ),
          ),
          Expanded(
            child: TextButton(
              child: const Text("Clear all"),
              onPressed: () async {
                await widget.cookies.deleteAllCookies();
                setState(() {});
              },
            ),
          )
        ],
      );

  List<DataRow> _buildRows(WebUri url, List<Cookie> cookies) {
    if (_cookieValueTrackingEdit.length != cookies.length) {
      _cookieNameTrackingEdit = List.filled(cookies.length, false);
      _cookieValueTrackingEdit = List.filled(cookies.length, false);
    }

    return cookies.map((cookie) {
      final index = cookies.indexOf(cookie);
      return DataRow(cells: <DataCell>[
        _buildCookieNameCell(url, cookie, index),
        _buildCookieValueCell(url, cookie, index),
        _buildDeleteCookieCell(url, cookie),
      ]);
    }).toList();
  }

  DataCell _buildCookieNameCell(WebUri url, Cookie cookie, int index) {
    return buildEditableStorageDataCell(
      EditableStorageDataCellConfig(
        width: widget.constraints.maxWidth / 3,
        onFieldSubmitted: (newValue) => _renameCookie(url, cookie, newValue),
        initialValue: cookie.name,
        index: index,
        trackingEditStatus: _cookieNameTrackingEdit,
        onRefresh: () => setState(() {}),
      ),
    );
  }

  Future<void> _renameCookie(WebUri url, Cookie cookie, String newName) async {
    final updateCookie = await widget.cookies.getCookie(
      url: url,
      name: cookie.name,
    );
    await widget.cookies.deleteCookie(url: url, name: cookie.name);
    await widget.cookies.setCookie(
      CookieSetRequest(
        url: url,
        name: newName,
        value: updateCookie?.value ?? "",
      ),
    );
  }

  DataCell _buildCookieValueCell(WebUri url, Cookie cookie, int index) {
    return buildEditableStorageDataCell(
      EditableStorageDataCellConfig(
        width: widget.constraints.maxWidth / 3,
        onFieldSubmitted: (newValue) => widget.cookies.setCookie(
          CookieSetRequest(
            url: url,
            name: cookie.name,
            value: newValue,
          ),
        ),
        initialValue: cookie.value,
        index: index,
        trackingEditStatus: _cookieValueTrackingEdit,
        onRefresh: () => setState(() {}),
      ),
    );
  }

  DataCell _buildDeleteCookieCell(WebUri url, Cookie cookie) => DataCell(
        IconButton(
          icon: const Icon(Icons.cancel),
          onPressed: () async {
            await widget.cookies.deleteCookie(url: url, name: cookie.name);
            setState(() {});
          },
        ),
      );

  Widget _buildNewCookieForm(BuildContext context, WebUri url) {
    return Form(
      key: _newCookieFormKey,
      child: Container(
        padding: const EdgeInsets.all(10.0),
        child: Column(
          children: <Widget>[
            _buildCookieTextFields(),
            _buildCookiePathFields(),
            _buildCookieOptionFields(context),
            _buildAddCookieButton(context, url),
          ],
        ),
      ),
    );
  }

  Widget _buildCookieTextFields() => Row(
        children: <Widget>[
          _newCookieField(
            controller: _newCookieNameController,
            label: "Cookie Name",
            required: true,
            padded: true,
          ),
          _newCookieField(
            controller: _newCookieValueController,
            label: "Cookie Value",
            required: true,
          ),
        ],
      );

  Widget _buildCookiePathFields() => Row(
        children: <Widget>[
          _newCookieField(
            controller: _newCookieDomainController,
            label: "Cookie Domain",
            padded: true,
          ),
          _newCookieField(
            controller: _newCookiePathController,
            label: "Cookie Path",
            required: true,
          ),
        ],
      );

  Widget _newCookieField({
    required TextEditingController controller,
    required String label,
    bool required = false,
    bool padded = false,
  }) {
    final field = TextFormField(
      controller: controller,
      decoration: InputDecoration(labelText: label),
      validator: required ? requiredStorageText : null,
    );
    return Expanded(
      child: padded
          ? Container(
              padding: const EdgeInsets.only(right: 10.0),
              child: field,
            )
          : field,
    );
  }

  Widget _buildCookieOptionFields(BuildContext context) => Row(
        children: <Widget>[
          Expanded(child: _buildExpirySelector(context)),
          Expanded(
            child: CheckboxListTile(
              title: const Text("Is Secure?"),
              value: _newCookieIsSecure,
              onChanged: (newValue) {
                setState(() {
                  _newCookieIsSecure = newValue!;
                });
              },
            ),
          ),
        ],
      );

  Widget _buildExpirySelector(BuildContext context) => Row(
        children: <Widget>[
          Expanded(
            child: ListTile(
              title: const Text("Expires in:"),
              subtitle: Text(_expiryLabel()),
              onTap: () => _selectExpiryDate(context),
            ),
          ),
          Center(
            child: IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                setState(() {
                  _newCookieExpiresDate = null;
                });
              },
            ),
          ),
        ],
      );

  String _expiryLabel() {
    return _newCookieExpiresDate != null
        ? _newCookieExpiresDate!.toIso8601String()
        : "Select a date ...";
  }

  Future<void> _selectExpiryDate(BuildContext context) async {
    FocusScope.of(context).unfocus();
    _newCookieExpiresDate = await showDatePicker(
      context: context,
      initialDate: _newCookieExpiresDate,
      firstDate: DateTime.now(),
      lastDate: DateTime(9999),
    );
    setState(() {});
  }

  Widget _buildAddCookieButton(BuildContext context, WebUri url) => SizedBox(
        width: MediaQuery.of(context).size.width,
        child: TextButton(
          child: const Text("Add Cookie"),
          onPressed: () => _addCookie(url),
        ),
      );

  Future<void> _addCookie(WebUri url) async {
    final form = _newCookieFormKey.currentState;
    if (form == null || !form.validate()) return;

    await widget.cookies.setCookie(
      CookieSetRequest(
        url: url,
        name: _newCookieNameController.text,
        value: _newCookieValueController.text,
        domain: _newCookieDomainController.text.isEmpty
            ? null
            : _newCookieDomainController.text,
        isSecure: _newCookieIsSecure,
        path: _newCookiePathController.text,
        expiresDate: _newCookieExpiresDate?.millisecondsSinceEpoch,
      ),
    );

    setState(form.reset);
  }
}

class _CookieHeader extends StatelessWidget {
  const _CookieHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16.0),
      );
}
