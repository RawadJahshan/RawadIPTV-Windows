import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'data/datasources/remote/xtream_api.dart';
import 'presentation/screens/profiles/profiles_screen.dart';
import 'presentation/screens/favorites/favorites_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IPTV App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF1E1E1E),
      ),
      home: const ProfilesScreen(),
      onGenerateRoute: (settings) {
        if (settings.name == '/favorites') {
          final xtreamApi = settings.arguments as XtreamApi;
          return MaterialPageRoute(
            builder: (_) => FavoritesScreen(xtreamApi: xtreamApi),
          );
        }
        return null;
      },
    );
  }
}