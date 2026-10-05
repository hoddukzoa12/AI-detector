import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:uuid/uuid.dart';

import 'content_blocker_factory.dart';
import 'models.dart';
import 'rule_store_codec.dart';
import 'storage.dart';
import 'template_catalog.dart';
import 'url_matcher.dart';

part 'infocutter_profile_mutations.dart';
part 'infocutter_rule_mutations.dart';
part 'infocutter_store_mutations.dart';
part 'infocutter_runtime_builder.dart';

const _uuid = Uuid();

class InfocutterService extends ChangeNotifier {
  InfocutterService({
    RuleStoreCodec? codec,
    ContentBlockerFactory? blockerFactory,
    InfocutterStore? store,
  })  : _codec = codec ?? const RuleStoreCodec(),
        _blockerFactory = blockerFactory ?? const ContentBlockerFactory(),
        _store = store ?? const SharedPreferencesInfocutterStore();

  final RuleStoreCodec _codec;
  final ContentBlockerFactory _blockerFactory;
  final InfocutterStore _store;

  RuleStoreSnapshot _snapshot = RuleStoreSnapshot.empty;
  bool _loaded = false;

  RuleStoreSnapshot get snapshot => _snapshot;
  bool get isLoaded => _loaded;
  bool get globalEnabled => _snapshot.globalEnabled;
  List<RuleProfile> get profiles => List.unmodifiable(_snapshot.profiles);

  /// 앱 시작 시 한 번 호출. InfocutterStore 에서 영속 데이터 로드.
  Future<void> load() async {
    final raw = await _store.loadRuleStoreJson();
    if (raw != null && raw.isNotEmpty) {
      _snapshot = _codec.decodeJson(raw);
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> _persist() async {
    await _store.saveRuleStoreJson(_codec.encodeJson(_snapshot));
  }

  Future<void> _commitSnapshot(RuleStoreSnapshot snapshot) async {
    _snapshot = snapshot;
    await _persist();
    notifyListeners();
  }

  Future<void> _commitProfiles(List<RuleProfile> profiles) {
    return _commitSnapshot(_snapshot.copyWith(profiles: profiles));
  }

  int _profileIndexById(String profileId) {
    return _snapshot.profiles.indexWhere((profile) => profile.id == profileId);
  }

  String exportChromeJson() => _codec.encodeJson(_snapshot);
}
