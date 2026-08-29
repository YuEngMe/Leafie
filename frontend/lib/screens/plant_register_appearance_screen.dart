import 'package:flutter/material.dart';
import 'package:yeso_plant/models/plant_registration_draft.dart';
import 'package:yeso_plant/screens/plant_register_complete_screen.dart';
import 'package:yeso_plant/theme/app_colors.dart';
import 'package:yeso_plant/widgets/primary_button.dart';

class _ColorOption {
  const _ColorOption(this.id, this.color);

  final String id; // POST /plants의 character.body_color 값 (color_id 형식)
  final Color color;
}

// Figma "와프2차 > 캐릭터 등록_꾸밈2-1" 컬러 팔레트 스와치를 그대로 관찰해 옮김
// (2026-08-04). id 값은 체크리스트의 "color_id: color_green_01" 형식 근거로 지음 —
// 서버 실제 목록은 GET /character-options 붙을 때 교체.
const _colorOptions = [
  _ColorOption('color_orange_01', Color(0xFFFFC98B)),
  _ColorOption('color_purple_01', Color(0xFFD9B3FA)),
  _ColorOption('color_mint_01', Color(0xFFA8E6C1)),
  _ColorOption('color_yellow_01', Color(0xFFFFF176)),
  _ColorOption('color_red_01', Color(0xFFFF8A8A)),
  _ColorOption('color_skyblue_01', Color(0xFFA8D8FF)),
  _ColorOption('color_blue_01', Color(0xFF7FA6F5)),
  _ColorOption('color_gray_01', Color(0xFFB0B0B0)),
  _ColorOption('color_pink_01', Color(0xFFFFC1DA)),
];

class PlantRegisterAppearanceScreen extends StatefulWidget {
  const PlantRegisterAppearanceScreen({super.key, required this.draft});

  final PlantRegistrationDraft draft;

  @override
  State<PlantRegisterAppearanceScreen> createState() =>
      _PlantRegisterAppearanceScreenState();
}

class _PlantRegisterAppearanceScreenState
    extends State<PlantRegisterAppearanceScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  String? _selectedColorId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _goToNextStep() {
    if (_selectedColorId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('컬러를 선택해주세요')));
      return;
    }
    widget.draft.bodyColorId = _selectedColorId;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlantRegisterCompleteScreen(draft: widget.draft),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('캐릭터 만들기')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: 0.9,
                  minHeight: 6,
                  backgroundColor: kBorderGreen,
                  color: kButtonGreen,
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '식물을 꾸며주세요!',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 24),
            Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                color: _selectedColorId == null
                    ? Colors.grey.shade300
                    : _colorOptions
                          .firstWhere((c) => c.id == _selectedColorId)
                          .color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(height: 24),
            TabBar(
              controller: _tabController,
              labelColor: kButtonGreen,
              unselectedLabelColor: Colors.grey,
              tabs: const [Tab(text: '컬러'), Tab(text: '헤어'), Tab(text: '장식')],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  GridView.count(
                    padding: const EdgeInsets.all(24),
                    crossAxisCount: 3,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    children: _colorOptions
                        .map(
                          (option) => GestureDetector(
                            key: ValueKey(option.id),
                            onTap: () => setState(
                              () => _selectedColorId = option.id,
                            ),
                            child: Container(
                              decoration: BoxDecoration(
                                color: option.color,
                                shape: BoxShape.circle,
                                border: _selectedColorId == option.id
                                    ? Border.all(
                                        color: kButtonGreen,
                                        width: 3,
                                      )
                                    : null,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  // TODO: 헤어 에셋은 디자이너 납품 후 연결 (2026-08-04 확인, 이미지뿐
                  // 텍스트 라벨 없어 ID 매핑 불가 — 체크리스트 "팀에 확인 필요한 것" 참고)
                  const Center(child: Text('헤어 꾸미기는 준비 중이에요')),
                  // TODO: 장식 에셋도 위와 동일한 이유로 보류
                  const Center(child: Text('장식 꾸미기는 준비 중이에요')),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 32,
                vertical: 16,
              ),
              child: PrimaryButton(label: '다음', onPressed: _goToNextStep),
            ),
          ],
        ),
      ),
    );
  }
}
