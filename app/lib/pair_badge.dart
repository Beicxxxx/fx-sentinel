import 'package:flutter/material.dart';

import 'currencies.dart';
import 'models.dart';

class PairBadge extends StatelessWidget {
  const PairBadge({super.key, required this.pair, this.size = 44});

  final Pair pair;
  final double size;

  @override
  Widget build(BuildContext context) {
    final overlap = size * 0.38;
    return SizedBox(
      width: size * 2 - overlap,
      height: size,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            child: _FlagDisc(code: pair.base, size: size, ring: true),
          ),
          Positioned(
            left: size - overlap,
            child: _FlagDisc(code: pair.quote, size: size, ring: true),
          ),
        ],
      ),
    );
  }
}

class _FlagDisc extends StatelessWidget {
  const _FlagDisc({required this.code, required this.size, required this.ring});
  final String code;
  final double size;
  final bool ring;

  @override
  Widget build(BuildContext context) {
    final info = currencyOf(code);
    final flag = info?.flag ?? '';
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFF0B1020), width: ring ? 2 : 0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: flag.isEmpty
          ? _Fallback(code: code)
          : Image.network(
              'https://flagcdn.com/w80/$flag.png',
              fit: BoxFit.cover,
              width: size,
              height: size,
              errorBuilder: (_, error, stack) => _Fallback(code: code),
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return _Fallback(code: code);
              },
            ),
    );
  }
}

class _Fallback extends StatelessWidget {
  const _Fallback({required this.code});
  final String code;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF1E2A4A),
      child: Center(
        child: Text(
          code.length >= 2 ? code.substring(0, 2) : code,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF7EE0C3)),
        ),
      ),
    );
  }
}
