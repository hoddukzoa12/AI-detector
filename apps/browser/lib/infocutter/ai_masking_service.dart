import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'ai_config_service.dart';

@immutable
class AiPageCandidate {
  const AiPageCandidate({
    required this.selector,
    this.className = '',
    this.height = 0,
    this.id = '',
    this.role = '',
    this.tag = '',
    this.textLength = 0,
    this.width = 0,
  });

  final String selector;
  final String className;
  final int height;
  final String id;
  final String role;
  final String tag;
  final int textLength;
  final int width;

  Map<String, Object?> toJson() => {
        'selector': selector,
        'tag': tag,
        'id': id,
        'className': className,
        'role': role,
        'textLength': textLength,
        'width': width,
        'height': height,
      };

  static AiPageCandidate? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final selector = raw['selector'];
    if (selector is! String || selector.trim().isEmpty) return null;
    return AiPageCandidate(
      selector: selector.trim(),
      tag: raw['tag'] is String ? raw['tag'] as String : '',
      id: raw['id'] is String ? raw['id'] as String : '',
      className: raw['className'] is String ? raw['className'] as String : '',
      role: raw['role'] is String ? raw['role'] as String : '',
      textLength: _asInt(raw['textLength']),
      width: _asInt(raw['width']),
      height: _asInt(raw['height']),
    );
  }
}

@immutable
class AiMaskingSuggestion {
  const AiMaskingSuggestion({
    required this.selector,
    this.confidence = 0,
    this.label = '',
    this.reason = '',
  });

  final String selector;
  final double confidence;
  final String label;
  final String reason;

  static AiMaskingSuggestion? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final selector = raw['selector'];
    if (selector is! String || selector.trim().isEmpty) return null;
    return AiMaskingSuggestion(
      selector: selector.trim(),
      label: raw['label'] is String ? raw['label'] as String : '',
      reason: raw['reason'] is String ? raw['reason'] as String : '',
      confidence: _asDouble(raw['confidence']),
    );
  }
}

abstract interface class AiMaskingClient {
  Future<List<AiMaskingSuggestion>> analyze({
    required List<AiPageCandidate> candidates,
    required AiConfigSnapshot config,
    required Uri url,
  });
}

class AiMaskingService {
  AiMaskingService({
    AiMaskingClient? client,
  }) : _client = client ?? const OpenAiCompatibleAiMaskingClient();

  final AiMaskingClient _client;

  Future<List<AiMaskingSuggestion>> analyze({
    required List<AiPageCandidate> candidates,
    required AiConfigSnapshot config,
    required Uri url,
  }) async {
    if (!config.isConfigured) {
      throw StateError('AI masking is not configured');
    }
    final limitedCandidates = candidates.take(80).toList();
    if (limitedCandidates.isEmpty) {
      return const [];
    }
    return _client.analyze(
      candidates: limitedCandidates,
      config: config,
      url: url,
    );
  }
}

class OpenAiCompatibleAiMaskingClient implements AiMaskingClient {
  const OpenAiCompatibleAiMaskingClient({
    Duration timeout = const Duration(seconds: 30),
  }) : _timeout = timeout;

  final Duration _timeout;

  @override
  Future<List<AiMaskingSuggestion>> analyze({
    required List<AiPageCandidate> candidates,
    required AiConfigSnapshot config,
    required Uri url,
  }) async {
    final endpoint = Uri.parse(config.endpoint);
    final client = HttpClient();
    try {
      final request = await client.postUrl(endpoint).timeout(_timeout);
      request.headers.contentType = ContentType.json;
      request.headers
          .set(HttpHeaders.authorizationHeader, 'Bearer ${config.apiKey}');
      request.write(jsonEncode(buildAiMaskingPayload(
        candidates: candidates,
        config: config,
        url: url,
      )));
      final response = await request.close().timeout(_timeout);
      final body = await utf8.decoder.bind(response).join().timeout(_timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
          'AI masking request failed with HTTP ${response.statusCode}',
          uri: endpoint,
        );
      }
      return parseAiMaskingSuggestions(body);
    } finally {
      client.close(force: true);
    }
  }
}

/// Builds the chat-completion request body. The system message pins the strict
/// JSON output contract (the parser depends on it) and appends the user-editable
/// global task prompt ([AiConfigSnapshot.prompt]). Top-level + visible so the
/// payload — and that the prompt flows into it — is unit-testable.
Map<String, Object?> buildAiMaskingPayload({
  required List<AiPageCandidate> candidates,
  required AiConfigSnapshot config,
  required Uri url,
}) =>
    {
      'model': config.model,
      'temperature': 0.1,
      'messages': [
        {
          'role': 'system',
          'content': 'Return strict JSON only: '
              '{"suggestions":[{"selector":"CSS selector","label":"short label",'
              '"reason":"why this should be hidden","confidence":0.0}]}. '
              '${config.prompt}',
        },
        {
          'role': 'user',
          'content': jsonEncode({
            'url': url.toString(),
            'candidates':
                candidates.map((candidate) => candidate.toJson()).toList(),
          }),
        },
      ],
    };

List<AiMaskingSuggestion> parseAiMaskingSuggestions(String rawBody) {
  final decoded = jsonDecode(rawBody);
  return _suggestionsFromDecoded(decoded) ??
      _suggestionsFromChoiceContent(decoded) ??
      const [];
}

String? _firstChoiceContent(Object? decoded) {
  return switch (decoded) {
    {'choices': final List choices} when choices.isNotEmpty =>
      _choiceContent(choices.first),
    _ => null,
  };
}

String? _choiceContent(Object? choice) {
  return switch (choice) {
    {'message': {'content': final String content}} => content,
    {'text': final String text} => text,
    _ => null,
  };
}

List<AiMaskingSuggestion>? _suggestionsFromDecoded(Object? decoded) {
  final rawSuggestions = switch (decoded) {
    final List suggestions => suggestions,
    {'suggestions': final List suggestions} => suggestions,
    _ => null,
  };
  if (rawSuggestions is! List) return null;
  return rawSuggestions
      .map(AiMaskingSuggestion.tryParse)
      .whereType<AiMaskingSuggestion>()
      .toList();
}

List<AiMaskingSuggestion>? _suggestionsFromChoiceContent(Object? decoded) {
  final content = _firstChoiceContent(decoded);
  if (content == null) return null;

  final extracted = _extractJsonObject(content);
  if (extracted == null) return null;

  final nested = _tryJsonDecode(extracted);
  return _suggestionsFromDecoded(nested);
}

String? _extractJsonObject(String content) {
  final fenced =
      RegExp(r'```(?:json)?\s*([\s\S]*?)\s*```').firstMatch(content)?.group(1);
  if (fenced != null) return fenced;
  final start = content.indexOf('{');
  final end = content.lastIndexOf('}');
  if (start < 0 || end <= start) return null;
  return content.substring(start, end + 1);
}

Object? _tryJsonDecode(String raw) {
  try {
    return jsonDecode(raw);
  } on FormatException {
    return null;
  }
}

int _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.round();
  return 0;
}

double _asDouble(Object? value) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return 0;
}
