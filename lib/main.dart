import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dashboard_screen.dart'; // ✅ IMPORTANTE: Importa tu pantalla

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ TUS DATOS DE SUPABASE
  const supabaseUrl = 'https://bkxbvvsbrwdklstlrfat.supabase.co';
  const supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJreGJ2dnNicndka2xzdGxyZmF0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODg5NjY3ODIsImV4cCI6MjEwNDU0Mjc4Mn0.xLi18kqkEQny-fduXPk6yghfYxZBy8nRJ_51KogMTY0';

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Parqueadero Calypso',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF121212),
      ),
      home: const DashboardScreen(), // ✅ Llama a tu pantalla
    );
  }
}