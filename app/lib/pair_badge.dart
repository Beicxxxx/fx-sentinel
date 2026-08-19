import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'currencies.dart';
import 'models.dart';

/// Flat circular flags (HatScripts/circle-flags), no photo or drop shadow.
class PairBadge extends StatelessWidget {
  const PairBadge({super.key, required this.pair, this.size = 44});

  final Pair pair;
  final double size;

  @override
  Widget build(BuildContext context) {
    final overlap = size * 0.42;
    return SizedBox(
      width: size * 2 - overlap,
      height: size,
      child: Stack(
        children: [
          Positioned(left: 0, child: FlatFlag(code: pair.base, size: size)),
          Positioned(left: size - overlap, child: FlatFlag(code: pair.quote, size: size)),
        ],
      ),
    );
  }
}

class FlatFlag extends StatelessWidget {
  const FlatFlag({super.key, required this.code, required this.size});

  final String code;
  final double size;

  static const _cdn = 'https://cdn.jsdelivr.net/gh/HatScripts/circle-flags@2.1.2/flags';

  @override
  Widget build(BuildContext context) {
    final iso = currencyOf(code)?.flag ?? '';
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF1A2238),
        border: Border.all(color: const Color(0xFF070B16), width: 2),
      ),
      clipBehavior: Clip.antiAlias,
      child: iso.isEmpty
          ? _Fallback(code: code)
          : SvgPicture.network(
              '$_cdn/$iso.svg',
              width: size,
              height: size,
              fit: BoxFit.cover,
              placeholderBuilder: (_) => _Fallback(code: code),
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
      color: const Color(0xFF243056),
      child: Center(
        child: Text(
          code.length >= 2 ? code.substring(0, 2) : code,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF9AA3C0)),
        ),
      ),
    );
  }
}
