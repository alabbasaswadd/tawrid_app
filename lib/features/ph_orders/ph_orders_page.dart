import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawrid_app/app/theme/app_spacing.dart';
import 'package:tawrid_app/app/theme/app_tokens_ext.dart';

class PhOrdersPage extends ConsumerWidget {
  const PhOrdersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tk = context.tokens;
    return Scaffold(
      appBar: AppBar(title: const Text('طلبيات التوريد')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {},
        icon: const Icon(Icons.add),
        label: const Text('طلبية جديدة'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.local_shipping_outlined, size: 64, color: tk.hint),
              const SizedBox(height: AppSpacing.md),
              Text('لا توجد طلبيات',
                  style: context.text.titleMedium?.copyWith(color: tk.hint)),
              const SizedBox(height: AppSpacing.xs),
              Text('ابدأ بإنشاء طلبية توريد جديدة',
                  style: context.text.bodySmall?.copyWith(color: tk.hint)),
            ],
          ),
        ),
      ),
    );
  }
}
