// lib/core/data/repositories/settings_repository.dart

import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as path;
import '../models/restaurant_settings_model.dart';
import '../services/data_persistence_manager.dart';

class SettingsRepository {
  final DataPersistenceManager persistence;

  SettingsRepository(this.persistence);

  /// Get restaurant settings
  Future<RestaurantSettingsModel> getRestaurantSettings() async {
    if (!persistence.isEnabled) {
      return RestaurantSettingsModel.defaultSettings();
    }

    final results = await persistence.sqliteManager.query(
      'restaurant_settings',
      limit: 1,
    );

    if (results.isEmpty) {
      final defaultSettings = RestaurantSettingsModel.defaultSettings();
      await _saveSettings(defaultSettings);
      return defaultSettings;
    }

    var model = RestaurantSettingsModel.fromSQLite(results.first);
    if (model.restaurantName == 'GrillPOS Store') {
      model = model.copyWith(restaurantName: 'GrillPOS');
      await _saveSettings(model);
    }

    return model;
  }

  /// Update restaurant settings
  Future<void> updateRestaurantSettings({
    String? restaurantName,
    String? restaurantAddress,
    String? restaurantPhone,
    String? restaurantEmail,
    double? taxRate,
    String? currency,
    String? invoicePrefix,
  }) async {
    final current = await getRestaurantSettings();
    final updated = current.copyWith(
      restaurantName: restaurantName,
      restaurantAddress: restaurantAddress,
      restaurantPhone: restaurantPhone,
      restaurantEmail: restaurantEmail,
      taxRate: taxRate,
      currency: currency,
      invoicePrefix: invoicePrefix,
    );

    await _saveSettings(updated);
  }

  /// Update restaurant logo
  Future<void> updateRestaurantLogo(File logoFile) async {
    final current = await getRestaurantSettings();

    final logoDir = Directory(path.join(persistence.pathResolver.assetsPath));
    await logoDir.create(recursive: true);

    final extension = path.extension(logoFile.path);
    final logoPath = path.join(logoDir.path, 'restaurant_logo$extension');

    await logoFile.copy(logoPath);

    final updated = current.copyWith(logoPath: logoPath);
    await _saveSettings(updated);
  }

  /// Update logo from bytes
  Future<void> updateRestaurantLogoFromBytes(
    Uint8List logoBytes,
    String extension,
  ) async {
    final current = await getRestaurantSettings();

    final logoDir = Directory(path.join(persistence.pathResolver.assetsPath));
    await logoDir.create(recursive: true);

    final logoPath = path.join(logoDir.path, 'restaurant_logo$extension');
    final logoFile = File(logoPath);
    await logoFile.writeAsBytes(logoBytes);

    final updated = current.copyWith(logoPath: logoPath);
    await _saveSettings(updated);
  }

  /// Remove restaurant logo
  Future<void> removeRestaurantLogo() async {
    final current = await getRestaurantSettings();

    if (current.logoPath != null) {
      final logoFile = File(current.logoPath!);
      if (await logoFile.exists()) {
        await logoFile.delete();
      }
    }

    final updated = current.copyWith(logoPath: '');
    await _saveSettings(updated);
  }

  Future<void> _saveSettings(RestaurantSettingsModel settings) async {
    if (!persistence.isEnabled) return;

    await persistence.writeImmediate(
      operation: 'UPDATE',
      entity: 'restaurant_settings',
      id: settings.id,
      data: settings.toJson(),
      sqliteWrite: () async {
        final existing = await persistence.sqliteManager.query(
          'restaurant_settings',
          where: 'id = ?',
          whereArgs: [settings.id],
        );

        if (existing.isEmpty) {
          await persistence.sqliteManager.insert(
            'restaurant_settings',
            settings.toSQLite(),
          );
        } else {
          await persistence.sqliteManager.update(
            'restaurant_settings',
            settings.toSQLite(),
            where: 'id = ?',
            whereArgs: [settings.id],
          );
        }
      },
    );
  }

  /// Get next invoice number
  Future<String> getNextInvoiceNumber() async {
    final current = await getRestaurantSettings();
    final nextNumber = current.lastInvoiceNumber + 1;
    final invoiceNumber = current.generateNextInvoiceNumber();

    if (persistence.isEnabled) {
      final updated = current.copyWith(lastInvoiceNumber: nextNumber);
      await _saveSettings(updated);
    }

    return invoiceNumber;
  }
}
