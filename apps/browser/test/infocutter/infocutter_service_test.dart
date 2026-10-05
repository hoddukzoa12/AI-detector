import 'package:flutter_test/flutter_test.dart';
import 'package:infocutter_app/infocutter/infocutter_service.dart';
import 'package:infocutter_app/infocutter/models.dart';
import 'package:infocutter_app/infocutter/storage.dart';
import 'package:infocutter_app/infocutter/template_catalog.dart';

class _MemoryStore implements InfocutterStore {
  String? raw;

  @override
  Future<String?> loadRuleStoreJson() async => raw;

  @override
  Future<void> saveRuleStoreJson(String raw) async {
    this.raw = raw;
  }
}

void main() {
  test('addPickedRuleForUrl creates a host profile and hide rule', () async {
    final store = _MemoryStore();
    final service = InfocutterService(store: store);

    final rule = await service.addPickedRuleForUrl(
      url: Uri.parse('https://example.com/articles/1'),
      selector: '.ad',
    );

    expect(rule.selector, '.ad');
    expect(service.profiles, hasLength(1));
    expect(service.profiles.first.name, 'example.com');
    expect(service.profiles.first.matchers, ['https://example.com/*']);
    expect(service.profiles.first.rules.single.selector, '.ad');
    expect(store.raw, isNotNull);
  });

  test('addPickedRuleForUrl reuses profile and skips duplicate rules',
      () async {
    final service = InfocutterService(store: _MemoryStore());

    await service.addPickedRuleForUrl(
      url: Uri.parse('https://example.com/first'),
      selector: '.ad',
    );
    await service.addPickedRuleForUrl(
      url: Uri.parse('https://example.com/second'),
      selector: ' .ad ',
    );

    expect(service.profiles, hasLength(1));
    expect(service.profiles.first.rules, hasLength(1));
    expect(
      service.buildContentBlockersForUrl(Uri.parse('https://example.com/next')),
      hasLength(1),
    );
  });

  test('addPickedRuleForUrl preserves iframe frameScope', () async {
    final service = InfocutterService(store: _MemoryStore());

    await service.addPickedRuleForUrl(
      url: Uri.parse('https://example.com/page'),
      selector: '.ad',
      frameScope: 'https://embed.example/frame',
    );
    await service.addPickedRuleForUrl(
      url: Uri.parse('https://example.com/page'),
      selector: '.ad',
    );

    expect(service.profiles.first.rules, hasLength(2));
    expect(service.profiles.first.rules.first.frameScope,
        'https://embed.example/frame');
    expect(service.profiles.first.rules.last.frameScope, isNull);
  });

  test('buildContentBlockersForUrl respects matcher path scope', () async {
    final service = InfocutterService(store: _MemoryStore());
    await service.upsertProfile(
      id: 'p1',
      name: 'News',
      matchers: ['https://example.com/news/*'],
    );
    await service.addRule(
      profileId: 'p1',
      cardName: 'Ads',
      selector: '.ad',
    );

    expect(
      service.buildContentBlockersForUrl(
        Uri.parse('https://example.com/news/1'),
      ),
      hasLength(1),
    );
    expect(
      service.buildContentBlockersForUrl(Uri.parse('https://example.com/mail')),
      isEmpty,
    );
  });

  test('buildActiveSiteState returns an empty state without a profile', () {
    final service = InfocutterService(store: _MemoryStore());

    final state = service.buildActiveSiteState(
      Uri.parse('https://example.com/news/1'),
    );

    expect(state.activeProfileId, isNull);
    expect(state.activeProfileName, isNull);
    expect(state.hostname, 'example.com');
    expect(state.globalEnabled, isTrue);
    expect(state.profileEnabled, isTrue);
    expect(state.matchers, isEmpty);
    expect(state.cards, isEmpty);
    expect(state.rules, isEmpty);
    expect(state.cardCount, 0);
    expect(state.selectorCount, 0);
    expect(state.enabledSelectorCount, 0);
    expect(state.exceptionCount, 0);
    expect(state.enabledExceptionCount, 0);
  });

  test('buildActiveSiteState groups rules by card and counts modes', () async {
    final service = InfocutterService(store: _MemoryStore());
    await service.upsertProfile(
      id: 'p1',
      name: 'Example',
      matchers: ['https://example.com/*'],
    );
    await service.addRule(
      profileId: 'p1',
      cardName: 'Ads',
      selector: '.ad',
    );
    await service.addRule(
      profileId: 'p1',
      cardName: 'Ads',
      selector: '#keep-me',
      mode: RuleMode.unhide,
    );

    final state = service.buildActiveSiteState(
      Uri.parse('https://example.com/article'),
    );

    expect(state.activeProfileId, 'p1');
    expect(state.activeProfileName, 'Example');
    expect(state.matchers, ['https://example.com/*']);
    expect(state.profileEnabled, isTrue);
    expect(state.cardCount, 1);
    expect(state.cards.single.cardName, 'Ads');
    expect(state.cards.single.ruleCount, 2);
    expect(state.cards.single.frameScopes, [null]);
    expect(state.selectorCount, 2);
    expect(state.enabledSelectorCount, 1);
    expect(state.exceptionCount, 1);
    expect(state.enabledExceptionCount, 1);
  });

  test('buildRuntimeStateForUrl returns enabled matching rules only', () async {
    final service = InfocutterService(store: _MemoryStore());
    await service.upsertProfile(
      id: 'p1',
      name: 'Example',
      matchers: ['https://example.com/*'],
    );
    final firstRule = await service.addRule(
      profileId: 'p1',
      cardName: 'Ads',
      selector: '.ad',
    );
    await service.addRule(
      profileId: 'p1',
      cardName: 'Ads',
      selector: '#keep-me',
      mode: RuleMode.unhide,
      frameScope: 'https://example.com/frame',
    );
    await service.addRule(
      profileId: 'p1',
      cardName: 'Muted',
      selector: '.muted',
    );
    final mutedRule = service.profiles.first.rules.last;
    await service.setCardEnabled(
      profileId: 'p1',
      cardId: mutedRule.cardId,
      enabled: false,
    );

    final state = service.buildRuntimeStateForUrl(
      Uri.parse('https://example.com/article'),
    );

    expect(state['version'], 1);
    expect(state['globalEnabled'], isTrue);
    expect(state['profileEnabled'], isTrue);
    expect(state['activeProfileId'], 'p1');
    final rules = state['rules'] as List<Object?>;
    expect(rules, hasLength(2));
    expect(
      rules,
      containsAll([
        {
          'cardId': firstRule.cardId,
          'cardName': 'Ads',
          'selector': '.ad',
          'mode': 'hide',
          'frameScope': null,
          'createdAt': firstRule.createdAt.toUtc().toIso8601String(),
        },
        {
          'cardId': firstRule.cardId,
          'cardName': 'Ads',
          'selector': '#keep-me',
          'mode': 'unhide',
          'frameScope': 'https://example.com/frame',
          'createdAt': service.profiles.first.rules[1].createdAt
              .toUtc()
              .toIso8601String(),
        },
      ]),
    );
  });

  test(
      'buildActiveSiteState includes disabled cards but excludes enabled counts',
      () async {
    final service = InfocutterService(store: _MemoryStore());
    await service.importChromeJson('''
{
  "version": 4,
  "settings": {"globalEnabled": false},
  "profiles": [
    {
      "id": "p1",
      "name": "Example",
      "enabled": false,
      "matchers": ["https://example.com/*"],
      "cards": [
        {
          "id": "c1",
          "name": "Muted card",
          "enabled": false,
          "createdAt": "2026-01-01T00:00:00Z",
          "updatedAt": "2026-01-01T00:00:00Z"
        }
      ],
      "rules": [
        {
          "cardId": "c1",
          "cardName": "Muted card",
          "selector": ".ad",
          "mode": "hide",
          "createdAt": "2026-01-01T00:00:00Z"
        }
      ],
      "updatedAt": "2026-01-02T00:00:00Z"
    }
  ]
}
''');

    final state = service.buildActiveSiteState(
      Uri.parse('https://example.com/article'),
    );

    expect(state.globalEnabled, isFalse);
    expect(state.profileEnabled, isFalse);
    expect(state.cardCount, 1);
    expect(state.cards.single.enabled, isFalse);
    expect(state.selectorCount, 1);
    expect(state.enabledSelectorCount, 0);
    expect(state.updatedAt, DateTime.utc(2026, 1, 2));
  });

  test('profile management actions update active site state', () async {
    final service = InfocutterService(store: _MemoryStore());
    await service.upsertProfile(
      id: 'p1',
      name: 'Example',
      matchers: ['https://example.com/*'],
    );
    await service.upsertProfile(
      id: 'p2',
      name: 'Other',
      matchers: ['https://other.test/*'],
    );
    await service.addRule(
      profileId: 'p1',
      cardName: 'Ads',
      selector: '.ad',
    );

    await service.renameProfile('p1', 'Example renamed');
    await service.setProfileMatchers('p1', [
      ' https://example.com/news/* ',
      '',
    ]);
    await service.setProfileEnabled('p1', false);
    await service.moveProfile('p2', ProfileMoveDirection.up);

    expect(service.profiles.map((profile) => profile.id), ['p2', 'p1']);

    final state = service.buildActiveSiteState(
      Uri.parse('https://example.com/news/1'),
    );
    expect(state.activeProfileId, 'p1');
    expect(state.activeProfileName, 'Example renamed');
    expect(state.profileEnabled, isFalse);
    expect(state.matchers, ['https://example.com/news/*']);
    expect(state.selectorCount, 1);

    await service.clearProfileRules('p1');
    expect(
      service
          .buildActiveSiteState(Uri.parse('https://example.com/news/1'))
          .selectorCount,
      0,
    );
  });

  test('card and rule management actions update grouped cards', () async {
    final service = InfocutterService(store: _MemoryStore());
    await service.upsertProfile(
      id: 'p1',
      name: 'Example',
      matchers: ['https://example.com/*'],
    );
    final firstRule = await service.addRule(
      profileId: 'p1',
      cardName: 'Ads',
      selector: '.ad',
    );
    await service.addRule(
      profileId: 'p1',
      cardName: 'Ads',
      selector: '.promo',
    );

    await service.renameCard(
      profileId: 'p1',
      cardId: firstRule.cardId,
      cardName: 'Distractions',
    );
    expect(service.profiles.first.cards.single.name, 'Distractions');
    expect(
      service.profiles.first.rules.map((rule) => rule.cardName).toSet(),
      {'Distractions'},
    );

    await service.setCardEnabled(
      profileId: 'p1',
      cardId: firstRule.cardId,
      enabled: false,
    );
    var state = service.buildActiveSiteState(
      Uri.parse('https://example.com/article'),
    );
    expect(state.cards.single.enabled, isFalse);
    expect(state.selectorCount, 2);
    expect(state.enabledSelectorCount, 0);

    await service.setCardEnabled(
      profileId: 'p1',
      cardId: firstRule.cardId,
      enabled: true,
    );
    await service.updateRuleSelector(
      profileId: 'p1',
      targetRule: firstRule,
      selector: '.ad-banner',
    );
    expect(service.profiles.first.rules.first.selector, '.ad-banner');

    final updatedFirstRule = service.profiles.first.rules.first;
    await service.updateStoredRule(
      profileId: 'p1',
      targetRule: updatedFirstRule,
      mode: RuleMode.unhide,
      frameScope: 'https://frame.example/path',
    );
    expect(service.profiles.first.rules.first.mode, RuleMode.unhide);
    expect(
      service.profiles.first.rules.first.frameScope,
      'https://frame.example/path',
    );

    final scopedRule = service.profiles.first.rules.first;
    await service.removeStoredRule(
      profileId: 'p1',
      targetRule: scopedRule,
    );
    state = service.buildActiveSiteState(
      Uri.parse('https://example.com/article'),
    );
    expect(state.selectorCount, 1);
    expect(state.cards.single.ruleCount, 1);

    await service.removeCard(profileId: 'p1', cardId: firstRule.cardId);
    state = service.buildActiveSiteState(
      Uri.parse('https://example.com/article'),
    );
    expect(state.cardCount, 0);
    expect(state.selectorCount, 0);
  });

  test('importTemplate creates or replaces a template-backed profile',
      () async {
    final service = InfocutterService(store: _MemoryStore());
    final template = bundledInfocutterTemplates.first;

    final imported = await service.importTemplate(template);

    expect(imported.id, 'template-naver-home-ads-basic');
    expect(imported.sourceTemplateSlug, template.slug);
    expect(imported.matchers, ['https://www.naver.com/*']);
    expect(imported.cards, hasLength(2));
    expect(imported.rules, hasLength(7));

    await service.importTemplate(template);
    expect(
      service.profiles
          .where((profile) => profile.sourceTemplateSlug == template.slug),
      hasLength(1),
    );
  });
}
