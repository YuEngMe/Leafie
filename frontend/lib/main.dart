import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yeso_plant/screens/login_screen.dart';
import 'package:yeso_plant/theme/app_colors.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load();
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    publishableKey: dotenv.env['SUPABASE_PUBLISHABLE_KEY']!,
  );
  runApp(const YesoApp());
}

class YesoApp extends StatelessWidget {
  const YesoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '리피 - 내 식물 친구',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: kButtonGreen),
        fontFamily: 'Pretendard',
      ),
      home: const LoginScreen(),
    );
  }
}
