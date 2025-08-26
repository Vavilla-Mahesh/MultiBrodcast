import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/stream/schedule_stream_screen.dart';
import 'screens/stream/live_stream_screen.dart';
import 'screens/downloads/downloads_screen.dart';
import 'services/auth_service.dart';

void main() {
  runApp(
    ProviderScope(
      child: MultiBroadcastApp(),
    ),
  );
}

class MultiBroadcastApp extends ConsumerWidget {
  MultiBroadcastApp({Key? key}) : super(key: key);

  final GoRouter _router = GoRouter(
    initialLocation: '/login',
    routes: [
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/home',
        name: 'home',
        builder: (context, state) => const HomeScreen(),
        routes: [
          GoRoute(
            path: '/schedule',
            name: 'schedule',
            builder: (context, state) => const ScheduleStreamScreen(),
          ),
          GoRoute(
            path: '/live/:broadcastId',
            name: 'live',
            builder: (context, state) => LiveStreamScreen(
              broadcastId: state.pathParameters['broadcastId']!,
            ),
          ),
          GoRoute(
            path: '/downloads',
            name: 'downloads',
            builder: (context, state) => const DownloadsScreen(),
          ),
        ],
      ),
    ],
    redirect: (context, state) {
      final authService = ProviderScope.containerOf(context).read(authServiceProvider);
      final isLoggedIn = authService.isAuthenticated;
      final isLoggingIn = state.matchedLocation == '/login';

      if (!isLoggedIn && !isLoggingIn) {
        return '/login';
      }
      if (isLoggedIn && isLoggingIn) {
        return '/home';
      }
      return null;
    },
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'MultiBroadcast',
      theme: ThemeData(
        primarySwatch: Colors.red,
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
        ),
      ),
      routerConfig: _router,
      debugShowCheckedModeBanner: false,
    );
  }
}