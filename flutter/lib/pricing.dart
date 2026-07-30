import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'models.dart';

class ModelPrice {
  final double input, output, cacheRead, cacheWrite; // USD / MTok
  const ModelPrice(
    this.input,
    this.output, [
    this.cacheRead = 0,
    this.cacheWrite = 0,
  ]);
}

/// 定价：内置表兜底 + LiteLLM 在线价格表（缓存 24 小时）。
class Pricing {
  Pricing._();
  static final shared = Pricing._();

  Map<String, ModelPrice> _remote = {};
  DateTime? _loadedAt;

  static const builtin = <(String, ModelPrice)>[
    ('claude-fable-5', ModelPrice(10, 50, 1, 12.5)),
    ('claude-opus-5', ModelPrice(5, 25, 0.5, 6.25)),
    ('claude-opus-4-5', ModelPrice(5, 25, 0.5, 6.25)),
    ('claude-opus-4', ModelPrice(15, 75, 1.5, 18.75)),
    ('claude-sonnet-5', ModelPrice(3, 15, 0.3, 3.75)),
    ('claude-sonnet-4', ModelPrice(3, 15, 0.3, 3.75)),
    ('claude-haiku-4-5', ModelPrice(1, 5, 0.1, 1.25)),
    ('claude', ModelPrice(3, 15, 0.3, 3.75)),
    ('gpt-5-mini', ModelPrice(0.25, 2, 0.025)),
    ('gpt-5-nano', ModelPrice(0.05, 0.4, 0.005)),
    ('codex-mini', ModelPrice(1.5, 6, 0.375)),
    ('gpt-5', ModelPrice(1.25, 10, 0.125)),
    ('gpt', ModelPrice(1.25, 10, 0.125)),
  ];

  ModelPrice priceFor(String model) {
    final m = model.toLowerCase();
    final exact = _remote[m];
    if (exact != null) return exact;
    String? bestKey;
    ModelPrice? bestPrice;
    _remote.forEach((k, p) {
      if ((m.contains(k) || k.contains(m)) &&
          (bestKey == null || k.length > bestKey!.length)) {
        bestKey = k;
        bestPrice = p;
      }
    });
    if (bestPrice != null) return bestPrice!;
    for (final (pattern, p) in builtin) {
      if (m.contains(pattern)) return p;
    }
    return const ModelPrice(3, 15, 0.3, 3.75);
  }

  double cost(String model, TokenTally t) {
    final p = priceFor(model);
    return (t.input * p.input +
            t.output * p.output +
            t.cacheRead * p.cacheRead +
            t.cacheWrite * p.cacheWrite) /
        1e6;
  }

  static File get _cacheFile {
    final home =
        Platform.environment['USERPROFILE'] ??
        Platform.environment['HOME'] ??
        '.';
    return File('$home/.aiusage/litellm-prices.json');
  }

  Future<void> loadRemoteIfNeeded() async {
    if (_loadedAt != null &&
        DateTime.now().difference(_loadedAt!).inHours < 1) {
      return;
    }
    final cache = _cacheFile;
    try {
      if (cache.existsSync() &&
          DateTime.now().difference(cache.lastModifiedSync()).inHours < 24) {
        _apply(cache.readAsStringSync());
        return;
      }
    } catch (_) {}
    try {
      final resp = await http
          .get(
            Uri.parse(
              'https://raw.githubusercontent.com/BerriAI/litellm/main/model_prices_and_context_window.json',
            ),
          )
          .timeout(const Duration(seconds: 20));
      if (resp.statusCode == 200) {
        cache.parent.createSync(recursive: true);
        cache.writeAsStringSync(resp.body);
        _apply(resp.body);
      }
    } catch (_) {
      try {
        if (cache.existsSync()) _apply(cache.readAsStringSync());
      } catch (_) {}
    }
  }

  void _apply(String body) {
    final root = jsonDecode(body);
    if (root is! Map<String, dynamic>) return;
    final table = <String, ModelPrice>{};
    root.forEach((key, value) {
      if (value is! Map) return;
      final inCost = (value['input_cost_per_token'] as num?)?.toDouble();
      final outCost = (value['output_cost_per_token'] as num?)?.toDouble();
      if (inCost == null || outCost == null) return;
      final cr =
          (value['cache_read_input_token_cost'] as num?)?.toDouble() ?? 0;
      final cw =
          (value['cache_creation_input_token_cost'] as num?)?.toDouble() ?? 0;
      final bare = key.toLowerCase().split('/').last;
      table[bare] = ModelPrice(inCost * 1e6, outCost * 1e6, cr * 1e6, cw * 1e6);
    });
    if (table.isNotEmpty) {
      _remote = table;
      _loadedAt = DateTime.now();
    }
  }
}
