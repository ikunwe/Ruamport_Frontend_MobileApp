import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/panel.dart';
import '../../shared/widgets/avatar_image.dart';
import '../import/pdf_preview_view.dart';
import 'portfolio_data.dart';

String amount(double? value, [String currency = 'THB']) =>
    pdfMoney(value, currency);
String signedAmount(double? value, [String currency = 'THB']) =>
    value == null ? '—' : '${value > 0 ? '+' : ''}${amount(value, currency)}';
String percentage(double? value) =>
    value == null ? '—' : '${value > 0 ? '+' : ''}${pdfNumber(value)}%';
String allocationPercent(double? value, double? total) {
  final share = ratioPercent(value, total);
  return share == null ? '—' : '${pdfNumber(share, 1)}%';
}

Color? profitColor(double? value) => value == null || value == 0
    ? null
    : value > 0
    ? lime
    : loss;

class LivePnl extends StatelessWidget {
  const LivePnl(
    this.value, {
    super.key,
    this.percent,
    this.currency = 'THB',
    this.size = 13,
  });
  final double? value, percent;
  final String currency;
  final double size;
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 5,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      if (value != null)
        Icon(
          value! >= 0 ? Icons.trending_up : Icons.trending_down,
          color: profitColor(value),
          size: size + 3,
        ),
      Text(
        signedAmount(value, currency),
        style: TextStyle(
          fontSize: size,
          color: profitColor(value),
          fontWeight: FontWeight.w600,
        ),
      ),
      if (percent != null)
        Text(
          '(${percentage(percent)})',
          style: TextStyle(fontSize: size - 2, color: profitColor(value)),
        ),
    ],
  );
}

class HoldingLogo extends StatelessWidget {
  const HoldingLogo(this.holding, {super.key, this.size = 38});
  final Holding holding;
  final double size;
  @override
  Widget build(BuildContext context) {
    final uri = Uri.tryParse(holding.logoUrl?.trim() ?? '');
    Widget fallback() => Center(
      child: Text(
        holding.symbol.substring(0, 1),
        style: TextStyle(
          color: lime,
          fontSize: size * .45,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
    return Semantics(
      label: holding.type == 'MUTUAL_FUND'
          ? 'โลโก้ บลจ. ${holding.symbol}'
          : 'โลโก้ ${holding.symbol}',
      image: true,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: size,
          height: size,
          color: lime.withValues(alpha: .08),
          child: uri == null || uri.scheme != 'https'
              ? fallback()
              : AvatarImage(
                  key: ValueKey(uri.toString()),
                  url: uri.toString(),
                  size: size,
                  fit: BoxFit.contain,
                  fallback: fallback(),
                ),
        ),
      ),
    );
  }
}

class DataNotice extends StatelessWidget {
  const DataNotice(this.message, {super.key, this.retry, this.loading = false});
  final String message;
  final VoidCallback? retry;
  final bool loading;
  @override
  Widget build(BuildContext context) => Panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (loading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(12),
              child: CircularProgressIndicator(),
            ),
          ),
        Text(
          message,
          style: const TextStyle(fontSize: 12, color: Colors.white54),
        ),
        if (retry != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: loading ? null : retry,
              child: const Text('ลองใหม่'),
            ),
          ),
      ],
    ),
  );
}
