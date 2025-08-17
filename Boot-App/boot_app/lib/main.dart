import 'package:flutter/material.dart';
import 'theme/terminal_theme.dart';
import 'pages/Test_Page.dart';
import 'pages/Home_Page.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Boot App',
      theme: buildTerminalTheme(),
      home: const HomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}
