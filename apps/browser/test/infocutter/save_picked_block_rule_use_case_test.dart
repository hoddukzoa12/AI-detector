import 'package:flutter_test/flutter_test.dart';
import 'package:infocutter_app/infocutter/application/block_rules/picked_block_rule_writer.dart';
import 'package:infocutter_app/infocutter/application/block_rules/save_picked_block_rule_use_case.dart';
import 'package:infocutter_app/infocutter/models.dart';

void main() {
  test('normalizes selector, card name, and frame scope before saving',
      () async {
    final repository = _FakePickedBlockRuleWriter();
    final useCase = SavePickedBlockRuleUseCase(repository);

    final rule = await useCase(
      SavePickedBlockRuleCommand(
        url: Uri.parse('https://example.com/news/1'),
        selector: '  article.card  ',
        cardName: '  Ads  ',
        frameScope: '  https://frame.example/news  ',
      ),
    );

    expect(rule.selector, 'article.card');
    expect(repository.lastSelector, 'article.card');
    expect(repository.lastCardName, 'Ads');
    expect(repository.lastFrameScope, 'https://frame.example/news');
  });

  test('uses host as fallback card name', () async {
    final repository = _FakePickedBlockRuleWriter();
    final useCase = SavePickedBlockRuleUseCase(repository);

    await useCase(
      SavePickedBlockRuleCommand(
        url: Uri.parse('https://example.com/news/1'),
        selector: '.ad',
        cardName: '   ',
      ),
    );

    expect(repository.lastCardName, 'example.com');
  });

  test('rejects URL without host and empty selector', () async {
    final useCase = SavePickedBlockRuleUseCase(_FakePickedBlockRuleWriter());

    expect(
      () => useCase(
        SavePickedBlockRuleCommand(
          url: Uri.parse('about:blank'),
          selector: '.ad',
          cardName: 'Ads',
        ),
      ),
      throwsArgumentError,
    );
    expect(
      () => useCase(
        SavePickedBlockRuleCommand(
          url: Uri.parse('https://example.com/news/1'),
          selector: '   ',
          cardName: 'Ads',
        ),
      ),
      throwsArgumentError,
    );
  });
}

class _FakePickedBlockRuleWriter implements PickedBlockRuleWriter {
  Uri? lastUrl;
  String? lastSelector;
  String? lastCardName;
  String? lastFrameScope;

  @override
  Future<StoredRule> addPickedRuleForUrl({
    required Uri url,
    required String selector,
    String cardName = 'Picked elements',
    String? frameScope,
  }) async {
    lastUrl = url;
    lastSelector = selector;
    lastCardName = cardName;
    lastFrameScope = frameScope;
    return StoredRule(
      cardId: 'card-1',
      cardName: cardName,
      selector: selector,
      mode: RuleMode.hide,
      frameScope: frameScope,
      createdAt: DateTime.utc(2026),
    );
  }
}
