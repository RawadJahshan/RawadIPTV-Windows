import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../data/services/cache_maintenance_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isClearingCache = false;

  Future<void> _clearCache() async {
    if (_isClearingCache) return;
    setState(() => _isClearingCache = true);
    try {
      await CacheMaintenanceService.clearAppCaches();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cache cleared: metadata and image cache.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to clear cache: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isClearingCache = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: ListTile(
              title: const Text('Clear Cache'),
              subtitle: const Text('Clears in-memory metadata and image cache.'),
              trailing: _isClearingCache
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.cleaning_services_outlined),
              onTap: _isClearingCache ? null : _clearCache,
            ),
          ),
        ],
      ),
    );
  }
}
