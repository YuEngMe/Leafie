import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yeso_plant/screens/plant_register_name_screen.dart';
import 'package:yeso_plant/theme/app_colors.dart';
import 'package:yeso_plant/widgets/primary_button.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, this.plantName, this.signOut});

  final String? plantName;
  final Future<void> Function()? signOut;

  Future<void> _requestSignOut(BuildContext context) async {
    try {
      await (signOut ?? Supabase.instance.client.auth.signOut)();
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('로그아웃에 실패했어요. 다시 시도해주세요.')));
    }
  }

  void _startPlantRegistration(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const PlantRegisterNameScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final hasPlant = plantName != null;

    return Scaffold(
      backgroundColor: kAppBackground,
      appBar: AppBar(
        backgroundColor: kAppBackground,
        title: Text(hasPlant ? '$plantName의 방' : '리피'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton.icon(
              onPressed: () => _requestSignOut(context),
              style: TextButton.styleFrom(
                foregroundColor: kLabelGreen,
                backgroundColor: kBorderGreen,
                minimumSize: const Size(96, 48),
                textStyle: const TextStyle(fontWeight: FontWeight.w600),
                shape: const StadiumBorder(),
              ),
              icon: const Icon(Icons.logout, size: 18),
              label: const Text('로그아웃'),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 132,
                height: 132,
                decoration: const BoxDecoration(
                  color: kBorderGreen,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.spa, size: 64, color: kLabelGreen),
              ),
              const SizedBox(height: 32),
              Text(
                hasPlant ? '$plantName의 등록이 완료됐어요' : '내 식물이 기다리고 있어요',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                hasPlant
                    ? '이제 식물과 함께하는 기록을 시작해보세요.'
                    : '식물을 등록하면 관리 일정과 성장 기록을\n한곳에서 확인할 수 있어요.',
                style: TextStyle(fontSize: 15, color: Colors.grey.shade700),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              PrimaryButton(
                label: hasPlant ? '식물 더 등록하기' : '식물 등록 시작하기',
                onPressed: () => _startPlantRegistration(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
