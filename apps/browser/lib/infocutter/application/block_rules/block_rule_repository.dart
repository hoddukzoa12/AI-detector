import 'package:infocutter_app/infocutter/application/block_rules/block_rule_import_export.dart';
import 'package:infocutter_app/infocutter/application/block_rules/block_rule_management.dart';
import 'package:infocutter_app/infocutter/application/block_rules/block_rule_reader.dart';
import 'package:infocutter_app/infocutter/application/block_rules/picked_block_rule_writer.dart';

abstract interface class BlockRuleRepository
    implements
        BlockRuleReader,
        PickedBlockRuleWriter,
        BlockRuleManagement,
        BlockRuleImportExport {}
