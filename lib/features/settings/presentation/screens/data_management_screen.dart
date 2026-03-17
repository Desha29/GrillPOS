import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:lucide_icons/lucide_icons.dart';

import 'package:path/path.dart' as path;

import '../../../../core/components/screen_header.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/di/dependency_injection.dart';
import '../../../../core/data/services/backup_manager.dart';
import '../../../../core/data/services/checkpoint_service.dart';
import '../../../../core/functions/messege.dart';

class DataManagementScreen extends StatefulWidget {
  const DataManagementScreen({super.key});

  @override
  State<DataManagementScreen> createState() => _DataManagementScreenState();
}

class _DataManagementScreenState extends State<DataManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;
  List<Directory> _backups = [];
  List<Map<String, dynamic>> _checkpoints = [];
  bool _isPersistenceReady = false;

  BackupManager? get _backupManager {
    if (getIt.isRegistered<BackupManager>()) {
      return getIt<BackupManager>();
    }
    return null;
  }

  final _checkpointService = CheckpointService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() => setState(() {}));
    _isPersistenceReady = getIt.isRegistered<BackupManager>();
    if (_isPersistenceReady) {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    final manager = _backupManager;
    if (manager == null) {
      setState(() => _isPersistenceReady = false);
      return;
    }
    setState(() => _isLoading = true);
    try {
      final backups = await manager.getAllBackups();
      final checkpoints = await _checkpointService.getAllCheckpoints();
      setState(() {
        _backups = backups;
        _checkpoints = checkpoints;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) MotionSnackBarError(context, 'فشل تحميل البيانات: $e');
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _createBackup() async {
    final manager = _backupManager;
    if (manager == null) return;
    setState(() => _isLoading = true);
    try {
      final success = await manager.createBackup();
      if (success) {
        if (mounted) MotionSnackBarSuccess(context, 'تم إنشاء النسخة الاحتياطية بنجاح');
        await _loadData();
      } else {
        if (mounted) MotionSnackBarError(context, 'فشل إنشاء النسخة الاحتياطية');
      }
    } catch (e) {
      if (mounted) MotionSnackBarError(context, 'خطأ: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _restoreBackup(String backupPath) async {
    final confirm = await _showConfirmDialog(
      'تأكيد الاستعادة',
      'سيتم استبدال البيانات الحالية بالبيانات الموجودة في النسخة المختارة.\n\nسيتم إعادة تشغيل التطبيق بعد الاستعادة.',
      icon: LucideIcons.alertTriangle,
      iconColor: AppColors.warningColor,
    );
    if (!confirm) return;

    setState(() => _isLoading = true);
    try {
      final manager = _backupManager;
      if (manager == null) return;
      final success = await manager.restoreFromBackup(backupPath);
      if (success) {
        if (mounted) {
          MotionSnackBarSuccess(context, 'تمت الاستعادة بنجاح. جارٍ إعادة التشغيل...');
          await Future.delayed(const Duration(seconds: 2));
          exit(0);
        }
      } else {
        if (mounted) MotionSnackBarError(context, 'فشل استعادة النسخة الاحتياطية');
      }
    } catch (e) {
      if (mounted) MotionSnackBarError(context, 'خطأ أثناء الاستعادة: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _restoreCheckpoint(String checkpointPath) async {
    final confirm = await _showConfirmDialog(
      'تأكيد استعادة نقطة الحفظ',
      'سيتم الرجوع إلى نقطة الحفظ هذه وفقدان أي بيانات مسجلة بعدها.\n\nسيتم إعادة تشغيل التطبيق.',
      icon: LucideIcons.alertTriangle,
      iconColor: AppColors.warningColor,
    );
    if (!confirm) return;

    setState(() => _isLoading = true);
    try {
      final success = await _checkpointService.restoreFromCheckpoint(checkpointPath);
      if (success) {
        if (mounted) {
          MotionSnackBarSuccess(context, 'تمت استعادة نقطة الحفظ بنجاح. جارٍ إعادة التشغيل...');
          await Future.delayed(const Duration(seconds: 2));
          exit(0);
        }
      } else {
        if (mounted) MotionSnackBarError(context, 'فشل استعادة نقطة الحفظ');
      }
    } catch (e) {
      if (mounted) MotionSnackBarError(context, 'خطأ أثناء الاستعادة: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteBackup(String backupPath) async {
    final confirm = await _showConfirmDialog(
      'حذف النسخة',
      'هل أنت متأكد من حذف هذه النسخة الاحتياطية؟\n\nلا يمكن التراجع عن هذا الإجراء.',
      icon: LucideIcons.trash2,
      iconColor: AppColors.errorColor,
    );
    if (!confirm) return;

    setState(() => _isLoading = true);
    try {
      final dir = Directory(backupPath);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
        if (mounted) MotionSnackBarSuccess(context, 'تم حذف النسخة بنجاح');
        await _loadData();
      }
    } catch (e) {
      if (mounted) MotionSnackBarError(context, 'فشل الحذف: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<bool> _showConfirmDialog(
    String title,
    String content, {
    IconData icon = LucideIcons.alertCircle,
    Color iconColor = AppColors.primaryColor,
  }) async {
    return await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ],
        ),
        content: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Text(
            content,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              height: 1.6,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('إلغاء', style: TextStyle(color: AppColors.textSecondary)),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: iconColor == AppColors.errorColor
                  ? AppColors.errorColor
                  : AppColors.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('تأكيد', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 8),
        ],
        actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      ),
    ) ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy/MM/dd');
    final timeFormat = DateFormat('hh:mm a');

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.charcoalDark,
        body: !_isPersistenceReady
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.shieldOff, size: 64, color: AppColors.warmOrange.withOpacity(0.5)),
                    const SizedBox(height: 16),
                    Text(
                      'نظام الحماية غير مُفعّل',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.cream),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'يجب تفعيل نظام الحماية أولاً من الإعدادات',
                      style: TextStyle(fontSize: 14, color: AppColors.creamMuted),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(LucideIcons.arrowRight),
                      label: const Text('رجوع'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.warmOrange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              )
            : SafeArea(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: ScreenHeader(
                        title: 'إدارة البيانات',
                        subtitle: 'النسخ الاحتياطي ونقاط الحفظ التلقائي',
                        icon: LucideIcons.database,
                        onBackPressed: () => Navigator.pop(context),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildTabBar(),
                    Expanded(
                      child: _isLoading
                          ? Center(
                              child: CircularProgressIndicator(color: AppColors.warmOrange),
                            )
                          : TabBarView(
                              controller: _tabController,
                              children: [
                                _buildBackupsTab(dateFormat, timeFormat),
                                _buildCheckpointsTab(dateFormat, timeFormat),
                              ],
                            ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  // Remove the old _buildHeader method since we use ScreenHeader




  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: AppColors.charcoalLight,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        indicatorPadding: const EdgeInsets.all(4),
        labelColor: AppColors.warmOrange,
        unselectedLabelColor: AppColors.creamMuted,
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
        dividerColor: Colors.transparent,
        tabs: [
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(LucideIcons.database, size: 16),
                const SizedBox(width: 8),
                const Text('النسخ الاحتياطي'),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(LucideIcons.clock, size: 16),
                const SizedBox(width: 8),
                const Text('نقاط الحفظ'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackupsTab(DateFormat dateFormat, DateFormat timeFormat) {
    return Column(
      children: [
        // Create backup button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: _isLoading ? null : _createBackup,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 18),
                decoration: BoxDecoration(
                  color: AppColors.warmOrange,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.warmOrange.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(LucideIcons.save, color: Colors.white, size: 20),
                    const SizedBox(width: 12),
                    const Text(
                      'إنشاء نسخة احتياطية جديدة',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        // Backup list
        Expanded(
          child: _backups.isEmpty
              ? _buildEmptyState(
                  icon: LucideIcons.database,
                  title: 'لا توجد نسخ احتياطية',
                  subtitle: 'أنشئ نسخة احتياطية للحفاظ على بياناتك',
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: _backups.length,
                  itemBuilder: (context, index) {
                    final backup = _backups[index];
                    final stat = backup.statSync();
                    final name = path.basename(backup.path);
                    final date = stat.modified;
                    final sizeBytes = _getDirSize(backup);
                    final isLatest = index == 0;

                    return _buildBackupCard(
                      name: name,
                      date: date,
                      sizeBytes: sizeBytes,
                      isLatest: isLatest,
                      dateFormat: dateFormat,
                      timeFormat: timeFormat,
                      onRestore: () => _restoreBackup(backup.path),
                      onDelete: () => _deleteBackup(backup.path),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildCheckpointsTab(DateFormat dateFormat, DateFormat timeFormat) {
    if (_checkpoints.isEmpty) {
      return _buildEmptyState(
        icon: LucideIcons.clock,
        title: 'لا توجد نقاط حفظ تلقائية',
        subtitle: 'يتم إنشاء نقاط الحفظ تلقائياً عند إجراء عمليات مهمة',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: _checkpoints.length,
      itemBuilder: (context, index) {
        final chk = _checkpoints[index];
        final reason = chk['reason'] as String? ?? 'نقطة حفظ تلقائية';
        final user = chk['user'] as String? ?? 'النظام';
        final timestampStr = chk['timestamp'] as String?;
        final date = timestampStr != null ? DateTime.parse(timestampStr) : DateTime.now();
        final isLatest = index == 0;

        return _buildCheckpointCard(
          reason: reason,
          user: user,
          date: date,
          isLatest: isLatest,
          dateFormat: dateFormat,
          timeFormat: timeFormat,
          onRestore: () => _restoreCheckpoint(chk['path']),
        );
      },
    );
  }

  Widget _buildBackupCard({
    required String name,
    required DateTime date,
    required int sizeBytes,
    required bool isLatest,
    required DateFormat dateFormat,
    required DateFormat timeFormat,
    required VoidCallback onRestore,
    required VoidCallback onDelete,
  }) {
    final sizeMB = (sizeBytes / 1024 / 1024).toStringAsFixed(2);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isLatest ? AppColors.warmOrange.withOpacity(0.3) : AppColors.borderColor,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isLatest ? AppColors.warmOrange.withOpacity(0.1) : AppColors.charcoalLight,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                LucideIcons.database,
                color: isLatest ? AppColors.warmOrange : AppColors.creamMuted,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: AppColors.cream,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isLatest)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.successGreen.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'الأحدث',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppColors.successGreen,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _buildInfoChip(
                        icon: LucideIcons.calendar,
                        text: dateFormat.format(date),
                      ),
                      const SizedBox(width: 10),
                      _buildInfoChip(
                        icon: LucideIcons.clock,
                        text: timeFormat.format(date),
                      ),
                      const SizedBox(width: 10),
                      _buildInfoChip(
                        icon: LucideIcons.hardDrive,
                        text: '$sizeMB MB',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Actions
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildActionButton(
                  icon: LucideIcons.rotateCcw,
                  color: AppColors.warmOrange,
                  tooltip: 'استعادة',
                  onTap: onRestore,
                ),
                const SizedBox(width: 6),
                _buildActionButton(
                  icon: LucideIcons.trash2,
                  color: AppColors.errorColor,
                  tooltip: 'حذف',
                  onTap: onDelete,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckpointCard({
    required String reason,
    required String user,
    required DateTime date,
    required bool isLatest,
    required DateFormat dateFormat,
    required DateFormat timeFormat,
    required VoidCallback onRestore,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isLatest ? AppColors.successGreen.withOpacity(0.3) : AppColors.borderColor,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isLatest ? AppColors.successGreen.withOpacity(0.1) : AppColors.charcoalLight,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                LucideIcons.clock,
                color: isLatest ? AppColors.successGreen : AppColors.creamMuted,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          reason,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: AppColors.cream,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isLatest)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.successGreen.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'الأحدث',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppColors.successGreen,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _buildInfoChip(
                        icon: LucideIcons.user,
                        text: user,
                      ),
                      const SizedBox(width: 10),
                      _buildInfoChip(
                        icon: LucideIcons.calendar,
                        text: dateFormat.format(date),
                      ),
                      const SizedBox(width: 10),
                      _buildInfoChip(
                        icon: LucideIcons.clock,
                        text: timeFormat.format(date),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Restore action
            _buildActionButton(
              icon: LucideIcons.rotateCcw,
              color: AppColors.successGreen,
              tooltip: 'استعادة',
              onTap: onRestore,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip({required IconData icon, required String text}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: AppColors.creamMuted),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 12,
            color: AppColors.creamMuted,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(icon, color: color, size: 18),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.warmOrange.withOpacity(0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 64, color: AppColors.mutedColor.withOpacity(0.3)),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.cream,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.creamMuted,
            ),
          ),
        ],
      ),
    );
  }

  int _getDirSize(Directory dir) {
    int size = 0;
    try {
      if (dir.existsSync()) {
        dir.listSync(recursive: true, followLinks: false).forEach((FileSystemEntity entity) {
          if (entity is File) {
            size += entity.lengthSync();
          }
        });
      }
    } catch (_) {}
    return size;
  }
}
