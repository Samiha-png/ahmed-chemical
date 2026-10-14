import 'package:flutter/material.dart';

import '../services/inventory_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class MovementTypeChip extends StatelessWidget {
  final MovementType type;
  const MovementTypeChip({super.key, required this.type});

  @override
  Widget build(BuildContext context) {
    late Color color;
    switch (type) {
      case MovementType.receipt:
        color = AppColors.primary;
        break;
      case MovementType.issue:
        color = AppColors.warning;
        break;
      case MovementType.transferIn:
        color = AppColors.info;
        break;
      case MovementType.transferOut:
        color = AppColors.info;
        break;
      case MovementType.adjustment:
        color = AppColors.error;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        movementTypeLabel(type),
        style: AppTextStyles.caption.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class QtyText extends StatelessWidget {
  final num value;
  final String unit;
  const QtyText({super.key, required this.value, required this.unit});

  @override
  Widget build(BuildContext context) {
    final positive = value >= 0;
    return Text(
      '${positive ? '+' : ''}${value.toStringAsFixed(2)} $unit',
      style: AppTextStyles.bodyMedium.copyWith(
        fontWeight: FontWeight.w600,
        color: positive ? AppColors.primary : AppColors.error,
      ),
    );
  }
}