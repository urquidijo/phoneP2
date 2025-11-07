import 'package:flutter/material.dart';

class KpiPill extends StatelessWidget {
  const KpiPill({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    this.helper,
  });

  final IconData icon;
  final String value;
  final String label;
  final String? helper;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant.withOpacity(.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: cs.onPrimaryContainer),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // valor grande, apretado
              Text(
                value,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Text(label, style: Theme.of(context).textTheme.labelMedium),
                  if (helper != null) ...[
                    const SizedBox(width: 6),
                    Text(
                      '· ${helper!}',
                      style: Theme.of(
                        context,
                      ).textTheme.labelSmall?.copyWith(color: cs.outline),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
