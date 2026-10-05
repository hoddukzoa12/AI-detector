import 'package:flutter/foundation.dart';
import 'package:infocutter_app/infocutter/models.dart';

abstract interface class BlockRuleReader implements Listenable {
  bool get globalEnabled;

  List<RuleProfile> get profiles;

  ActiveSiteState buildActiveSiteState(Uri url);
}
