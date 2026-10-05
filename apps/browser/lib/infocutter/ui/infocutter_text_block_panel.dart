import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:infocutter_app/infocutter/text_block_models.dart';
import 'package:infocutter_app/infocutter/text_block_service.dart';
import 'package:infocutter_app/infocutter/ui/infocutter_sidebar_widgets.dart';
import 'package:infocutter_app/l10n/generated/app_localizations.dart';
import 'package:provider/provider.dart';

class InfocutterTextBlockPanel extends StatefulWidget {
  const InfocutterTextBlockPanel({
    required this.url,
    required this.onTextBlocksChanged,
    this.showHeader = true,
    this.capturedKeyword,
    this.keywordCaptureActive,
    this.onSetKeywordCapture,
    super.key,
  });

  final Uri url;
  final Future<void> Function() onTextBlocksChanged;
  final bool showHeader;

  /// Live captured keyword from page-text selection. When non-empty it fills
  /// the keyword field (focus-guarded so it doesn't clobber active typing).
  final ValueListenable<String?>? capturedKeyword;

  /// Whether the "키워드 잡기" capture mode is currently active on the page.
  /// A [ValueListenable<bool>] so the toggle reflects state reactively.
  final ValueListenable<bool>? keywordCaptureActive;

  /// Called when the toggle is flipped; `true` = start capture, `false` = stop.
  final void Function(bool active)? onSetKeywordCapture;

  @override
  State<InfocutterTextBlockPanel> createState() =>
      _InfocutterTextBlockPanelState();
}

class _InfocutterTextBlockPanelState extends State<InfocutterTextBlockPanel> {
  final TextEditingController _keywordController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _minCountController =
      TextEditingController(text: '2');
  final FocusNode _keywordFocusNode = FocusNode();

  @override
  void dispose() {
    _keywordController.removeListener(_handleFormChanged);
    _minCountController.removeListener(_handleFormChanged);
    widget.capturedKeyword?.removeListener(_onCapturedKeyword);
    _keywordController.dispose();
    _nameController.dispose();
    _minCountController.dispose();
    _keywordFocusNode.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _keywordController.addListener(_handleFormChanged);
    _minCountController.addListener(_handleFormChanged);
    widget.capturedKeyword?.addListener(_onCapturedKeyword);
  }

  @override
  void didUpdateWidget(InfocutterTextBlockPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.capturedKeyword != widget.capturedKeyword) {
      oldWidget.capturedKeyword?.removeListener(_onCapturedKeyword);
      widget.capturedKeyword?.addListener(_onCapturedKeyword);
    }
  }

  void _onCapturedKeyword() {
    final text = widget.capturedKeyword?.value;
    if (text == null || text.trim().isEmpty) return;
    // Focus-guard: don't overwrite while the user is actively typing.
    if (_keywordFocusNode.hasFocus) return;
    if (!mounted) return;
    setState(() {
      _keywordController.text = text.trim();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final service = Provider.of<TextBlockService>(context);
    final active = service.buildActiveStateForUrl(widget.url);
    final children = [
      _buildGlobalToggle(service, l10n),
      ..._buildRuleForm(l10n),
      const Divider(),
      ..._buildActiveRules(service, active, l10n),
    ];

    if (!widget.showHeader) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: children,
      );
    }

    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      leading: const Icon(Icons.text_fields),
      title: Text(l10n.infocutterTextBlocks),
      subtitle: Text(
        active.activeProfileName ?? l10n.infocutterNoActiveProfile,
      ),
      childrenPadding: const EdgeInsets.only(bottom: 12),
      children: children,
    );
  }

  Widget _buildGlobalToggle(
    TextBlockService service,
    AppLocalizations l10n,
  ) =>
      InfocutterZeroPaddingSwitchTile(
        title: l10n.infocutterTextBlockGlobalEnabled,
        value: service.globalEnabled,
        onChanged: (value) => _update(() => service.setGlobalEnabled(value)),
      );

  Widget _buildCaptureToggle(AppLocalizations l10n) {
    final notifier = widget.keywordCaptureActive;
    if (notifier == null) {
      return InfocutterZeroPaddingSwitchTile(
        title: l10n.infocutterCaptureKeyword,
        value: false,
        onChanged: widget.onSetKeywordCapture,
      );
    }
    return ValueListenableBuilder<bool>(
      valueListenable: notifier,
      builder: (context, active, _) => InfocutterZeroPaddingSwitchTile(
        title: l10n.infocutterCaptureKeyword,
        value: active,
        onChanged: widget.onSetKeywordCapture,
      ),
    );
  }

  List<Widget> _buildRuleForm(AppLocalizations l10n) => [
        if (widget.onSetKeywordCapture != null) _buildCaptureToggle(l10n),
        TextField(
          controller: _keywordController,
          focusNode: _keywordFocusNode,
          decoration: InputDecoration(
            labelText: l10n.infocutterTextBlockKeyword,
            border: const OutlineInputBorder(),
          ),
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 8),
        InfocutterOutlinedTextField(
          controller: _nameController,
          labelText: l10n.infocutterTextBlockObjectName,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 8),
        InfocutterOutlinedTextField(
          controller: _minCountController,
          labelText: l10n.infocutterTextBlockMinMatchCount,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: _canAddRule ? _addRule : null,
          icon: const Icon(Icons.playlist_add),
          label: Text(l10n.infocutterTextBlockAddRule),
        ),
      ];

  List<Widget> _buildActiveRules(
    TextBlockService service,
    ActiveTextBlockState active,
    AppLocalizations l10n,
  ) {
    final profileId = active.activeProfileId;
    if (profileId == null || active.rules.isEmpty) {
      return [
        InfocutterEmptyTile(
          icon: Icons.text_fields,
          label: l10n.infocutterNoItemsYet,
        ),
      ];
    }

    return [
      InfocutterZeroPaddingSwitchTile(
        title: l10n.infocutterTextBlockProfileEnabled,
        value: active.profileEnabled,
        onChanged: (value) => _update(
          () => service.setProfileEnabled(profileId, value),
        ),
      ),
      ...active.rules.map(
        (rule) => _buildRuleTile(service, profileId, rule, l10n),
      ),
    ];
  }

  Widget _buildRuleTile(
    TextBlockService service,
    String profileId,
    TextBlockRule rule,
    AppLocalizations l10n,
  ) =>
      ListTile(
        contentPadding: EdgeInsets.zero,
        onTap: () => _update(
          () => service.setRuleEnabled(profileId, rule.id, !rule.enabled),
        ),
        leading: Switch(
          value: rule.enabled,
          onChanged: (value) => _update(
            () => service.setRuleEnabled(profileId, rule.id, value),
          ),
        ),
        title: Text(rule.objectName),
        subtitle: Text(
          '${rule.keyword} · ${l10n.infocutterMatchCount(rule.minMatchCount)}',
        ),
        trailing: IconButton(
          tooltip: l10n.infocutterRemove,
          icon: const Icon(Icons.delete_outline),
          onPressed: () async {
            final confirmed = await showInfocutterDeleteConfirmation(context);
            if (!mounted || !confirmed) return;
            await _update(
              () => service.removeRule(profileId, rule.id),
            );
          },
        ),
      );

  Future<void> _addRule() async {
    final keyword = _keywordController.text.trim();
    if (!_canAddRule) return;
    final service = context.read<TextBlockService>();
    await service.addRuleForUrl(
      TextBlockRuleRequest(
        url: widget.url,
        keyword: keyword,
        objectName: _nameController.text.trim(),
        minMatchCount: int.tryParse(_minCountController.text.trim()) ?? 2,
      ),
    );
    await widget.onTextBlocksChanged();
    if (!mounted) return;
    _keywordController.clear();
    _nameController.clear();
    _minCountController.text = '2';
  }

  bool get _canAddRule {
    final minCount = int.tryParse(_minCountController.text.trim());
    return _keywordController.text.trim().isNotEmpty &&
        minCount != null &&
        minCount >= 2;
  }

  void _handleFormChanged() {
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _update(Future<void> Function() update) async {
    await update();
    await widget.onTextBlocksChanged();
  }
}
