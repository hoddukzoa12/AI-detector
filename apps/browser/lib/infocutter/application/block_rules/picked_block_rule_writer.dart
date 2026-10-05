import 'package:infocutter_app/infocutter/models.dart';

abstract interface class PickedBlockRuleWriter {
  Future<StoredRule> addPickedRuleForUrl({
    required Uri url,
    required String selector,
    String cardName = 'Picked elements',
    String? frameScope,
  });
}
