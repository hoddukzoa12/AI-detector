import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infocutter_app/infocutter/content_blocker_factory.dart';
import 'package:infocutter_app/infocutter/models.dart';
import 'package:infocutter_app/infocutter/url_matcher.dart';

void main() {
  const factory = ContentBlockerFactory();

  group('matcherToDomain', () {
    test('https 매처에서 host 만 추출', () {
      expect(matcherToDomain('https://example.com/*'), 'example.com');
    });

    test('와일드카드 scheme 매처', () {
      expect(matcherToDomain('*://*.example.com/*'), '*.example.com');
    });

    test('http 매처', () {
      expect(matcherToDomain('http://news.example.com/path/*'),
          'news.example.com');
    });

    test('잘못된 형식은 그대로 반환 (호출자가 urlFilter 로 우회)', () {
      expect(matcherToDomain('invalid'), 'invalid');
      expect(matcherToDomain(''), '');
    });
  });

  group('matcherToUrlFilter / matchesUrl', () {
    test('path scoped matcher keeps path scope', () {
      final matcher = 'https://example.com/news/*';
      expect(
          matchesUrl(matcher, Uri.parse('https://example.com/news/1')), isTrue);
      expect(
          matchesUrl(matcher, Uri.parse('https://example.com/mail')), isFalse);
      expect(matcherToUrlFilter(matcher), contains('/news/.*'));
    });

    test('wildcard scheme matches http and https', () {
      final matcher = '*://example.com/*';
      expect(matchesUrl(matcher, Uri.parse('https://example.com/a')), isTrue);
      expect(matchesUrl(matcher, Uri.parse('http://example.com/a')), isTrue);
      expect(matchesUrl(matcher, Uri.parse('ftp://example.com/a')), isFalse);
    });
  });

  group('ContentBlockerFactory.buildAll', () {
    test('globalEnabled = false 면 빈 리스트', () {
      final snap = RuleStoreSnapshot(
        globalEnabled: false,
        profiles: [
          _profileWithHideRule('https://example.com/*', '.ad'),
        ],
      );
      expect(factory.buildAll(snap), isEmpty);
    });

    test('비활성 프로필은 무시', () {
      final snap = RuleStoreSnapshot(
        globalEnabled: true,
        profiles: [
          _profileWithHideRule('https://example.com/*', '.ad', enabled: false),
        ],
      );
      expect(factory.buildAll(snap), isEmpty);
    });

    test('hide 룰만 있으면 CSS_DISPLAY_NONE blocker 1개', () {
      final snap = RuleStoreSnapshot(
        globalEnabled: true,
        profiles: [
          _profileWithHideRule('https://example.com/*', '.ad, #promo'),
        ],
      );
      final blockers = factory.buildAll(snap);
      expect(blockers, hasLength(1));
      final b = blockers.first;
      expect(b.action.type, ContentBlockerActionType.CSS_DISPLAY_NONE);
      expect(b.action.selector, contains('.ad'));
      expect(b.trigger.urlFilter, r'^https://example\.com(:[0-9]+)?/.*$');
      expect(b.trigger.urlFilter, isNot(contains('?:')));
      expect(b.trigger.urlFilter, isNot(contains(r'\d')));
    });

    test('path scoped matcher is preserved in ContentBlocker urlFilter', () {
      final blockers = factory.buildAll(RuleStoreSnapshot(
        globalEnabled: true,
        profiles: [
          _profileWithHideRule('https://example.com/news/*', '.ad'),
        ],
      ));
      expect(blockers, hasLength(1));
      expect(blockers.first.trigger.urlFilter, contains('/news/.*'));
    });

    test('hide + unhide 룰은 hide selector 에 :not(unhide) 로 합성', () {
      final profile = RuleProfile(
        id: 'p1',
        name: 'Example',
        enabled: true,
        matchers: const ['https://example.com/*'],
        cards: [
          ProfileCard(
            id: 'c1',
            name: 'Ads',
            enabled: true,
            createdAt: DateTime.utc(2026),
            updatedAt: DateTime.utc(2026),
          ),
        ],
        rules: [
          StoredRule(
            cardId: 'c1',
            cardName: 'Ads',
            selector: '.ad',
            mode: RuleMode.hide,
            createdAt: DateTime.utc(2026),
          ),
          StoredRule(
            cardId: 'c1',
            cardName: 'Ads',
            selector: '#keep-me',
            mode: RuleMode.unhide,
            createdAt: DateTime.utc(2026),
          ),
        ],
        updatedAt: DateTime.utc(2026),
      );
      final blockers = factory.buildAll(RuleStoreSnapshot(
        globalEnabled: true,
        profiles: [profile],
      ));
      expect(blockers, hasLength(1));
      expect(blockers.first.action.type,
          ContentBlockerActionType.CSS_DISPLAY_NONE);
      expect(blockers.first.action.selector, '.ad:not(#keep-me)');
    });

    test('여러 unhide 는 CSS4 목록이 아니라 :not() 체인으로 합성', () {
      final profile = RuleProfile(
        id: 'p1',
        name: 'Example',
        enabled: true,
        matchers: const ['https://example.com/*'],
        cards: [
          ProfileCard(
            id: 'c1',
            name: 'Ads',
            enabled: true,
            createdAt: DateTime.utc(2026),
            updatedAt: DateTime.utc(2026),
          ),
        ],
        rules: [
          StoredRule(
            cardId: 'c1',
            cardName: 'Ads',
            selector: '.ad',
            mode: RuleMode.hide,
            createdAt: DateTime.utc(2026),
          ),
          StoredRule(
            cardId: 'c1',
            cardName: 'Ads',
            selector: '#keep-me',
            mode: RuleMode.unhide,
            createdAt: DateTime.utc(2026),
          ),
          StoredRule(
            cardId: 'c1',
            cardName: 'Ads',
            selector: '.keep2',
            mode: RuleMode.unhide,
            createdAt: DateTime.utc(2026),
          ),
        ],
        updatedAt: DateTime.utc(2026),
      );
      final blockers = factory.buildAll(RuleStoreSnapshot(
        globalEnabled: true,
        profiles: [profile],
      ));
      // CSS3-compatible chain, not the CSS4 selector-list `:not(#keep-me, .keep2)`.
      expect(blockers.first.action.selector, '.ad:not(#keep-me):not(.keep2)');
    });

    test('hide 만 있으면 :not() 없이 단순 join', () {
      final profile = RuleProfile(
        id: 'p1',
        name: 'Example',
        enabled: true,
        matchers: const ['https://example.com/*'],
        cards: [
          ProfileCard(
            id: 'c1',
            name: 'Ads',
            enabled: true,
            createdAt: DateTime.utc(2026),
            updatedAt: DateTime.utc(2026),
          ),
        ],
        rules: [
          StoredRule(
            cardId: 'c1',
            cardName: 'Ads',
            selector: '.ad',
            mode: RuleMode.hide,
            createdAt: DateTime.utc(2026),
          ),
          StoredRule(
            cardId: 'c1',
            cardName: 'Ads',
            selector: '#promo',
            mode: RuleMode.hide,
            createdAt: DateTime.utc(2026),
          ),
        ],
        updatedAt: DateTime.utc(2026),
      );
      final blockers = factory.buildAll(RuleStoreSnapshot(
        globalEnabled: true,
        profiles: [profile],
      ));
      expect(blockers.first.action.selector, '.ad, #promo');
    });

    test('카드가 disabled 이면 그 카드의 룰만 제외', () {
      final profile = RuleProfile(
        id: 'p1',
        name: 'Example',
        enabled: true,
        matchers: const ['https://example.com/*'],
        cards: [
          ProfileCard(
            id: 'c1',
            name: 'Ads',
            enabled: false,
            createdAt: DateTime.utc(2026),
            updatedAt: DateTime.utc(2026),
          ),
          ProfileCard(
            id: 'c2',
            name: 'Other',
            enabled: true,
            createdAt: DateTime.utc(2026),
            updatedAt: DateTime.utc(2026),
          ),
        ],
        rules: [
          StoredRule(
            cardId: 'c1',
            cardName: 'Ads',
            selector: '.ad',
            mode: RuleMode.hide,
            createdAt: DateTime.utc(2026),
          ),
          StoredRule(
            cardId: 'c2',
            cardName: 'Other',
            selector: '.promo',
            mode: RuleMode.hide,
            createdAt: DateTime.utc(2026),
          ),
        ],
        updatedAt: DateTime.utc(2026),
      );
      final blockers = factory.buildAll(RuleStoreSnapshot(
        globalEnabled: true,
        profiles: [profile],
      ));
      expect(blockers, hasLength(1));
      expect(blockers.first.action.selector, '.promo');
    });

    test('matchers 가 비어있으면 blocker 생성 안 함', () {
      final profile = RuleProfile(
        id: 'p1',
        name: 'Example',
        enabled: true,
        matchers: const [],
        cards: [
          ProfileCard(
            id: 'c1',
            name: 'Ads',
            enabled: true,
            createdAt: DateTime.utc(2026),
            updatedAt: DateTime.utc(2026),
          ),
        ],
        rules: [
          StoredRule(
            cardId: 'c1',
            cardName: 'Ads',
            selector: '.ad',
            mode: RuleMode.hide,
            createdAt: DateTime.utc(2026),
          ),
        ],
        updatedAt: DateTime.utc(2026),
      );
      expect(
        factory.buildAll(RuleStoreSnapshot(
          globalEnabled: true,
          profiles: [profile],
        )),
        isEmpty,
      );
    });

    test('iframe scoped rules are skipped until scoped runtime is available',
        () {
      final profile = RuleProfile(
        id: 'p1',
        name: 'Example',
        enabled: true,
        matchers: const ['https://example.com/*'],
        cards: [
          ProfileCard(
            id: 'c1',
            name: 'Ads',
            enabled: true,
            createdAt: DateTime.utc(2026),
            updatedAt: DateTime.utc(2026),
          ),
        ],
        rules: [
          StoredRule(
            cardId: 'c1',
            cardName: 'Ads',
            selector: '.iframe-ad',
            mode: RuleMode.hide,
            frameScope: 'https://frame.example/*',
            createdAt: DateTime.utc(2026),
          ),
        ],
        updatedAt: DateTime.utc(2026),
      );

      expect(
        factory.buildAll(RuleStoreSnapshot(
          globalEnabled: true,
          profiles: [profile],
        )),
        isEmpty,
      );
    });
  });
}

RuleProfile _profileWithHideRule(
  String matcher,
  String selector, {
  bool enabled = true,
}) {
  return RuleProfile(
    id: 'p1',
    name: 'Example',
    enabled: enabled,
    matchers: [matcher],
    cards: [
      ProfileCard(
        id: 'c1',
        name: 'Ads',
        enabled: true,
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      ),
    ],
    rules: [
      StoredRule(
        cardId: 'c1',
        cardName: 'Ads',
        selector: selector,
        mode: RuleMode.hide,
        createdAt: DateTime.utc(2026),
      ),
    ],
    updatedAt: DateTime.utc(2026),
  );
}
