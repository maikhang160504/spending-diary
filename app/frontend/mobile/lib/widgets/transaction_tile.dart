import 'package:flutter/material.dart';

import '../data/mock_data.dart';
import '../theme/app_colors.dart';

class TransactionTile extends StatelessWidget {
  final TransactionItem item;

  const TransactionTile({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final amountPrefix = item.isIncome ? '+' : '-';
    final amountColor = item.isIncome ? AppColors.success : AppColors.danger;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: AppColors.surface,
        child: Icon(
          item.isIncome ? Icons.arrow_downward : Icons.arrow_upward,
          color: amountColor,
        ),
      ),
      title: Text(item.title, style: Theme.of(context).textTheme.bodyLarge),
      subtitle: Text('${item.category} • ${item.date}'),
      trailing: Text(
        '$amountPrefix${item.amount.toStringAsFixed(2)}',
        style: TextStyle(
          color: amountColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
