import 'package:infocutter_app/infocutter/ai_config_service.dart';
import 'package:infocutter_app/infocutter/ai_rule_service.dart';
import 'package:infocutter_app/infocutter/application/block_rules/block_rule_repository.dart';
import 'package:infocutter_app/infocutter/application/block_rules/infocutter_service_block_rule_repository.dart';
import 'package:infocutter_app/infocutter/application/block_rules/save_picked_block_rule_use_case.dart';
import 'package:infocutter_app/infocutter/evidence_service.dart';
import 'package:infocutter_app/infocutter/infocutter_service.dart';
import 'package:infocutter_app/infocutter/network_filter_service.dart';
import 'package:infocutter_app/infocutter/site_protection_bypass.dart';
import 'package:infocutter_app/infocutter/text_block_service.dart';
import 'package:infocutter_app/infocutter/watch_service.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

List<SingleChildWidget> infocutterProviders() => [
      ChangeNotifierProvider<SiteProtectionBypass>.value(
        value: SiteProtectionBypass.instance..ensureLoaded(),
      ),
      ChangeNotifierProvider<InfocutterService>(
        create: (_) => InfocutterService()..load(),
      ),
      ListenableProxyProvider<InfocutterService, BlockRuleRepository>(
        update: (_, service, __) => InfocutterServiceBlockRuleRepository(
          service,
        ),
      ),
      ProxyProvider<BlockRuleRepository, SavePickedBlockRuleUseCase>(
        update: (_, repository, __) => SavePickedBlockRuleUseCase(repository),
      ),
      ChangeNotifierProvider<WatchService>(
        create: (_) => WatchService()..load(),
      ),
      ChangeNotifierProvider<EvidenceService>(
        create: (_) => EvidenceService()..load(),
      ),
      ChangeNotifierProvider<AiConfigService>(
        create: (_) => AiConfigService()..load(),
      ),
      ChangeNotifierProvider<AiRuleService>(
        create: (_) => AiRuleService()..load(),
      ),
      ChangeNotifierProvider<TextBlockService>(
        create: (_) => TextBlockService()..load(),
      ),
      ChangeNotifierProvider<NetworkFilterService>(
        create: (_) => NetworkFilterService()..load(),
      ),
    ];
