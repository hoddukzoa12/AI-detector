import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:infocutter_app/models/webview_model.dart';
import 'package:infocutter_app/models/window_model_codec.dart';
import 'package:infocutter_app/services/browser_persistence.dart';
import 'package:uuid/uuid.dart';
import 'package:collection/collection.dart';

import '../util.dart';

part 'window_model_persistence.dart';

class WindowModel extends ChangeNotifier {
  String _id;
  String _name = '';
  DateTime _updatedTime;
  final DateTime _createdTime;
  final List<WebViewModel> _webViewModels = [];
  int _currentTabIndex = -1;
  late WebViewModel _currentWebViewModel;
  bool _shouldSave = false;
  bool _showTabScroller = false;

  bool get showTabScroller => _showTabScroller;

  set showTabScroller(bool value) {
    if (value != _showTabScroller) {
      _showTabScroller = value;
      notifyListeners();
    }
  }

  bool get shouldSave => _shouldSave;

  set shouldSave(bool value) {
    _shouldSave = value;
    if (_shouldSave) {
      saveInfo();
    } else {
      removeInfo();
    }
    notifyListeners();
  }

  DateTime get createdTime => _createdTime;

  DateTime get updatedTime => _updatedTime;

  WindowModel(
      {String? id,
      String? name,
      bool? shouldSave,
      DateTime? updatedTime,
      DateTime? createdTime,
      WindowPersistence? persistence})
      : _id = id ?? 'window_${const Uuid().v4()}',
        _name = name ?? '',
        _shouldSave = Util.isMobile() ? true : (shouldSave ?? false),
        _createdTime = createdTime ?? DateTime.now(),
        _updatedTime = updatedTime ?? DateTime.now(),
        _persistence = persistence {
    _currentWebViewModel = WebViewModel();
  }

  final WindowPersistence? _persistence;

  String get id => _id;

  UnmodifiableListView<WebViewModel> get webViewModels =>
      UnmodifiableListView(_webViewModels);

  WebViewModel get currentWebViewModelSnapshot => _currentWebViewModel;

  String get name => _name;

  set name(String value) {
    _name = value;

    notifyListeners();
  }

  void addTab(WebViewModel webViewModel) {
    _webViewModels.add(webViewModel);
    _currentTabIndex = _webViewModels.length - 1;
    webViewModel.tabIndex = _currentTabIndex;
    webViewModel.lastOpenedTime = DateTime.now();

    _currentWebViewModel.updateWithValue(webViewModel);

    notifyListeners();
  }

  void addTabs(List<WebViewModel> webViewModels) {
    for (var webViewModel in webViewModels) {
      _webViewModels.add(webViewModel);
      webViewModel.tabIndex = _webViewModels.length - 1;
    }
    _currentTabIndex = _webViewModels.length - 1;
    if (_currentTabIndex >= 0) {
      webViewModels.last.lastOpenedTime = DateTime.now();
      _currentWebViewModel.updateWithValue(webViewModels.last);
    }

    notifyListeners();
  }

  void closeTab(int index) {
    final webViewModel = _webViewModels[index];
    _webViewModels.removeAt(index);
    InAppWebViewController.disposeKeepAlive(webViewModel.keepAlive);

    if (Util.isMobile() || _currentTabIndex >= _webViewModels.length) {
      _currentTabIndex = _webViewModels.length - 1;
    }

    for (int i = index; i < _webViewModels.length; i++) {
      _webViewModels[i].tabIndex = i;
    }

    if (_currentTabIndex >= 0) {
      _currentWebViewModel.updateWithValue(_webViewModels[_currentTabIndex]);
    } else {
      _currentWebViewModel.updateWithValue(WebViewModel());
    }

    notifyListeners();
  }

  void showTab(int index) {
    if (_currentTabIndex != index) {
      _currentTabIndex = index;
      final webViewModel = _webViewModels[_currentTabIndex];
      webViewModel.lastOpenedTime = DateTime.now();
      _currentWebViewModel.updateWithValue(webViewModel);

      notifyListeners();
    }
  }

  void closeAllTabs() {
    for (final webViewModel in _webViewModels) {
      InAppWebViewController.disposeKeepAlive(webViewModel.keepAlive);
    }
    _webViewModels.clear();
    _currentTabIndex = -1;
    _currentWebViewModel.updateWithValue(WebViewModel());

    notifyListeners();
  }

  int getCurrentTabIndex() {
    return _currentTabIndex;
  }

  WebViewModel? getCurrentWebViewModel() {
    return _currentTabIndex >= 0 ? _webViewModels[_currentTabIndex] : null;
  }

  void notifyCurrentTabUpdated() {
    notifyListeners();
  }

  void setCurrentWebViewModel(WebViewModel webViewModel) {
    _currentWebViewModel = webViewModel;
  }

  DateTime _lastTrySave = DateTime.now();
  Timer? _timerSave;

  static WindowModel fromMap(
    Map<String, dynamic> map, {
    WindowPersistence? persistence,
  }) {
    return WindowModelCodec.fromMap(map, persistence: persistence);
  }

  Map<String, dynamic> toMap() {
    return WindowModelCodec.toMap(this);
  }

  Map<String, dynamic> toJson() {
    return toMap();
  }

  @override
  String toString() {
    return toMap().toString();
  }
}
