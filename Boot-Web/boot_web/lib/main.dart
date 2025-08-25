import 'package:flutter/material.dart';
import 'theme/terminal_theme.dart';
import 'pages/Test_Home.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Boot Web',
      theme: buildTerminalTheme(),
      home: const HomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}
