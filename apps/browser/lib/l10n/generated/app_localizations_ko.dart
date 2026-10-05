// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String get appTitle => '인포커터';

  @override
  String get searchOrTypeWebAddress => '검색어나 웹 주소를 입력하세요';

  @override
  String get findOnPageHint => '페이지에서 찾기...';

  @override
  String get openWebPageFirst => '먼저 웹페이지를 열어주세요';

  @override
  String pickerActiveOnHost(String host) {
    return '$host에서 선택 모드가 켜졌습니다';
  }

  @override
  String hiddenSelectorOnHost(String selector, String host) {
    return '$host에서 $selector를 숨겼습니다';
  }

  @override
  String savedOffline(String url) {
    return '$url을 오프라인에 저장했습니다.';
  }

  @override
  String get unableToSave => '저장할 수 없습니다.';

  @override
  String get share => '공유';

  @override
  String get login => '로그인';

  @override
  String get username => '사용자 이름';

  @override
  String get password => '비밀번호';

  @override
  String get cancel => '취소';

  @override
  String get ok => '확인';

  @override
  String get openNewWindow => '새 창 열기';

  @override
  String get saveWindow => '창 저장';

  @override
  String get savedWindows => '저장된 창';

  @override
  String get newTab => '새 탭';

  @override
  String get newIncognitoTab => '새 시크릿 탭';

  @override
  String get favorites => '즐겨찾기';

  @override
  String get history => '방문 기록';

  @override
  String get webArchives => '웹 아카이브';

  @override
  String get findOnPage => '페이지에서 찾기';

  @override
  String get desktopMode => '데스크톱 모드';

  @override
  String get settings => '설정';

  @override
  String get developers => '개발자 도구';

  @override
  String get inAppWebViewProject => 'InAppWebView 프로젝트';

  @override
  String get closeTabs => '탭 닫기';

  @override
  String get closeAllTabs => '모든 탭 닫기';

  @override
  String get linkPreview => '링크 미리보기';

  @override
  String get openInNewTab => '새 탭에서 열기';

  @override
  String get openInNewIncognitoTab => '새 시크릿 탭에서 열기';

  @override
  String get copyAddressLink => '링크 주소 복사';

  @override
  String get shareLink => '링크 공유';

  @override
  String get downloadImage => '이미지 다운로드';

  @override
  String get shareImage => '이미지 공유';

  @override
  String get imageInNewTab => '이미지를 새 탭에서 열기';

  @override
  String get searchImageOnGoogle => 'Google에서 이미지 검색';

  @override
  String get generalSettings => '일반 설정';

  @override
  String get themeMode => '테마 모드';

  @override
  String get themeModeSystem => '시스템 설정 따르기';

  @override
  String get themeModeLight => '라이트';

  @override
  String get themeModeDark => '다크';

  @override
  String get searchEngine => '검색 엔진';

  @override
  String get defaultSite => '기본 사이트';

  @override
  String get homePage => '홈 페이지';

  @override
  String get on => '켜짐';

  @override
  String get off => '꺼짐';

  @override
  String get customUrlHomePage => '직접 입력한 홈 페이지 URL';

  @override
  String get defaultUserAgent => '기본 User Agent';

  @override
  String get debuggingEnabled => '디버깅 사용';

  @override
  String get debuggingEnabledDescription =>
      '이 앱의 WebView에 로드된 웹 콘텐츠 디버깅을 활성화합니다. iOS 16.4 미만에서는 디버깅 모드가 항상 활성화됩니다.';

  @override
  String get infocutterCutPage => '페이지 블록 숨기기';

  @override
  String get infocutterReviewSelection => '블록 숨김 설정';

  @override
  String infocutterReviewSelectionDescription(String host) {
    return '$host에서 숨길 블록과 저장 이름을 확인하세요.';
  }

  @override
  String get infocutterCardName => '블록 이름';

  @override
  String get infocutterSelector => '선택 기준';

  @override
  String get infocutterSelectorCandidates => '블록 후보';

  @override
  String get infocutterPointerCandidates => '포인터 후보';

  @override
  String get infocutterTargetRange => '대상 범위';

  @override
  String get infocutterSelectorDetails => '선택 기준 상세';

  @override
  String get infocutterNarrowTarget => '대상 좁히기';

  @override
  String get infocutterWidenTarget => '대상 넓히기';

  @override
  String get infocutterNextSelector => '다음 기준';

  @override
  String get infocutterSelectedTarget => '선택한 대상';

  @override
  String get infocutterSelectedBadge => '선택됨';

  @override
  String get infocutterApplyBlocked => '현재 기준은 적용할 수 없습니다';

  @override
  String get infocutterCutSettingsTab => '블록';

  @override
  String get infocutterCurrentSiteTab => '사이트';

  @override
  String get infocutterWatchTab => '감시';

  @override
  String get infocutterEvidenceTab => '캡처';

  @override
  String get infocutterSettingsTab => '설정';

  @override
  String get infocutterBlockShortTab => '블록';

  @override
  String get infocutterTextShortTab => '문구';

  @override
  String get infocutterAiShortTab => 'AI';

  @override
  String get infocutterTemplatesShortTab => '추천';

  @override
  String get infocutterDirectRemoveCategory => '직접 지우기';

  @override
  String get infocutterAutoRemoveCategory => '자동으로 지우기';

  @override
  String get infocutterManageRemovedCategory => '지운 것 관리하기';

  @override
  String get infocutterAppSettingsCategory => '설정하기';

  @override
  String get infocutterPickBlockRemoveTab => '화면에서 블록 선택해 지우기';

  @override
  String get infocutterKeywordBlockRemoveTab => '문구가 있는 블록 지우기';

  @override
  String get infocutterNetworkRequestBlockTab => '광고/추적 요청 막기';

  @override
  String get infocutterWatchAutoRemoveTab => '감시어가 나오면 자동으로 가리기';

  @override
  String get infocutterAiRecommendRemoveTab => 'AI가 지울 항목 추천하기';

  @override
  String get infocutterCurrentSiteRulesTab => '현재 사이트 규칙 관리하기';

  @override
  String get infocutterImportRecommendedRulesTab => '추천 규칙 가져오기';

  @override
  String get infocutterEvidenceRecordsViewTab => '캡처 기록 보기';

  @override
  String get infocutterGlobalSettingsTab => '인포커터 켜기/끄기';

  @override
  String get infocutterClosePanel => '인포커터 패널 닫기';

  @override
  String get infocutterActiveProfile => '활성 프로필';

  @override
  String get infocutterNoActiveProfile => '활성 프로필 없음';

  @override
  String get infocutterNoItemsYet => '아직 없음';

  @override
  String get infocutterWatchTargets => '감시 대상';

  @override
  String get infocutterEvidenceRecords => '캡처 기록';

  @override
  String get infocutterImportAndSettings => '가져오기 및 설정';

  @override
  String get infocutterGlobalEnabled => '인포커터 전역 사용';

  @override
  String get infocutterProfiles => '프로필';

  @override
  String infocutterProfilesCount(int count) {
    return '프로필 $count개';
  }

  @override
  String get infocutterCreateProfile => '프로필 만들기';

  @override
  String get infocutterProfileName => '프로필 이름';

  @override
  String get infocutterMatchers => '매처';

  @override
  String get infocutterEditMatchers => '매처 편집';

  @override
  String get infocutterRename => '이름 변경';

  @override
  String get infocutterDelete => '삭제';

  @override
  String get infocutterConfirmDeleteMessage => '이 항목을 삭제할까요? 이 작업은 되돌릴 수 없습니다.';

  @override
  String get infocutterImportJson => 'Chrome JSON 가져오기';

  @override
  String get infocutterExportJson => 'Chrome JSON 내보내기';

  @override
  String get infocutterExportCopied => '내보내기 JSON을 클립보드에 복사했습니다';

  @override
  String get infocutterSave => '저장';

  @override
  String get infocutterRuleActions => '규칙 작업';

  @override
  String get infocutterEditSelector => '선택 기준 편집';

  @override
  String get infocutterToggleRuleMode => '숨김/예외 전환';

  @override
  String get infocutterFrameScope => '프레임 범위';

  @override
  String get infocutterMainFrame => '메인 프레임';

  @override
  String get infocutterRuleModeHide => '숨김';

  @override
  String get infocutterRuleModeUnhide => '예외';

  @override
  String get infocutterTemplates => '사전 규칙 템플릿';

  @override
  String get infocutterImportTemplate => '템플릿 가져오기';

  @override
  String infocutterTemplateImported(String name) {
    return '$name 템플릿을 가져왔습니다';
  }

  @override
  String get infocutterWatchGlobalEnabled => '감시 사용';

  @override
  String get infocutterWatchAutoMask => '감지 시 자동 가리기';

  @override
  String get infocutterWatchTargetName => '감시 대상 이름';

  @override
  String get infocutterWatchAliases => '별칭 (쉼표로 구분)';

  @override
  String get infocutterAddWatchTarget => '감시 대상 추가';

  @override
  String get infocutterWatchDetections => '최근 감지';

  @override
  String get infocutterCaptureEvidence => '현재 페이지 캡처 저장';

  @override
  String get infocutterNoEvidenceRecords => '저장된 캡처 기록이 없습니다';

  @override
  String infocutterEvidenceCaptured(int sequence) {
    return '캡처 기록 #$sequence을 저장했습니다';
  }

  @override
  String get infocutterAiAutoMasking => 'AI 자동 마스킹';

  @override
  String get infocutterAiPendingDecision => '앱 버전 포함 여부와 개인정보/비용 정책 결정이 필요합니다.';

  @override
  String infocutterAiConfigured(String model) {
    return '$model 설정됨';
  }

  @override
  String get infocutterAiEndpoint => 'AI 엔드포인트';

  @override
  String get infocutterAiModel => '모델';

  @override
  String get infocutterAiApiKey => 'API 키';

  @override
  String get infocutterAiSaveConfig => 'AI 설정 저장';

  @override
  String get infocutterAiConfigSaved => 'AI 설정을 저장했습니다';

  @override
  String get infocutterAiResetHosts => '분석 기록 초기화';

  @override
  String infocutterAiAnalyzedHosts(int count) {
    return '분석한 호스트 $count개';
  }

  @override
  String get infocutterAiAnalyzeCurrentPage => '현재 페이지 AI 분석';

  @override
  String get infocutterAiAnalyzing => '분석 중';

  @override
  String get infocutterAiAnalyzeFailed => 'AI 분석에 실패했습니다';

  @override
  String get infocutterAiApplySuggestion => '제안 적용';

  @override
  String infocutterAiSuggestions(int count) {
    return 'AI 제안 $count개';
  }

  @override
  String get infocutterTextBlocks => '텍스트 블록';

  @override
  String get infocutterTextBlockGlobalEnabled => '텍스트 블록 숨김 사용';

  @override
  String get infocutterTextBlockKeyword => '키워드';

  @override
  String get infocutterTextBlockObjectName => '대상 이름';

  @override
  String get infocutterTextBlockMinMatchCount => '최소 반복 수';

  @override
  String get infocutterTextBlockAddRule => '텍스트 블록 규칙 추가';

  @override
  String get infocutterTextBlockProfileEnabled => '현재 사이트 텍스트 규칙 사용';

  @override
  String get infocutterCaptureKeyword => '키워드 잡기';

  @override
  String get infocutterNetworkFilters => '네트워크 필터';

  @override
  String get infocutterNetworkFilterGlobalEnabled => '네트워크 필터 사용';

  @override
  String get infocutterNetworkFilterPaste => 'ABP/uBlock 네트워크 필터 붙여넣기';

  @override
  String get infocutterNetworkFilterImport => '필터 가져오기';

  @override
  String infocutterNetworkFilterImportResult(int imported, int skipped) {
    return '가져옴 $imported개 · 건너뜀 $skipped개';
  }

  @override
  String get infocutterNetworkFilterAllowRule => '허용 규칙';

  @override
  String get infocutterNetworkFilterBlockRule => '차단 규칙';

  @override
  String get infocutterRemove => '삭제';

  @override
  String infocutterSavedCards(int count) {
    return '블록 $count개';
  }

  @override
  String infocutterSavedRules(int count) {
    return '규칙 $count개';
  }

  @override
  String infocutterEnabledRules(int count) {
    return '활성 숨김 $count개';
  }

  @override
  String infocutterMatchCount(int count) {
    return '매치 $count개';
  }

  @override
  String get infocutterInvalidSelector => '유효하지 않은 선택 기준입니다';

  @override
  String get infocutterSaveRule => '블록 숨기기';

  @override
  String get infocutterSessionPickHint => '페이지에서 지울 요소를 클릭해 담으세요';

  @override
  String infocutterStagedCount(int count) {
    return '담은 항목 $count개';
  }

  @override
  String infocutterSessionApplyAll(int count) {
    return '전체 적용 ($count)';
  }

  @override
  String get infocutterPickTab => '고르기';

  @override
  String get infocutterHiddenListTab => '숨긴 목록';

  @override
  String get infocutterTooBroadSelector => '전체 페이지를 가립니다';

  @override
  String get infocutterFixSelectorsToApply => '적용하려면 잘못된 기준을 고치세요';

  @override
  String get infocutterModulesTab => '모듈 관리';

  @override
  String get infocutterModulesHint => '끄면 해당 기능이 모든 사이트에서 멈춥니다';

  @override
  String get infocutterBackupRestore => '백업 / 복원';

  @override
  String get infocutterExportRules => '내보내기';

  @override
  String get infocutterImportRules => '가져오기';

  @override
  String get infocutterRulesExported => '블록 규칙을 클립보드에 복사했습니다';

  @override
  String get infocutterRulesImported => '규칙을 가져왔습니다';

  @override
  String get infocutterImportPasteHint => '내보낸 JSON을 붙여넣으세요';

  @override
  String get infocutterUndo => '실행취소';

  @override
  String get infocutterEvidenceCaptureFailed => '페이지 캡처를 저장하지 못했습니다';

  @override
  String get infocutterImportReplaceWarning => '주의: 가져오면 지금 저장된 규칙을 덮어씁니다';

  @override
  String get infocutterImportInvalid => '올바른 설정 형식이 아닙니다';

  @override
  String get infocutterAiPrompt => 'AI 프롬프트';

  @override
  String get infocutterAiPromptHelp => '무엇을 숨길지 지시하세요 (출력 형식은 자동 처리됩니다)';

  @override
  String infocutterAlreadyHiddenSection(int count) {
    return '이미 숨긴 것 ($count)';
  }

  @override
  String infocutterPickingNowSection(int count) {
    return '지금 고르는 중 ($count)';
  }

  @override
  String get infocutterAppliedEditsLiveHint => '여기서 고치면 페이지에 바로 반영돼요';

  @override
  String get infocutterDeleteRule => '규칙 삭제';

  @override
  String get infocutterCardsManagedInPickTab => '이 프로필의 카드는 \'고르기\' 탭에서 편집합니다';

  @override
  String get settingsAdvanced => '고급';

  @override
  String get settingsAdvancedSubtitle => 'WebView 세부 설정. 대부분 바꿀 필요가 없습니다.';

  @override
  String get settingsDeveloperTools => '개발자 도구';

  @override
  String get onboardingTitle => '보고 싶은 것만 남기세요';

  @override
  String get onboardingPickBody =>
      '주소창 옆 가위 버튼을 누르고 화면에서 가릴 요소를 고르세요. 같은 사이트에 다시 오면 자동으로 가려집니다.';

  @override
  String get onboardingPeekBody => '가린 것을 잠깐 보려면 미리보기를 켜세요. 규칙은 사이트별로 저장됩니다.';

  @override
  String get onboardingStart => '시작하기';

  @override
  String get onboardingSkip => '건너뛰기';

  @override
  String get authUnsupportedTitle => '이 브라우저에서는 로그인할 수 없습니다';

  @override
  String get authUnsupportedBody =>
      'Google 등 일부 서비스는 앱에 내장된 브라우저에서의 로그인을 정책상 차단합니다. 앱 문제가 아닙니다.';

  @override
  String get authOpenExternally => '기본 브라우저로 열기';

  @override
  String get a11yBack => '뒤로';

  @override
  String get a11yForward => '앞으로';

  @override
  String get a11yReload => '새로고침';

  @override
  String get a11yMoreMenu => '추가 메뉴';

  @override
  String get a11yTabCount => '열린 탭 수';

  @override
  String get a11yInfocutterPick => '가릴 요소 고르기';

  @override
  String get a11yActionBar => '브라우저 도구 모음';

  @override
  String get a11ySiteInfo => '사이트 정보 보기';

  @override
  String get rendererCrashTitle => '페이지를 그리는 과정이 중단됐습니다';

  @override
  String get rendererCrashBody =>
      '기기 메모리가 부족하면 시스템이 웹 페이지 프로세스를 먼저 정리합니다. 다른 앱을 닫은 뒤 다시 시도해 보세요.';

  @override
  String get rendererCrashRetry => '다시 시도';

  @override
  String get loadErrorTitle => '페이지를 불러오지 못했습니다';

  @override
  String get loadErrorBodyGeneric => '네트워크 오류이거나 사이트에 연결할 수 없습니다.';

  @override
  String get loadErrorTimeout => '응답이 없어 중단했습니다. 연결을 확인한 뒤 다시 시도해 보세요.';

  @override
  String get loadErrorRetry => '다시 시도';

  @override
  String get siteProtectionBypassTitle => '이 사이트에서 보호 끄기';

  @override
  String get siteProtectionBypassSubtitle => '가리기·필터·감시가 페이지를 깨뜨릴 때 잠시 끕니다';

  @override
  String get siteProtectionBypassActiveHint => '이 호스트에서는 인포커터 보호가 꺼져 있습니다.';

  @override
  String get networkFilterSubscribeUrl => '필터 목록 URL';

  @override
  String get networkFilterSubscribeAction => 'URL에서 가져오기';

  @override
  String networkFilterSubscribeFailed(String error) {
    return '필터 목록을 가져오지 못했습니다: $error';
  }

  @override
  String get jsDialogDefaultTitle => '이 페이지 메시지';

  @override
  String get readerModeTitle => '읽기 모드';

  @override
  String get readerModeEmpty => '이 페이지에서 읽을 본문을 찾지 못했습니다.';

  @override
  String get readerModeFailed => '읽기 모드를 열지 못했습니다.';

  @override
  String get menuReaderMode => '읽기 모드';

  @override
  String get pickerStopped => '선택 모드를 종료했습니다';
}
