import 'package:flutter/material.dart';
import 'package:synckit_example/globals.dart';
import 'package:synckit_example/utils/router.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    Globals.initialize(context);
    return MaterialApp.router(
      title: 'Synckit Example',
      debugShowCheckedModeBanner: false,
      routerConfig: appRouter,
      theme: ThemeData.dark().copyWith(
        colorScheme: const ColorScheme.dark(
          primary: Colors.tealAccent,
          secondary: Colors.cyanAccent,
          surface: Color(0xFF1E1E2E),
        ),
        scaffoldBackgroundColor: const Color(0xFF11111B),
        cardTheme: CardThemeData(
          elevation: 0,
          margin: EdgeInsets.zero,
          color: const Color(0xFF1E1E2E),
          shape: RoundedRectangleBorder(
            borderRadius: Globals.borderRadius,
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF181825),
          elevation: 0,
        ),
        inputDecorationTheme: InputDecorationTheme(
          fillColor: const Color(0xFF1E1E2E),
          filled: true,
          border: OutlineInputBorder(
            borderRadius: Globals.borderRadius,
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: Globals.borderRadius,
            borderSide: const BorderSide(color: Colors.tealAccent, width: 1.5),
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Colors.tealAccent,
          foregroundColor: Color(0xFF11111B),
        ),
      ),
    );
  }
}

