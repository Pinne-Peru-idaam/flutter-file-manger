import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/home_screen.dart';
import 'screens/signin_screen.dart';
import 'screens/signup_screen.dart';
import 'services/auth_service.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'config/theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Lock orientation to portrait only
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  final AuthService _authService = AuthService();

  MyApp({super.key});

  static final _defaultLightColorScheme = ColorScheme.fromSeed(
    seedColor: Colors.blue,
    brightness: Brightness.light,
  );

  static final _defaultDarkColorScheme = ColorScheme.fromSeed(
    seedColor: Colors.blue,
    brightness: Brightness.dark,
  );
  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
        builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
      return MaterialApp(
        title: 'File Manager',
        theme: AppTheme.themeData(lightDynamic ?? _defaultLightColorScheme),
        darkTheme: AppTheme.themeData(darkDynamic ?? _defaultDarkColorScheme),
        themeMode: ThemeMode.system,
        initialRoute: '/',
        routes: {
          '/': (context) => FutureBuilder<bool>(
                future: _authService.isLoggedIn(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Scaffold(
                      body: Center(child: CircularProgressIndicator()),
                    );
                  }

                  if (snapshot.hasError) {
                    debugPrint('Auth error: ${snapshot.error}');
                    return const SignInScreen();
                  }

                  final bool isLoggedIn = snapshot.data ?? false;
                  debugPrint('User logged in: $isLoggedIn');

                  if (isLoggedIn) {
                    return const HomeScreen();
                  } else {
                    return const SignInScreen();
                  }
                },
              ),
          '/home': (context) => const HomeScreen(),
          '/signin': (context) => const SignInScreen(),
          '/signup': (context) => const SignUpScreen(),
        },
      );
    });
  }
}
