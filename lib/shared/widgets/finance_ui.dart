import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/demo/demo_portfolio.dart';
import 'panel.dart';

class PageHeading extends StatelessWidget {
  const PageHeading(this.title, this.subtitle, {super.key, this.action});
  final String title, subtitle;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ],
          ),
        ),
        ?action,
      ],
    ),
  );
}

class DemoTag extends StatelessWidget {
  const DemoTag({super.key});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: const Color(0xFFFFD675).withValues(alpha: .08),
      borderRadius: BorderRadius.circular(8),
    ),
    child: const Text(
      'ข้อมูลตัวอย่าง',
      style: TextStyle(color: Color(0xFFFFD675), fontSize: 10),
    ),
  );
}

class ChoiceStrip extends StatelessWidget {
  const ChoiceStrip({
    super.key,
    required this.labels,
    required this.value,
    required this.onChanged,
  });
  final List<String> labels;
  final String value;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: labels
          .map(
            (label) => Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Semantics(
                selected: value == label,
                button: true,
                child: InkWell(
                  onTap: () => onChanged(label),
                  borderRadius: BorderRadius.circular(8),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: value == label
                          ? Colors.white.withValues(alpha: .09)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: value == label ? Colors.white24 : Colors.white10,
                      ),
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 11,
                        color: value == label ? Colors.white : Colors.white38,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          )
          .toList(),
    ),
  );
}

class PnlText extends StatelessWidget {
  const PnlText(
    this.value, {
    super.key,
    this.currency = 'THB',
    this.percentage,
    this.size = 13,
  });
  final double value, size;
  final double? percentage;
  final String currency;
  @override
  Widget build(BuildContext context) => Wrap(
    crossAxisAlignment: WrapCrossAlignment.center,
    spacing: 5,
    children: [
      Icon(
        value >= 0 ? Icons.trending_up : Icons.trending_down,
        size: size + 3,
        color: value >= 0 ? lime : loss,
      ),
      Text(
        signedMoney(value, currency),
        style: TextStyle(
          color: value >= 0 ? lime : loss,
          fontSize: size,
          fontWeight: FontWeight.w600,
        ),
      ),
      if (percentage != null)
        Text(
          '(${percent(percentage!)})',
          style: TextStyle(color: value >= 0 ? lime : loss, fontSize: size - 2),
        ),
    ],
  );
}

class AssetAvatar extends StatelessWidget {
  const AssetAvatar(this.asset, {super.key, this.size = 38});
  final DemoAsset asset;
  final double size;
  @override
  Widget build(BuildContext context) {
    final color = asset.group == AssetGroup.offshore
        ? lime
        : asset.group == AssetGroup.thai
        ? blue
        : violet;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: .16)),
      ),
      child: Text(
        asset.symbol.substring(0, 1),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: size * .44,
        ),
      ),
    );
  }
}

class SmallStat extends StatelessWidget {
  const SmallStat(this.label, this.value, {super.key, this.color});
  final String label, value;
  final Color? color;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10)),
      const SizedBox(height: 6),
      Text(
        value,
        style: TextStyle(
          color: color ?? Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
    ],
  );
}

class MetricTile extends StatelessWidget {
  const MetricTile(this.label, this.value, {super.key, this.hint, this.color});
  final String label, value;
  final String? hint;
  final Color? color;
  @override
  Widget build(BuildContext context) => Panel(
    padding: 14,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 10),
        ),
        const SizedBox(height: 10),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
        if (hint != null) ...[
          const SizedBox(height: 5),
          Text(
            hint!,
            style: const TextStyle(fontSize: 9, color: Colors.white30),
          ),
        ],
      ],
    ),
  );
}

class FinanceList extends StatelessWidget {
  const FinanceList({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
    children: children
        .map(
          (child) =>
              Padding(padding: const EdgeInsets.only(bottom: 14), child: child),
        )
        .toList(),
  );
}

Widget twoColumns(Widget first, Widget second) => Row(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Expanded(child: first),
    const SizedBox(width: 10),
    Expanded(child: second),
  ],
);
