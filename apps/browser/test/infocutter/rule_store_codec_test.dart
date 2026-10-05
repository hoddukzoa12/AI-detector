import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:infocutter_app/infocutter/models.dart';
import 'package:infocutter_app/infocutter/rule_store_codec.dart';

void main() {
  const codec = RuleStoreCodec();

  group('RuleStoreCodec.decode', () {
    test('null / 잘못된 입력 → empty snapshot', () {
      expect(codec.decode(null).profiles, isEmpty);
      expect(codec.decode('garbage').profiles, isEmpty);
      expect(codec.decode(42).profiles, isEmpty);
      expect(codec.decode(null).globalEnabled, isTrue);
    });

    test('settings 누락 시 globalEnabled 기본값 true', () {
      final snap = codec.decode(const <String, dynamic>{
        'version': 4,
        'profiles': [],
      });
      expect(snap.globalEnabled, isTrue);
    });

    test('settings.globalEnabled = false 가 그대로 보존', () {
      final snap = codec.decode(const <String, dynamic>{
        'version': 4,
        'settings': {'globalEnabled': false},
        'profiles': [],
      });
      expect(snap.globalEnabled, isFalse);
    });

    test('legacy rule (selector 문자열만) 도 정상 흡수', () {
      final snap = codec.decode(<String, dynamic>{
        'version': 4,
        'profiles': [
          {
            'id': 'p1',
            'name': 'Example',
            'enabled': true,
            'matchers': ['https://example.com/*'],
            'rules': ['.ad', '#promo'],
            'updatedAt': '2026-01-01T00:00:00Z',
          }
        ],
      });
      expect(snap.profiles, hasLength(1));
      expect(snap.profiles.first.rules, hasLength(2));
      expect(snap.profiles.first.rules.first.selector, '.ad');
      expect(snap.profiles.first.rules.first.mode, RuleMode.hide);
    });

    test('cards 누락 시 rules 에서 파생', () {
      final snap = codec.decode(<String, dynamic>{
        'version': 4,
        'profiles': [
          {
            'id': 'p1',
            'name': 'Example',
            'matchers': ['https://example.com/*'],
            'rules': [
              {
                'cardId': 'c1',
                'cardName': '기본 카드',
                'selector': '.ad',
                'mode': 'hide',
                'createdAt': '2026-01-01T00:00:00Z',
              }
            ],
            'updatedAt': '2026-01-01T00:00:00Z',
          }
        ],
      });
      expect(snap.profiles.first.cards, hasLength(1));
      expect(snap.profiles.first.cards.first.id, 'c1');
    });

    test('mode 가 unhide / 잘못된 값일 때 처리', () {
      final snap = codec.decode(<String, dynamic>{
        'version': 4,
        'profiles': [
          {
            'id': 'p1',
            'matchers': ['https://example.com/*'],
            'rules': [
              {'selector': 'a', 'mode': 'unhide'},
              {'selector': 'b', 'mode': 'bogus'},
              {'selector': 'c'},
            ],
            'updatedAt': '2026-01-01T00:00:00Z',
          }
        ],
      });
      expect(snap.profiles.first.rules[0].mode, RuleMode.unhide);
      expect(snap.profiles.first.rules[1].mode, RuleMode.hide);
      expect(snap.profiles.first.rules[2].mode, RuleMode.hide);
    });

    test('잘못된 timestamp 는 epoch 로 fallback', () {
      final snap = codec.decode(<String, dynamic>{
        'version': 4,
        'profiles': [
          {
            'id': 'p1',
            'matchers': ['https://example.com/*'],
            'rules': [
              {'selector': '.a', 'createdAt': 'not-a-date'}
            ],
            'updatedAt': null,
          }
        ],
      });
      expect(snap.profiles.first.updatedAt.millisecondsSinceEpoch, 0);
      expect(
          snap.profiles.first.rules.first.createdAt.millisecondsSinceEpoch, 0);
    });
  });

  group('RuleStoreCodec.encode → decode round-trip', () {
    test('일반 프로필이 round-trip 후 동일 핵심 필드', () {
      final original = RuleStoreSnapshot(
        globalEnabled: false,
        profiles: [
          RuleProfile(
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
                updatedAt: DateTime.utc(2026, 1, 2),
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
                selector: '#hero',
                mode: RuleMode.unhide,
                createdAt: DateTime.utc(2026, 1, 1, 12),
              ),
            ],
            updatedAt: DateTime.utc(2026, 1, 3),
          ),
        ],
      );
      final encoded = codec.encodeJson(original);
      // JSON 이 유효한지
      expect(() => jsonDecode(encoded), returnsNormally);

      final decoded = codec.decodeJson(encoded);
      expect(decoded.globalEnabled, isFalse);
      expect(decoded.profiles, hasLength(1));
      expect(decoded.profiles.first.matchers, ['https://example.com/*']);
      expect(decoded.profiles.first.rules, hasLength(2));
      expect(decoded.profiles.first.rules[0].mode, RuleMode.hide);
      expect(decoded.profiles.first.rules[1].mode, RuleMode.unhide);
    });

    test('chrome storage version 이 항상 4', () {
      const snap = RuleStoreSnapshot.empty;
      final encoded = codec.encode(snap);
      expect(encoded['version'], chromeStorageVersion);
      expect(chromeStorageVersion, 4);
    });
  });
}
