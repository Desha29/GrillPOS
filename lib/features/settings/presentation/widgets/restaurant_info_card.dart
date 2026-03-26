// restaurant_info_card.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:file_picker/file_picker.dart';
import 'package:grill_pos/core/components/app_logo.dart';
import '../../../../core/components/section_card.dart';

import '../../../../core/functions/messege.dart';
import '../../data/models/restaurant_info_model.dart';
import '../cubit/settings_cubit.dart';
import '../cubit/settings_states.dart';
import 'edit_restaurant_info_dialog.dart';

import 'package:grill_pos/core/constants/app_colors.dart';

class RestaurantInfoCard extends StatelessWidget {
  const RestaurantInfoCard({
    super.key,
    required this.isMobile,
  });

  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
        final isLoading = state is SettingsLoading;

        RestaurantInfo? restaurant;
        if (state is RestaurantInfoLoaded) {
          restaurant = state.restaurantInfo;
        } else if (!isLoading) {
          try {
            restaurant = cubit.currentRestaurantInfo;
          } catch (e) {
            restaurant = null;
          }
        }

        return SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    LucideIcons.chefHat,
                    size: 18,
                    color: AppColors.mutedColor,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'معلومات المطعم',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (cubit.isAdmin() && restaurant != null)
                    IconButton(
                      onPressed: isLoading
                          ? null
                          : () => _showEditDialog(
                              context, restaurant!.toMap()),
                      icon: const Icon(LucideIcons.edit2, size: 16),
                      tooltip: 'تعديل معلومات المطعم',
                    ),
                ],
              ),
              SizedBox(height: isMobile ? 12 : 16),
              if (isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (restaurant != null)
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth > 700;
                    return Column(
                      children: [
                        Center(
                          child: Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(50),
                                child: const AppLogo(
                                    width: 120, height: 120, fit: BoxFit.cover),
                              ),
                              if (cubit.isAdmin())
                                GestureDetector(
                                  onTap: () => _pickImage(context, restaurant!),
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: AppColors.warmOrange,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: Colors.white, width: 2),
                                    ),
                                    child: const Icon(LucideIcons.camera,
                                        size: 16, color: Colors.white),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (isWide)
                          Wrap(
                            spacing: 16,
                            runSpacing: 12,
                            children: [
                              _RestaurantInfoRow(
                                  icon: LucideIcons.chefHat,
                                  label: 'اسم المطعم',
                                  value: restaurant!.name,
                                  theme: theme),
                              _RestaurantInfoRow(
                                  icon: LucideIcons.mapPin,
                                  label: 'العنوان',
                                  value: restaurant.address,
                                  theme: theme),
                              _RestaurantInfoRow(
                                  icon: LucideIcons.phone,
                                  label: 'رقم الهاتف',
                                  value: restaurant.phone,
                                  theme: theme),
                              _RestaurantInfoRow(
                                  icon: LucideIcons.mail,
                                  label: 'البريد الإلكتروني',
                                  value: restaurant.email,
                                  theme: theme),
                              _RestaurantInfoRow(
                                  icon: LucideIcons.fileText,
                                  label: 'الرقم الضريبي',
                                  value: restaurant.vat,
                                  theme: theme),
                            ]
                                .map((row) => SizedBox(
                                    width: (constraints.maxWidth - 16) / 2,
                                    child: row))
                                .toList(),
                          )
                        else
                          Column(
                            children: [
                              _RestaurantInfoRow(
                                  icon: LucideIcons.chefHat,
                                  label: 'اسم المطعم',
                                  value: restaurant!.name,
                                  theme: theme),
                              _RestaurantInfoRow(
                                  icon: LucideIcons.mapPin,
                                  label: 'العنوان',
                                  value: restaurant.address,
                                  theme: theme),
                              _RestaurantInfoRow(
                                  icon: LucideIcons.phone,
                                  label: 'رقم الهاتف',
                                  value: restaurant.phone,
                                  theme: theme),
                              _RestaurantInfoRow(
                                  icon: LucideIcons.mail,
                                  label: 'البريد الإلكتروني',
                                  value: restaurant.email,
                                  theme: theme),
                              _RestaurantInfoRow(
                                  icon: LucideIcons.fileText,
                                  label: 'الرقم الضريبي',
                                  value: restaurant.vat,
                                  theme: theme),
                            ]
                                .map((row) => Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: row))
                                .toList(),
                          ),
                      ],
                    );
                  },
                )
              else
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Text('لا توجد معلومات للمطعم'),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _showEditDialog(
      BuildContext context, Map<String, String> restaurant) async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) =>
          EditRestaurantInfoDialog(restaurantInfo: restaurant),
    );

    if (result != null && context.mounted) {
      SettingsCubit.get(context).updateRestaurantInfo(result);
    }
  }

  void _pickImage(BuildContext context, RestaurantInfo currentInfo) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
      );

      if (result != null && result.files.single.path != null) {
        final newPath = result.files.single.path!;

        final updatedMap = currentInfo.toMap();
        updatedMap['logoPath'] = newPath;

        if (context.mounted) {
          SettingsCubit.get(context).updateRestaurantInfo(updatedMap);
        }
      }
    } catch (e) {
      if (context.mounted) {
        MotionSnackBarError(context, "حدث خطأ أثناء اختيار الصورة");
      }
    }
  }
}

class _RestaurantInfoRow extends StatelessWidget {
  const _RestaurantInfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.theme,
  });

  final IconData icon;
  final String label;
  final String value;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: AppColors.mutedColor,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.mutedColor,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
