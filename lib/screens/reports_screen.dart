import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/empty_state.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Reports', style: AppTextStyles.displayMedium),
          const SizedBox(height: 6),
          Text('Manage sales, purchases, inventory, financial reports, and exports.',
            style: AppTextStyles.bodySmall),
          const SizedBox(height: 24),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border)),
              child: const EmptyState(
                icon: LucideIcons.barChart3,
                title: 'Coming in Phase 9',
                message: 'Sales, purchases, inventory, financial reports, and exports.',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

