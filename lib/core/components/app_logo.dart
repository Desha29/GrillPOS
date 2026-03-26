import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../features/settings/presentation/cubit/settings_cubit.dart';
import '../../features/settings/presentation/cubit/settings_states.dart';
import '../di/dependency_injection.dart';

class AppLogo extends StatelessWidget {
  final double width;
  final double height;
  final BoxFit fit;

  const AppLogo({
    super.key,
    this.width = 100,
    this.height = 100,
    this.fit = BoxFit.contain,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsCubit, SettingsStates>(
      bloc: getIt<SettingsCubit>(),
      builder: (context, state) {
        final restaurantInfo = getIt<SettingsCubit>().currentRestaurantInfo;

        if (restaurantInfo != null &&
            restaurantInfo.logoPath != null &&
            restaurantInfo.logoPath!.isNotEmpty) {
          final file = File(restaurantInfo.logoPath!);
          if (file.existsSync()) {
            return Image.file(
              file,
              key: ValueKey(file.lastModifiedSync().millisecondsSinceEpoch),
              width: width,
              height: height,
              fit: fit,
              errorBuilder: (_, __, ___) => _buildAssetLogo(),
            );
          }
        }
        return _buildAssetLogo();
      },
    );
  }

  Widget _buildAssetLogo() {
    return Image.asset(
      'assets/images/grillpos/logo_icon.png',
      width: width,
      height: height,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => Image.asset(
        'assets/images/grillpos/logo_full.png',
        width: width,
        height: height,
        fit: BoxFit.contain,
      ),
    );
  }
}
