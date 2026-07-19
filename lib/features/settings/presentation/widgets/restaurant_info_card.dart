import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/components/app_logo.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/functions/messege.dart';
import '../../data/models/restaurant_info_model.dart';
import '../cubit/settings_cubit.dart';
import '../cubit/settings_states.dart';
import 'edit_restaurant_info_dialog.dart';

class RestaurantInfoCard extends StatelessWidget {
  const RestaurantInfoCard({super.key, required this.isMobile});

  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<SettingsCubit, SettingsStates>(
      listener: (context, state) {
        if (state is RestaurantInfoUpdateSuccess) {
          MotionSnackBarSuccess(context, state.message);
        } else if (state is RestaurantInfoUpdateFailure) {
          MotionSnackBarError(context, state.message);
        }
      },
      builder: (context, state) {
        final cubit = SettingsCubit.get(context);
        final loading = state is SettingsLoading;
        final restaurant = state is RestaurantInfoLoaded
            ? state.restaurantInfo
            : cubit.currentRestaurantInfo;

        return Container(
          padding: EdgeInsets.all(isMobile ? 16 : 20),
          decoration: BoxDecoration(
            color: AppColors.surfaceDark,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _CardHeader(
                canEdit: cubit.isAdmin() && restaurant != null,
                loading: loading,
                onEdit: restaurant == null
                    ? null
                    : () => _showEditDialog(context, restaurant.toMap()),
              ),
              const SizedBox(height: 18),
              if (loading && restaurant == null)
                const SizedBox(
                  height: 260,
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                )
              else if (restaurant == null)
                _EmptyRestaurantState(
                  onRetry: () => cubit.loadRestaurantInfo(),
                )
              else
                LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 620;
                    final brand = _RestaurantBrand(
                      restaurant: restaurant,
                      canEdit: cubit.isAdmin(),
                      onPickImage: () => _pickImage(context, restaurant),
                    );
                    final details = _RestaurantDetails(
                      restaurant: restaurant,
                      wide: wide,
                    );

                    if (wide) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(width: 185, child: brand),
                          const SizedBox(width: 18),
                          Expanded(child: details),
                        ],
                      );
                    }
                    return Column(
                      children: [
                        brand,
                        const SizedBox(height: 18),
                        details,
                      ],
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showEditDialog(
    BuildContext context,
    Map<String, String> restaurant,
  ) async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => EditRestaurantInfoDialog(restaurantInfo: restaurant),
    );
    if (result != null && context.mounted) {
      SettingsCubit.get(context).updateRestaurantInfo(result);
    }
  }

  Future<void> _pickImage(
    BuildContext context,
    RestaurantInfo currentInfo,
  ) async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.image);
      if (result == null || result.files.single.path == null) return;
      final updated = currentInfo.toMap();
      updated['logoPath'] = result.files.single.path!;
      if (context.mounted) {
        SettingsCubit.get(context).updateRestaurantInfo(updated);
      }
    } catch (_) {
      if (context.mounted) {
        MotionSnackBarError(context, 'حدث خطأ أثناء اختيار الصورة');
      }
    }
  }
}

class _CardHeader extends StatelessWidget {
  const _CardHeader({
    required this.canEdit,
    required this.loading,
    required this.onEdit,
  });

  final bool canEdit;
  final bool loading;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.warmOrange.withValues(alpha: .1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            LucideIcons.store,
            color: AppColors.warmOrange,
            size: 20,
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'هوية المطعم',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                'البيانات التي تظهر في الفواتير والتقارير',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 10.5,
                ),
              ),
            ],
          ),
        ),
        if (canEdit)
          OutlinedButton.icon(
            onPressed: loading ? null : onEdit,
            icon: const Icon(LucideIcons.pencil, size: 15),
            label: const Text('تعديل'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.warmOrange,
              side: BorderSide(
                color: AppColors.warmOrange.withValues(alpha: .3),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
            ),
          ),
      ],
    );
  }
}

class _RestaurantBrand extends StatelessWidget {
  const _RestaurantBrand({
    required this.restaurant,
    required this.canEdit,
    required this.onPickImage,
  });

  final RestaurantInfo restaurant;
  final bool canEdit;
  final VoidCallback onPickImage;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.warmOrange.withValues(alpha: .09),
            AppColors.charcoalLight,
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.warmOrange.withValues(alpha: .13),
        ),
      ),
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 94,
                height: 94,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: AppColors.warmOrange.withValues(alpha: .24),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: .08),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const ClipRRect(
                  borderRadius: BorderRadius.all(Radius.circular(17)),
                  child: AppLogo(fit: BoxFit.contain),
                ),
              ),
              if (canEdit)
                PositionedDirectional(
                  end: -6,
                  bottom: -5,
                  child: Tooltip(
                    message: 'تغيير الشعار',
                    child: Material(
                      color: AppColors.warmOrange,
                      shape: const CircleBorder(),
                      child: InkWell(
                        onTap: onPickImage,
                        customBorder: const CircleBorder(),
                        child: const Padding(
                          padding: EdgeInsets.all(8),
                          child: Icon(
                            LucideIcons.camera,
                            size: 15,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 13),
          Text(
            restaurant.name.isEmpty ? 'اسم المطعم' : restaurant.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.successGreen.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'الملف نشط',
              style: TextStyle(
                color: AppColors.successGreen,
                fontSize: 9,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RestaurantDetails extends StatelessWidget {
  const _RestaurantDetails({required this.restaurant, required this.wide});

  final RestaurantInfo restaurant;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final details = [
      (LucideIcons.mapPin, 'العنوان', restaurant.address),
      (LucideIcons.phone, 'رقم الهاتف', restaurant.phone),
      (LucideIcons.mail, 'البريد الإلكتروني', restaurant.email),
      (LucideIcons.badgePercent, 'الرقم الضريبي', restaurant.vat),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = wide ? 2 : 1;
        final gap = 10.0;
        final tileWidth = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final detail in details)
              SizedBox(
                width: tileWidth,
                child: _InfoTile(
                  icon: detail.$1,
                  label: detail.$2,
                  value: detail.$3,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 78,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: AppColors.charcoalLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.warmOrange.withValues(alpha: .08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.warmOrange, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 9.5),
                ),
                const SizedBox(height: 3),
                Text(
                  value.trim().isEmpty ? 'غير مسجل' : value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: value.trim().isEmpty
                        ? AppColors.mutedColor
                        : AppColors.textPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyRestaurantState extends StatelessWidget {
  const _EmptyRestaurantState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 240,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.store, color: AppColors.mutedColor, size: 34),
            const SizedBox(height: 10),
            Text(
              'تعذر تحميل معلومات المطعم',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            TextButton(onPressed: onRetry, child: const Text('إعادة المحاولة')),
          ],
        ),
      ),
    );
  }
}
