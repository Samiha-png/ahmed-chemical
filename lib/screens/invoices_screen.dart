import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/empty_state.dart';

class InvoicesScreen extends StatelessWidget {
  const InvoicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Invoices', style: AppTextStyles.displayMedium),
          const SizedBox(height: 6),
          Text('Manage sales invoices, customer receipts, and payment tracking.',
            style: AppTextStyles.bodySmall),
          const SizedBox(height: 24),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border)),
              child: const EmptyState(
                icon: LucideIcons.fileText,
                title: 'Coming in Phase 7',
                message: 'Sales invoices, customer receipts, and payment tracking.',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

