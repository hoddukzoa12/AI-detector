import 'models.dart';

class InfocutterTemplateRule {
  const InfocutterTemplateRule({
    required this.selector,
    this.frameScope,
  });

  final String selector;
  final String? frameScope;
}

class InfocutterTemplateCard {
  const InfocutterTemplateCard({
    required this.id,
    required this.name,
    required this.enabled,
    required this.rules,
    this.note,
  });

  final String id;
  final String name;
  final bool enabled;
  final List<InfocutterTemplateRule> rules;
  final String? note;
}

class InfocutterTemplate {
  const InfocutterTemplate({
    required this.slug,
    required this.name,
    required this.description,
    required this.matchers,
    required this.cards,
  });

  final String slug;
  final String name;
  final String description;
  final List<String> matchers;
  final List<InfocutterTemplateCard> cards;

  String get profileId => 'template-$slug';

  RuleProfile toRuleProfile(DateTime now) {
    final profileCards = cards
        .map(
          (card) => ProfileCard(
            id: _cardId(card.id),
            name: card.name,
            enabled: card.enabled,
            createdAt: now,
            updatedAt: now,
          ),
        )
        .toList();

    final rules = <StoredRule>[];
    for (final card in cards) {
      for (final rule in card.rules) {
        rules.add(
          StoredRule(
            cardId: _cardId(card.id),
            cardName: card.name,
            selector: rule.selector,
            mode: RuleMode.hide,
            frameScope: rule.frameScope,
            createdAt: now,
          ),
        );
      }
    }

    return RuleProfile(
      id: profileId,
      name: name,
      enabled: true,
      matchers: matchers,
      cards: profileCards,
      rules: rules,
      sourceTemplateSlug: slug,
      updatedAt: now,
    );
  }

  String _cardId(String cardId) => 'template-$slug-$cardId';
}

const bundledInfocutterTemplates = <InfocutterTemplate>[
  InfocutterTemplate(
    slug: 'naver-home-ads-basic',
    name: '네이버 홈 광고 기본',
    description: '네이버 메인 우측/상단 광고 iframe과 배너 영역을 기본적으로 숨깁니다.',
    matchers: ['https://www.naver.com/*'],
    cards: [
      InfocutterTemplateCard(
        id: 'naver-top-ad',
        name: '상단 메인 광고',
        enabled: true,
        note: '타임보드와 상단 대형 광고 영역',
        rules: [
          InfocutterTemplateRule(selector: '#ad_timeboard'),
          InfocutterTemplateRule(selector: '#ad_timeboard_tgtLREC'),
        ],
      ),
      InfocutterTemplateCard(
        id: 'naver-right-ads',
        name: '우측 광고 블록',
        enabled: true,
        note: '로그인 영역 아래 우측 광고 블록과 하단 광고 슬롯',
        rules: [
          InfocutterTemplateRule(selector: '#right-ad-1'),
          InfocutterTemplateRule(selector: '#right-ad-1_tgtLREC'),
          InfocutterTemplateRule(
            selector: '#pc-main-ad-div-p_main_rightside_understock',
          ),
          InfocutterTemplateRule(
            selector: '#pc-main-ad-div-p_main_rightbottom_widget',
          ),
          InfocutterTemplateRule(
            selector: '#pc-main-ad-div-p_main_rightbottom_widget_tgtLREC',
          ),
        ],
      ),
    ],
  ),
  InfocutterTemplate(
    slug: 'naver-home-feed-ads',
    name: '네이버 홈 피드 광고',
    description: '네이버 홈 추천 피드 안의 광고성 영역을 한 번에 관리하기 위한 템플릿입니다.',
    matchers: ['https://www.naver.com/*'],
    cards: [
      InfocutterTemplateCard(
        id: 'naver-feed-ads',
        name: '추천 피드 광고',
        enabled: true,
        note: '추천 피드 안의 AD 카드 묶음',
        rules: [
          InfocutterTemplateRule(selector: '.feed_area'),
        ],
      ),
    ],
  ),
];
