import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../data/services/catalog_cache_service.dart';
import '../live_tv/live_tv_categories_screen.dart';
import '../movies/movies_screen.dart';
import '../profiles/playlist_sync_screen.dart';
import '../series/series_categories_screen.dart';
import '../../../data/datasources/remote/xtream_api.dart';
import '../profiles/profiles_screen.dart';
import '../settings/settings_screen.dart';

class HomeDashboard extends StatefulWidget {
  final String username;
  final String expiryDate;
  final XtreamApi xtreamApi;

  const HomeDashboard({
    super.key,
    required this.username,
    required this.expiryDate,
    required this.xtreamApi,
  });

  @override
  State<HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends State<HomeDashboard> {
  String _playlistName = 'My IPTV';
  String _lastRefreshText = 'Never';

  @override
  void initState() {
    super.initState();
    _loadPlaylistName();
    _loadLastRefresh();
  }

  Future<void> _loadPlaylistName() async {
    final prefs = await SharedPreferences.getInstance();
    final savedPlaylistName = prefs.getString('playlist_name') ?? 'My IPTV';
    if (!mounted) return;
    setState(() => _playlistName = savedPlaylistName);
  }

  Future<void> _loadLastRefresh() async {
    final profileKey = CatalogCacheService.buildProfileKey(
      serverUrl: widget.xtreamApi.serverUrl,
      username: widget.xtreamApi.username,
    );
    final lastRefresh = await CatalogCacheService.getLastRefresh(profileKey);
    if (!mounted) return;
    setState(() {
      _lastRefreshText = lastRefresh == null
          ? 'Never'
          : DateFormat('yyyy-MM-dd HH:mm').format(lastRefresh);
    });
  }

  Future<void> _refreshPlaylist() async {
    final profileKey = CatalogCacheService.buildProfileKey(
      serverUrl: widget.xtreamApi.serverUrl,
      username: widget.xtreamApi.username,
    );
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlaylistSyncScreen(
          xtreamApi: widget.xtreamApi,
          profileKey: profileKey,
          title: 'Refreshing Playlist Content',
        ),
      ),
    );

    if (result != null && mounted) {
      await _loadLastRefresh();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Playlist refreshed successfully')),
      );
    }
  }

  Widget buildTile({
    required String label,
    required IconData icon,
    required Color startColor,
    required Color endColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 160,
        height: 160,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [startColor, endColor],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              offset: const Offset(0, 6),
              blurRadius: 12,
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 72, color: Colors.white),
            const SizedBox(height: 16),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 22,
                letterSpacing: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2C2C2C),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 24),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _playlistName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 40),
                  Expanded(
                    child: Center(
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 48,
                        runSpacing: 48,
                        children: [
                          buildTile(
                            label: 'LIVE TV',
                            icon: Icons.live_tv,
                            startColor: const Color(0xFF00c6ff),
                            endColor: const Color(0xFF0072ff),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => LiveTvCategoriesScreen(xtreamApi: widget.xtreamApi),
                                ),
                              );
                            },
                          ),
                          buildTile(
                            label: 'MOVIES',
                            icon: Icons.movie,
                            startColor: const Color(0xFF00c6ff),
                            endColor: const Color(0xFF0072ff),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => MoviesScreen(xtreamApi: widget.xtreamApi),
                                ),
                              );
                            },
                          ),
                          buildTile(
                            label: 'SERIES',
                            icon: Icons.tv,
                            startColor: const Color(0xFF00c6ff),
                            endColor: const Color(0xFF0072ff),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => SeriesCategoriesScreen(xtreamApi: widget.xtreamApi),
                                ),
                              );
                            },
                          ),
                          buildTile(
                            label: 'FAVORITES',
                            icon: Icons.favorite,
                            startColor: const Color(0xFFe91e63),
                            endColor: const Color(0xFFc2185b),
                            onTap: () {
                              Navigator.pushNamed(context, '/favorites', arguments: widget.xtreamApi);
                            },
                          ),
                          buildTile(
                            label: 'CATCH UP',
                            icon: Icons.history,
                            startColor: const Color(0xFF2f9c95),
                            endColor: const Color(0xFF2c5d63),
                            onTap: () {},
                          ),
                          buildTile(
                            label: 'MULTISCREEN',
                            icon: Icons.grid_view,
                            startColor: const Color(0xFF4b6cb7),
                            endColor: const Color(0xFF182848),
                            onTap: () {},
                          ),
                          buildTile(
                            label: 'SETTINGS',
                            icon: Icons.settings,
                            startColor: const Color(0xFF06beb6),
                            endColor: const Color(0xFF48b1bf),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const SettingsScreen(),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              Positioned(
                top: 24,
                right: 36,
                child: _DateTimeWidget(),
              ),
              Positioned(
                top: 24,
                left: 0,
                child: Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ProfilesScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.switch_account, size: 18),
                      label: const Text('Switch Profile'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1A1A2E),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: _refreshPlaylist,
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Refresh Playlist'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF004A7C),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                bottom: 24,
                right: 36,
                child: Text(
                  'Logged in: ${widget.username}\nExpiration: ${widget.expiryDate}\nLast Refresh: $_lastRefreshText',
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}

class _DateTimeWidget extends StatefulWidget {
  @override
  State<_DateTimeWidget> createState() => _DateTimeWidgetState();
}

class _DateTimeWidgetState extends State<_DateTimeWidget> {
  late String _time;
  late String _date;
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _updateDateTime();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _updateDateTime());
  }

  void _updateDateTime() {
    final now = DateTime.now();
    setState(() {
      _time = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
      _date = DateFormat('MMM d, yyyy').format(now);
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          _time,
          style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
        ),
        Text(
          _date,
          style: const TextStyle(color: Colors.white54, fontSize: 14),
        ),
      ],
    );
  }
}
