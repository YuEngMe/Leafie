import 'package:flutter/material.dart';
import 'package:yeso_plant/models/plant_registration_draft.dart';
import 'package:yeso_plant/screens/home_screen.dart';
import 'package:yeso_plant/services/leafie_api_client.dart';
import 'package:yeso_plant/services/plant_api.dart';
import 'package:yeso_plant/theme/app_colors.dart';
import 'package:yeso_plant/theme/app_layout.dart';
import 'package:yeso_plant/theme/app_text_styles.dart';
import 'package:yeso_plant/widgets/plant_character_art.dart';
import 'package:yeso_plant/widgets/primary_button.dart';
import 'package:yeso_plant/widgets/yeso_app_bar.dart';

Future<String> _submitPlantRegistration(PlantRegistrationDraft draft) async {
  return PlantApi().registerPlant(draft);
}

class PlantRegisterCompleteScreen extends StatefulWidget {
  const PlantRegisterCompleteScreen({
    super.key,
    required this.draft,
    this.submit,
  });

  final PlantRegistrationDraft draft;

  /// Supabase를 초기화하지 않는 위젯 테스트에서 갈아끼운다.
  final Future<String> Function(PlantRegistrationDraft)? submit;

  @override
  State<PlantRegisterCompleteScreen> createState() =>
      _PlantRegisterCompleteScreenState();
}

class _PlantRegisterCompleteScreenState
    extends State<PlantRegisterCompleteScreen> {
  bool _submitting = false;

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      final plantId = await (widget.submit ?? _submitPlantRegistration)(
        widget.draft,
      );
      if (mounted) {
        final snapshot = widget.draft.submissionSnapshot;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => HomeScreen(
              plant: HomePlant(
                id: plantId,
                name: snapshot?.name ?? widget.draft.name,
                startedOn: snapshot?.startedOn ?? widget.draft.startedOn,
                personalityType:
                    snapshot?.personalityType ?? widget.draft.personalityType,
                bodyId: snapshot?.bodyId ?? widget.draft.bodyId,
                hairId: snapshot?.headItem ?? widget.draft.headItem,
                expressionId:
                    snapshot?.expressionId ?? widget.draft.expressionId,
                colorId: snapshot?.bodyColorId ?? widget.draft.bodyColorId,
              ),
            ),
          ),
          (route) => false,
        );
      }
    } on LeafieApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (error, stackTrace) {
      debugPrint('Plant registration failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('식물을 등록하지 못했어요.')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundWhite,
      appBar: const YesoAppBar(title: '캐릭터 만들기'),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // 작은 화면은 시안 배치를 비율로 줄인다.
            final scale = constraints.maxHeight < 700 ? 0.75 : 1.0;
            return Column(
              children: [
                SizedBox(height: AppLayout.completionTopGap * scale),
                // 시안 4534:812: 제목 y=188, 광원 원(408) y=251, 몸통 바닥
                // y=596.9. 헤어는 박스 위로 솟으므로 몸통 바닥 기준으로 둔다.
                SizedBox(
                  height: AppLayout.completionStageHeight * scale,
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.topCenter,
                    children: [
                      Positioned(
                        top: AppLayout.completionGlowTop * scale,
                        child: Container(
                          width: AppLayout.completionGlowSize * scale,
                          height: AppLayout.completionGlowSize * scale,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                Color(0xFFFFDFA0),
                                Color(0xCCFFEAC2),
                                Color(0x00FFFFFF),
                              ],
                              stops: [0, 0.5, 1],
                            ),
                          ),
                        ),
                      ),
                      const Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: Text(
                          '당신의 리피가 완성되었어요!',
                          style: kTitleStyle,
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Positioned(
                        top: AppLayout.completionCharacterTop * scale,
                        child: PlantCharacterArt(
                          width: AppLayout.completionCharacterWidth * scale,
                          body: plantBodyFromId(widget.draft.bodyId),
                          colorId: widget.draft.bodyColorId,
                          hairId: widget.draft.headItem,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppLayout.registrationHorizontalPadding,
                    0,
                    AppLayout.registrationHorizontalPadding,
                    AppLayout.bottomPadding,
                  ),
                  child: PrimaryButton(
                    label: _submitting ? '등록 중...' : '다음',
                    variant: _submitting
                        ? PrimaryButtonVariant.disabled
                        : PrimaryButtonVariant.enabled,
                    onPressed: _submitting ? null : _submit,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
