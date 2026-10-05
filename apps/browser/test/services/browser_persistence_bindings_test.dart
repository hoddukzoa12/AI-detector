import 'package:flutter_test/flutter_test.dart';
import 'package:infocutter_app/models/browser_model.dart';
import 'package:infocutter_app/models/webview_model.dart';
import 'package:infocutter_app/models/window_model.dart';
import 'package:infocutter_app/services/browser_persistence_bindings.dart';

void main() {
  test('bind is idempotent and dispose detaches without throwing', () {
    final browser = BrowserModel();
    final window = WindowModel();
    final tab1 = WebViewModel();
    final tab2 = WebViewModel();
    final bindings = BrowserPersistenceBindings();

    bindings.bind(browser: browser, window: window);
    bindings.bind(browser: browser, window: window);
    bindings.bindCurrentTab(tab1);
    bindings.bindCurrentTab(tab1);
    bindings.bindCurrentTab(tab2);

    // notify while attached must not throw
    browser.notifyListeners();
    window.notifyListeners();
    tab1.notifyListeners();
    tab2.notifyListeners();

    bindings.dispose();

    // post-dispose notify is safe (no stacked listeners left behind)
    browser.notifyListeners();
    window.notifyListeners();
    tab1.notifyListeners();
    tab2.notifyListeners();
  });
}
