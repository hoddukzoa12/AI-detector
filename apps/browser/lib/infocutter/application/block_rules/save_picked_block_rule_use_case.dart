import 'package:infocutter_app/infocutter/application/block_rules/picked_block_rule_writer.dart';
import 'package:infocutter_app/infocutter/models.dart';

class SavePickedBlockRuleCommand {
  const SavePickedBlockRuleCommand({
    required this.url,
    required this.selector,
    required this.cardName,
    this.frameScope,
  });

  final Uri url;
  final String selector;
  final String cardName;
  final String? frameScope;
}

class SavePickedBlockRuleUseCase {
  const SavePickedBlockRuleUseCase(this._repository);

  final PickedBlockRuleWriter _repository;

  Future<StoredRule> call(SavePickedBlockRuleCommand command) {
    final host = command.url.host.trim();
    if (host.isEmpty) {
      throw ArgumentError.value(
        command.url.toString(),
        'url',
        'URL must include a host',
      );
    }

    final selector = command.selector.trim();
    if (selector.isEmpty) {
      throw ArgumentError.value(
        command.selector,
        'selector',
        'selector must not be empty',
      );
    }

    return _repository.addPickedRuleForUrl(
      url: command.url,
      selector: selector,
      cardName: _nonEmptyTrimmed(command.cardName) ?? host,
      frameScope: _nonEmptyTrimmed(command.frameScope),
    );
  }

  String? _nonEmptyTrimmed(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
