import 'package:flutter/material.dart';
import 'chat_screen.dart';

void main() {
  runApp(const EgipturaRagApp());
}

class EgipturaRagApp extends StatelessWidget {
  const EgipturaRagApp({super.key});

  @override
  Widget build(BuildContext context) {
    final seed = const Color(0xFFB88A2E); // Egiptura gold
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'PDF Q&A',
      themeMode: ThemeMode.light,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: seed,
        brightness: Brightness.light,
        scaffoldBackgroundColor: Colors.transparent,
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
          filled: true,
          fillColor: Color(0xFFFFFFFF),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          ),
        ),
      ),
      home: const ChatScreen(),
    );
  }
}