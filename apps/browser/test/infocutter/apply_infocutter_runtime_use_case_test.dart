import 'package:flutter_test/flutter_test.dart';
import 'package:infocutter_app/infocutter/application/runtime/apply_infocutter_runtime_use_case.dart';
import 'package:infocutter_app/infocutter/application/runtime/infocutter_runtime_page.dart';
import 'package:infocutter_app/infocutter/infocutter_runtime_contracts.dart';

void main() {
  test('applies runtime state without injecting when the runtime exists',
      () async {
    final page = _FakeRuntimePage(['ok']);
    const useCase = ApplyInfocutterRuntimeUseCase(
      runtimeObjectName: infocutterBlockRuntimeObjectName,
      runtimeUserScriptSource: 'RUNTIME_SCRIPT',
    );

    final result = await useCase(
      ApplyInfocutterRuntimeCommand(
        page: page,
        state: const {
          'globalEnabled': true,
          'profileEnabled': true,
          'rules': [
            {'selector': '.ad', 'mode': 'hide'},
          ],
        },
      ),
    );

    expect(result, ApplyInfocutterRuntimeResult.applied);
    expect(page.sources, hasLength(1));
    expect(
      page.sources.single,
      contains('window.$infocutterBlockRuntimeObjectName'),
    );
    expect(page.sources.single, contains('"selector":".ad"'));
    expect(page.sources.single, isNot(contains('RUNTIME_SCRIPT')));
  });

  test('injects the runtime script and retries when the runtime is missing',
      () async {
    final page = _FakeRuntimePage(['missing', 'ok']);
    const useCase = ApplyInfocutterRuntimeUseCase(
      runtimeObjectName: infocutterBlockRuntimeObjectName,
      runtimeUserScriptSource: 'RUNTIME_SCRIPT',
    );

    final result = await useCase(
      ApplyInfocutterRuntimeCommand(
        page: page,
        state: const {
          'globalEnabled': true,
          'profileEnabled': true,
          'rules': [
            {'selector': '.ad', 'mode': 'hide'},
          ],
        },
      ),
    );

    expect(result, ApplyInfocutterRuntimeResult.injectedAndApplied);
    expect(page.sources, hasLength(3));
    expect(
      page.sources[0],
      contains('window.$infocutterBlockRuntimeObjectName'),
    );
    expect(page.sources[1], 'RUNTIME_SCRIPT');
    expect(
      page.sources[2],
      contains('window.$infocutterBlockRuntimeObjectName'),
    );
    expect(page.sources[2], contains('"selector":".ad"'));
  });

  test('uses the configured runtime object name', () async {
    final page = _FakeRuntimePage(['missing', 'ok']);
    const useCase = ApplyInfocutterRuntimeUseCase(
      runtimeObjectName: infocutterTextBlockRuntimeObjectName,
      runtimeUserScriptSource: 'TEXT_BLOCK_SCRIPT',
    );

    await useCase(
      ApplyInfocutterRuntimeCommand(
        page: page,
        state: const {
          'globalEnabled': true,
          'profileEnabled': true,
          'rules': [
            {'keyword': 'sponsor'},
          ],
        },
      ),
    );

    expect(
      page.sources[0],
      contains('window.$infocutterTextBlockRuntimeObjectName'),
    );
    expect(page.sources[1], 'TEXT_BLOCK_SCRIPT');
    expect(
      page.sources[2],
      contains('window.$infocutterTextBlockRuntimeObjectName'),
    );
    expect(page.sources[2], contains('"keyword":"sponsor"'));
  });
}

class _FakeRuntimePage implements InfocutterRuntimePage {
  _FakeRuntimePage(this._results);

  final List<Object?> _results;
  final List<String> sources = [];
  int _callCount = 0;

  @override
  Future<Object?> evaluateJavascript(String source) async {
    sources.add(source);
    final result = _callCount < _results.length ? _results[_callCount] : null;
    _callCount += 1;
    return result;
  }
}
