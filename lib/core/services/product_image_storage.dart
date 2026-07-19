import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;

import '../constants/app_colors.dart';
import '../data/services/persistence_initializer.dart';

/// Stores product images inside the configured persistent GrillPOS data folder.
///
/// Menu records always point at the copied file, never at the user's original
/// source file. This keeps images available after the source is moved or
/// removed.
class ProductImageStorage {
  ProductImageStorage._();

  static const int maxImageBytes = 10 * 1024 * 1024;

  static String get productImagesDirectory {
    final manager = PersistenceInitializer.persistenceManager;
    if (manager == null) {
      throw StateError('لم يتم تهيئة مسار بيانات GrillPOS بعد');
    }
    return path.join(manager.pathResolver.assetsPath, 'product_images');
  }

  /// Opens the platform image picker and copies the selection into
  /// `GrillPOSData/assets/product_images`.
  ///
  /// Returns `null` when the user cancels.
  static Future<String?> pickAndStoreImage() async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'اختر صورة الصنف',
      type: FileType.image,
      allowMultiple: false,
      withData: true,
      lockParentWindow: true,
    );
    if (result == null || result.files.isEmpty) return null;

    final selected = result.files.single;
    if (selected.size > maxImageBytes) {
      throw const FileSystemException(
        'حجم الصورة أكبر من 10 ميجابايت. اختر صورة أصغر.',
      );
    }

    final directory = Directory(productImagesDirectory);
    await directory.create(recursive: true);

    final rawExtension = selected.extension ??
        (selected.path == null ? null : path.extension(selected.path!));
    final extension = _normalizedExtension(rawExtension);
    final originalStem = path.basenameWithoutExtension(selected.name);
    final safeStem = originalStem
        .replaceAll(RegExp(r'[^a-zA-Z0-9_-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    final fileName =
        'product_${DateTime.now().microsecondsSinceEpoch}_${safeStem.isEmpty ? 'image' : safeStem}.$extension';
    final destination = File(path.join(directory.path, fileName));

    final sourcePath = selected.path;
    if (sourcePath != null && await File(sourcePath).exists()) {
      await File(sourcePath).copy(destination.path);
    } else if (selected.bytes != null) {
      await destination.writeAsBytes(selected.bytes!, flush: true);
    } else {
      throw const FileSystemException('تعذر قراءة ملف الصورة المحدد');
    }

    return path.normalize(destination.absolute.path);
  }

  /// Deletes an internally managed image only when no menu item references it.
  /// External paths and remote URLs are never touched.
  static Future<void> deleteIfUnreferenced(String? source) async {
    if (source == null || source.trim().isEmpty || !isManagedImage(source)) {
      return;
    }

    final manager = PersistenceInitializer.persistenceManager;
    if (manager == null) return;

    try {
      final references = await manager.sqliteManager.database.rawQuery(
        'SELECT COUNT(*) AS count FROM menu_items WHERE image_url = ?',
        [source],
      );
      final count = (references.firstOrNull?['count'] as num?)?.toInt() ?? 0;
      if (count > 0) return;

      final localPath = _localPath(source);
      if (localPath == null) return;
      final file = File(localPath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // Image cleanup is best-effort. A locked old image must never make an
      // otherwise successful menu save fail.
    }
  }

  static bool isManagedImage(String source) {
    final localPath = _localPath(source);
    if (localPath == null) return false;

    try {
      final directory = path.normalize(
        path.absolute(productImagesDirectory),
      );
      final candidate = path.normalize(path.absolute(localPath));
      if (Platform.isWindows) {
        final lowerDirectory = directory.toLowerCase();
        final lowerCandidate = candidate.toLowerCase();
        return lowerCandidate == lowerDirectory ||
            path.isWithin(lowerDirectory, lowerCandidate);
      }
      return candidate == directory || path.isWithin(directory, candidate);
    } catch (_) {
      return false;
    }
  }

  static String _normalizedExtension(String? rawExtension) {
    final extension =
        (rawExtension ?? '').replaceFirst('.', '').trim().toLowerCase();
    return const {'jpg', 'jpeg', 'png', 'webp', 'gif', 'bmp'}
            .contains(extension)
        ? extension
        : 'jpg';
  }

  static String? _localPath(String source) {
    final trimmed = source.trim();
    if (trimmed.isEmpty) return null;
    final uri = Uri.tryParse(trimmed);
    if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
      return null;
    }
    if (uri != null && uri.scheme == 'file') {
      try {
        return uri.toFilePath(windows: Platform.isWindows);
      } catch (_) {
        return null;
      }
    }
    return trimmed;
  }
}

/// Safely renders persisted local files and HTTP(S) product images.
class ProductImageView extends StatelessWidget {
  const ProductImageView({
    super.key,
    required this.source,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.semanticLabel,
  });

  final String? source;
  final BoxFit fit;
  final Widget? placeholder;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final fallback = placeholder ?? const ProductImagePlaceholder();
    final value = source?.trim();
    if (value == null || value.isEmpty) return fallback;

    final uri = Uri.tryParse(value);
    if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
      return Image.network(
        value,
        fit: fit,
        semanticLabel: semanticLabel,
        errorBuilder: (_, __, ___) => fallback,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return Stack(
            fit: StackFit.expand,
            children: [
              fallback,
              Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.warmOrange,
                    value: progress.expectedTotalBytes == null
                        ? null
                        : progress.cumulativeBytesLoaded /
                            progress.expectedTotalBytes!,
                  ),
                ),
              ),
            ],
          );
        },
      );
    }

    if (kIsWeb) return fallback;
    final localPath = uri?.scheme == 'file' ? _safeFileUriPath(uri!) : value;
    if (localPath == null || !File(localPath).existsSync()) return fallback;

    return Image.file(
      File(localPath),
      fit: fit,
      semanticLabel: semanticLabel,
      gaplessPlayback: true,
      errorBuilder: (_, __, ___) => fallback,
    );
  }

  static String? _safeFileUriPath(Uri uri) {
    try {
      return uri.toFilePath(windows: Platform.isWindows);
    } catch (_) {
      return null;
    }
  }
}

class ProductImagePlaceholder extends StatelessWidget {
  const ProductImagePlaceholder({
    super.key,
    this.iconSize = 32,
    this.iconColor,
  });

  final double iconSize;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.warmOrange.withOpacity(.12),
            AppColors.ember.withOpacity(.05),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.restaurant_rounded,
          size: iconSize,
          color: iconColor ?? AppColors.warmOrange.withOpacity(.7),
        ),
      ),
    );
  }
}
