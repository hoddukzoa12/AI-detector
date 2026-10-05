import 'package:flutter/material.dart';
import 'package:infocutter_app/infocutter/ai_config_service.dart';
import 'package:infocutter_app/infocutter/ai_masking_service.dart';
import 'package:infocutter_app/infocutter/ai_rule_service.dart';
import 'package:infocutter_app/infocutter/application/block_rules/save_picked_block_rule_use_case.dart';
import 'package:infocutter_app/infocutter/ui/infocutter_sidebar_widgets.dart';
import 'package:infocutter_app/l10n/generated/app_localizations.dart';
import 'package:provider/provider.dart';

class InfocutterAiSettingsPanel extends StatefulWidget {
  const InfocutterAiSettingsPanel({
    required this.onAnalyzeCurrentPage,
    required this.onRulesChanged,
    required this.url,
    this.showHeader = true,
    super.key,
  });

  final Future<List<AiPageCandidate>> Function() onAnalyzeCurrentPage;
  final Future<void> Function() onRulesChanged;
  final Uri url;
  final bool showHeader;

  @override
  State<InfocutterAiSettingsPanel> createState() =>
      _InfocutterAiSettingsPanelState();
}

class _InfocutterAiSettingsPanelState extends State<InfocutterAiSettingsPanel> {
  late final TextEditingController _endpointController;
  late final TextEditingController _apiKeyController;
  late final TextEditingController _modelController;
  late final TextEditingController _promptController;
  final AiMaskingService _maskingService = AiMaskingService();
  bool _initialized = false;
  bool _analyzing = false;

  @override
  void initState() {
    super.initState();
    _endpointController = TextEditingController();
    _apiKeyController = TextEditingController();
    _modelController = TextEditingController();
    _promptController = TextEditingController();
  }

  @override
  void dispose() {
    _endpointController.dispose();
    _apiKeyController.dispose();
    _modelController.dispose();
    _promptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final service = Provider.of<AiConfigService>(context);
    final ruleService = Provider.of<AiRuleService>(context);
    final config = service.snapshot;
    final suggestions = ruleService.rulesForHost(widget.url.host);
    if (!_initialized) {
      _endpointController.text = config.endpoint;
      _apiKeyController.text = config.apiKey;
      _modelController.text = config.model;
      _promptController.text = config.prompt;
      _initialized = true;
    }
    final children = [
      ..._buildConfigFields(l10n),
      const SizedBox(height: 8),
      _buildActions(service, l10n),
      const SizedBox(height: 8),
      _buildAnalysisActions(service, l10n),
      ..._buildSuggestions(suggestions, l10n),
      const SizedBox(height: 8),
      _buildAnalyzedHostsSummary(config, l10n),
    ];

    if (!widget.showHeader) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: children,
      );
    }

    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      leading: const Icon(Icons.auto_fix_high),
      title: Text(l10n.infocutterAiAutoMasking),
      subtitle: Text(
        service.isConfigured
            ? l10n.infocutterAiConfigured(config.model)
            : l10n.infocutterAiPendingDecision,
      ),
      childrenPadding: const EdgeInsets.only(bottom: 12),
      children: children,
    );
  }

  List<Widget> _buildConfigFields(AppLocalizations l10n) => [
        InfocutterOutlinedTextField(
          controller: _endpointController,
          labelText: l10n.infocutterAiEndpoint,
          keyboardType: TextInputType.url,
        ),
        const SizedBox(height: 8),
        InfocutterOutlinedTextField(
          controller: _modelController,
          labelText: l10n.infocutterAiModel,
        ),
        const SizedBox(height: 8),
        InfocutterOutlinedTextField(
          controller: _apiKeyController,
          labelText: l10n.infocutterAiApiKey,
          obscureText: true,
        ),
        const SizedBox(height: 8),
        InfocutterOutlinedTextField(
          controller: _promptController,
          labelText: l10n.infocutterAiPrompt,
          helperText: l10n.infocutterAiPromptHelp,
          minLines: 2,
          maxLines: 4,
        ),
      ];

  Widget _buildActions(
    AiConfigService service,
    AppLocalizations l10n,
  ) =>
      Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _analyzing || service.snapshot.analyzedHosts.isEmpty
                  ? null
                  : service.resetAnalyzedHosts,
              icon: const Icon(Icons.refresh),
              label: Text(l10n.infocutterAiResetHosts),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: FilledButton.icon(
              onPressed: _analyzing ? null : _save,
              icon: const Icon(Icons.save),
              label: Text(l10n.infocutterAiSaveConfig),
            ),
          ),
        ],
      );

  Widget _buildAnalysisActions(
    AiConfigService service,
    AppLocalizations l10n,
  ) =>
      SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: !_analyzing && service.isConfigured ? _analyze : null,
          icon: _analyzing
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.auto_awesome),
          label: Text(
            _analyzing
                ? l10n.infocutterAiAnalyzing
                : l10n.infocutterAiAnalyzeCurrentPage,
          ),
        ),
      );

  List<Widget> _buildSuggestions(
    List<GeneratedAiRule> suggestions,
    AppLocalizations l10n,
  ) {
    if (suggestions.isEmpty) return const [];
    return [
      const Divider(),
      Align(
        alignment: Alignment.centerLeft,
        child: Text(
          l10n.infocutterAiSuggestions(suggestions.length),
          style: Theme.of(context).textTheme.titleSmall,
        ),
      ),
      const SizedBox(height: 8),
      ...suggestions.map(
        (suggestion) => ListTile(
          contentPadding: EdgeInsets.zero,
          onTap: suggestion.applied ? null : () => _applySuggestion(suggestion),
          leading: Icon(
            suggestion.applied
                ? Icons.check_circle_outline
                : Icons.auto_fix_high,
          ),
          title: Text(
            suggestion.label.isEmpty ? suggestion.selector : suggestion.label,
          ),
          subtitle: Text(
            [
              suggestion.selector,
              if (suggestion.reason.isNotEmpty) suggestion.reason,
            ].join('\n'),
          ),
          trailing: IconButton(
            tooltip: l10n.infocutterAiApplySuggestion,
            icon: const Icon(Icons.add),
            onPressed:
                suggestion.applied ? null : () => _applySuggestion(suggestion),
          ),
        ),
      ),
    ];
  }

  Widget _buildAnalyzedHostsSummary(
    AiConfigSnapshot config,
    AppLocalizations l10n,
  ) =>
      Align(
        alignment: Alignment.centerLeft,
        child: Text(
          l10n.infocutterAiAnalyzedHosts(config.analyzedHosts.length),
        ),
      );

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final service = context.read<AiConfigService>();
    await service.saveConfig(
      endpoint: _endpointController.text,
      apiKey: _apiKeyController.text,
      model: _modelController.text,
      prompt: _promptController.text,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.infocutterAiConfigSaved)),
    );
  }

  Future<void> _analyze() async {
    final l10n = AppLocalizations.of(context);
    final configService = context.read<AiConfigService>();
    final aiRuleService = context.read<AiRuleService>();
    setState(() {
      _analyzing = true;
    });
    try {
      final candidates = await widget.onAnalyzeCurrentPage();
      final suggestions = await _maskingService.analyze(
        candidates: candidates,
        config: configService.snapshot,
        url: widget.url,
      );
      final saved = await aiRuleService.addSuggestions(
        url: widget.url,
        suggestions: suggestions,
      );
      await configService.markHostAnalyzed(widget.url.host);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.infocutterAiSuggestions(saved.length)),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.infocutterAiAnalyzeFailed)),
      );
    } finally {
      if (mounted) {
        setState(() {
          _analyzing = false;
        });
      }
    }
  }

  Future<void> _applySuggestion(GeneratedAiRule suggestion) async {
    final l10n = AppLocalizations.of(context);
    final savePickedBlockRule = context.read<SavePickedBlockRuleUseCase>();
    final aiRuleService = context.read<AiRuleService>();
    final defaultCardName = l10n.infocutterAiAutoMasking;
    await savePickedBlockRule(
      SavePickedBlockRuleCommand(
        url: widget.url,
        selector: suggestion.selector,
        cardName: suggestion.label.isEmpty ? defaultCardName : suggestion.label,
      ),
    );
    await aiRuleService.markAppliedForSelector(
      host: widget.url.host,
      selector: suggestion.selector,
    );
    await widget.onRulesChanged();
  }
}
