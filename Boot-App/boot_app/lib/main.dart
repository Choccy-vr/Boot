import 'package:flutter/material.dart';
import 'theme/terminal_theme.dart';
import 'pages/Test_Page.dart';
import 'pages/Home_Page.dart';
import 'pages/Login/Login_Page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/supabase/auth/Auth.dart';
import 'services/supabase/auth/auth_listener.dart';

import 'pages/Login/SignUp/SignUp_Profile_Page.dart';

const supabaseUrl = 'https://zbtphhtuaovleoxkoemt.supabase.co';
const supabaseKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpidHBoaHR1YW92bGVveGtvZW10Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTU0NjU4MDEsImV4cCI6MjA3MTA0MTgwMX0.qogFGForru9M9rutCcMQSNJuGpP46LpLdWo03lvYqMQ';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseKey);
  AuthListener.startListening();
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Boot App',
      theme: buildTerminalTheme(),
      //home: const SignUp_Profile_Page(),
      home: FutureBuilder<bool>(
        future: Authentication.restoreStoredSession(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          } else if (snapshot.hasData && snapshot.data == true) {
            return const HomePage();
          } else {
            return const LoginPage();
          }
        },
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}
