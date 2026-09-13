// lib/main.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_config.dart';
import 'dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar Supabase con persistencia de sesión
  try {
    await Supabase.initialize(
      url: SupabaseConfig.supabaseUrl,
      anonKey: SupabaseConfig.supabaseAnonKey,
      options: SupabaseClientOptions(
        autoRefreshToken: true,    // Renueva el token automáticamente
        persistSession: true,      // Guarda la sesión en el dispositivo
      ),
    );
    debugPrint('✅ Supabase inicializado con persistencia');
  } catch (e) {
    debugPrint('❌ ERROR Supabase: $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Parqueadero Calypso',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const DashboardScreen(),
    );
  }
}