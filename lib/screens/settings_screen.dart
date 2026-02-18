import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import '../config/app_theme.dart';
import '../providers/app_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _serverC = TextEditingController(text: ApiConfig.baseUrl);
  String _msg = '';

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();
    final isRtl = prov.isRtl;

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(isRtl ? 'الإعدادات' : 'Settings',
              style:
                  const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),

          // Language
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(isRtl ? 'اللغة' : 'Language',
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _langBtn(
                          label: 'العربية',
                          isSelected: prov.locale == 'ar',
                          onTap: () => prov.setLocale('ar'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _langBtn(
                          label: 'English',
                          isSelected: prov.locale == 'en',
                          onTap: () => prov.setLocale('en'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Connection Mode
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(isRtl ? 'وضع الاتصال' : 'Connection Mode',
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.success.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.cloud_done_rounded,
                          size: 16,
                          color: AppTheme.success,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            isRtl ? 'متصل عبر API Server (آمن)' : 'Connected via API Server (Secure)',
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Server URL (only relevant in API mode)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(isRtl ? 'عنوان السيرفر' : 'Server URL',
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 8),
                  Text(
                    isRtl
                        ? 'عنوان الـ API الخاص بتطبيق الويب'
                        : 'The API base URL for the web app backend',
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _serverC,
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'http://192.168.100.25:3000',
                      labelText: isRtl ? 'رابط السيرفر' : 'Base URL',
                    ),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: () async {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setString('baseUrl', _serverC.text.trim());
                      setState(() =>
                          _msg = isRtl ? 'تم الحفظ. أعد تشغيل التطبيق.' : 'Saved. Restart app to apply.');
                    },
                    icon: const Icon(Icons.save_rounded, size: 16),
                    label: Text(isRtl ? 'حفظ' : 'Save'),
                  ),
                  if (_msg.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(_msg,
                          style: const TextStyle(
                              fontSize: 12, color: AppTheme.success)),
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // App info
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(isRtl ? 'عن التطبيق' : 'About',
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 8),
                  Text('PMS Lite v1.0.0',
                      style: const TextStyle(
                          fontSize: 13, color: AppTheme.textPrimary)),
                  const SizedBox(height: 4),
                  Text(
                    isRtl
                        ? 'نظام إدارة العقارات - إدارة الوحدات والحجوزات والمحتوى والتقارير.'
                        : 'Property Management System - Manage units, bookings, content, and reports.',
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _langBtn(
      {required String label,
      required bool isSelected,
      required VoidCallback onTap}) {
    return Material(
      color: isSelected
          ? AppTheme.accent.withValues(alpha: 0.1)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppTheme.accent : AppTheme.border,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? AppTheme.accent : AppTheme.textSecondary,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
