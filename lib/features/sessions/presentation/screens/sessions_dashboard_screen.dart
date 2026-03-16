import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/components/screen_header.dart';
import 'session_history_screen.dart';

class SessionsDashboardScreen extends StatelessWidget {
  const SessionsDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 1024;

    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(isDesktop ? 32 : 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ScreenHeader(
                title: 'سجل الجلسات',
                subtitle: 'عرض وإدارة جلسات النظام والتقارير اليومية',
                icon: LucideIcons.history,
                onBackPressed: () => Navigator.pop(context),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.surfaceDark,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.borderColor),
                    ),
                    child: const SessionHistoryScreen(isEmbedded: true),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
