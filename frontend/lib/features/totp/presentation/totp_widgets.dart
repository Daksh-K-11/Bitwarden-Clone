import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/common_widgets.dart';
import '../domain/totp.dart';

/// Ticks once per second while mounted. Codes are computed on demand and
/// never stored.
class TotpTicker extends StatefulWidget {
  const TotpTicker({super.key, required this.builder});
  final Widget Function(BuildContext context, DateTime now) builder;
  @override
  State<TotpTicker> createState() => _TotpTickerState();
}

class _TotpTickerState extends State<TotpTicker> {
  late Timer _t;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 1), (_) => setState(() => _now = DateTime.now()));
  }

  @override
  void dispose() {
    _t.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _now);
}

class CountdownRing extends StatelessWidget {
  const CountdownRing({super.key, required this.remaining, required this.period, this.size = 28});
  final int remaining;
  final int period;
  final double size;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final urgent = remaining <= 5;
    return SizedBox.square(
      dimension: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: remaining / period,
            strokeWidth: 3,
            color: urgent ? s.error : s.primary,
            backgroundColor: s.surfaceContainerHighest,
          ),
          Text('$remaining', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: urgent ? s.error : null)),
        ],
      ),
    );
  }
}

/// Large live code with countdown and copy.
class TotpCodeView extends ConsumerWidget {
  const TotpCodeView({super.key, required this.config, this.compact = false});
  final TotpConfig config;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) => TotpTicker(
    builder: (context, now) {
      final code = config.codeAt(now);
      final remaining = config.secondsRemaining(now);
      final style = (compact ? Theme.of(context).textTheme.titleLarge : Theme.of(context).textTheme.headlineSmall)
          ?.copyWith(
            fontFamily: 'monospace',
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
            color: Theme.of(context).colorScheme.primary,
          );
      return InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => copySecret(context, ref, config.codeAt(DateTime.now()), 'Verification code'),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(formatTotpCode(code), style: style),
              const SizedBox(width: 12),
              CountdownRing(remaining: remaining, period: config.period),
              const SizedBox(width: 4),
              const Icon(Icons.copy_rounded, size: 18),
            ],
          ),
        ),
      );
    },
  );
}
