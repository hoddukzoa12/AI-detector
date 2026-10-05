import 'package:infocutter_app/infocutter/models.dart';
import 'package:infocutter_app/infocutter/template_catalog.dart';

abstract interface class BlockRuleImportExport {
  String exportChromeJson();

  Future<void> importChromeJson(String raw);

  Future<RuleProfile> importTemplate(InfocutterTemplate template);
}
