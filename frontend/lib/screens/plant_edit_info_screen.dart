import 'package:flutter/material.dart';
import 'package:yeso_plant/services/leafie_api_client.dart';
import 'package:yeso_plant/services/plant_management_api.dart';
import 'package:yeso_plant/theme/app_colors.dart';
import 'package:yeso_plant/theme/app_text_styles.dart';
import 'package:yeso_plant/widgets/plant_detail_components.dart';
import 'package:yeso_plant/widgets/plant_search_components.dart';
import 'package:yeso_plant/widgets/rounded_input_field.dart';
import 'package:yeso_plant/widgets/yeso_app_bar.dart';

/// 시안 2555:661 "캐릭터 상세_정보수정 1" + 4534:20112 "정보수정 4"(날짜 시트).
///
/// 4필드 폼: 닉네임 / 장소(별명) / 마지막 물 준 날 / 분갈이 한 날.
/// 라벨 x=45, 입력칸 x=34 w=334 h=51, 라벨 피치 110. 하단 '수정하기' y=790.
/// 앱이 쓰던 이름 변경 AlertDialog는 이 화면으로 대체됐다.
class PlantEditInfoScreen extends StatefulWidget {
  const PlantEditInfoScreen({
    super.key,
    required this.plant,
    required this.repository,
  });

  final ManagedPlant plant;
  final PlantManagementRepository repository;

  @override
  State<PlantEditInfoScreen> createState() => _PlantEditInfoScreenState();
}

class _PlantEditInfoScreenState extends State<PlantEditInfoScreen> {
  late final _nickname = TextEditingController(text: widget.plant.nickname);
  late final _place = TextEditingController(text: widget.plant.placeName);
  late DateTime? _wateredOn = widget.plant.lastWateredOn;
  late DateTime? _repottedOn = widget.plant.lastRepottedOn;
  late final _wateredText = TextEditingController(
    text: _displayDate(widget.plant.lastWateredOn),
  );
  late final _repottedText = TextEditingController(
    text: _displayDate(widget.plant.lastRepottedOn),
  );
  bool _busy = false;

  @override
  void dispose() {
    _nickname.dispose();
    _place.dispose();
    _wateredText.dispose();
    _repottedText.dispose();
    super.dispose();
  }

  static String _displayDate(DateTime? date) =>
      date == null ? '' : '${date.year}년 ${date.month}월 ${date.day}일';

  /// 서버는 사용자 시간대(현재 Asia/Seoul 고정)로 "오늘"을 정한다.
  /// 기기 시간대가 달라도 같은 기준으로 미래 날짜를 막는다.
  static DateTime _todayInSeoul() {
    final now = DateTime.now().toUtc().add(const Duration(hours: 9));
    return DateTime(now.year, now.month, now.day);
  }

  static bool _sameDay(DateTime? a, DateTime? b) =>
      a == null || b == null
      ? a == b
      : a.year == b.year && a.month == b.month && a.day == b.day;

  /// 시안 4534:20112 "정보수정 4" 날짜 시트를 띄운다. 기록이 없으면 오늘에서
  /// 시작한다. 서버가 미래 날짜를 받지 않으므로 여기서 먼저 막는다.
  /// 시안은 시트 뒤 화면을 어둡게 덮지 않는다.
  Future<void> _pickDate({required bool watered}) async {
    final current = watered ? _wateredOn : _repottedOn;
    final thisYear = DateTime.now().year;
    final picked = await showModalBottomSheet<DateTime>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: false,
      builder: (_) => PlantDatePickerSheet(
        initialDate: current ?? _todayInSeoul(),
        // 오늘 뒤의 날짜는 휠에 아예 없다.
        maximumDate: _todayInSeoul(),
        buttonLabel: '수정하기',
        firstYear: thisYear - 20,
        lastYear: thisYear,
      ),
    );
    if (!mounted || picked == null) return;
    setState(() {
      if (watered) {
        _wateredOn = picked;
        _wateredText.text = _displayDate(picked);
      } else {
        _repottedOn = picked;
        _repottedText.text = _displayDate(picked);
      }
    });
  }

  Future<void> _submit() async {
    final nickname = _nickname.text.trim();
    final placeName = _place.text.trim();
    if (nickname.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('식물 이름을 입력해주세요.')));
      return;
    }
    if (placeName.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('장소를 입력해주세요.')));
      return;
    }
    final nicknameChanged = nickname != widget.plant.nickname;
    final placeNameChanged = placeName != widget.plant.placeName;
    final wateredChanged = !_sameDay(_wateredOn, widget.plant.lastWateredOn);
    final repottedChanged = !_sameDay(
      _repottedOn,
      widget.plant.lastRepottedOn,
    );
    if (!nicknameChanged &&
        !placeNameChanged &&
        !wateredChanged &&
        !repottedChanged) {
      Navigator.of(context).pop(widget.plant);
      return;
    }
    setState(() => _busy = true);
    try {
      final updated = await widget.repository.updatePlant(
        widget.plant.id,
        nickname: nicknameChanged ? nickname : null,
        placeName: placeNameChanged ? placeName : null,
        // 날짜를 바꾸면 서버가 다음 물주기·분갈이 예정일을 다시 계산한다.
        // 이전 기록보다 앞선 날짜는 409로 거절되고 그 안내를 그대로 띄운다.
        lastWateredOn: wateredChanged ? _wateredOn : null,
        lastRepottedOn: repottedChanged ? _repottedOn : null,
      );
      if (mounted) Navigator.of(context).pop(updated);
    } on LeafieApiException catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundWhite,
      // 시안 4534:20068/20112의 뒤로 꺾쇠는 주황(#FFB52A), 제목(4534:20090)은
      // 검정이다(공용 앱바 기본 #444).
      appBar: const YesoAppBar(
        title: '캐릭터 정보 수정',
        backIconColor: kOrangeMain,
        titleColor: Colors.black,
      ),
      body: PlantDetailBody(
        children: [
          // 2555:687/689. 라벨 top 145, 입력칸 top 169.
          _field(
            labelTop: 145,
            label: '닉네임',
            child: RoundedInputField(
              key: const ValueKey('plant_nickname_field'),
              controller: _nickname,
              height: 51,
            ),
          ),
          // 2555:697/699. 라벨 top 255.
          _field(
            labelTop: 255,
            label: '장소(별명)',
            child: RoundedInputField(
              key: const ValueKey('plant_place_field'),
              controller: _place,
              hintText: '예: 베란다',
              height: 51,
            ),
          ),
          // 2555:702/704. 라벨 top 365.
          _field(
            labelTop: 365,
            label: '마지막 물 준 날',
            child: RoundedInputField(
              key: const ValueKey('plant_watered_field'),
              controller: _wateredText,
              readOnly: true,
              hintText: '선택하기',
              height: 51,
              onTap: () => _pickDate(watered: true),
            ),
          ),
          // 2555:707/709. 라벨 top 475.
          _field(
            labelTop: 475,
            label: '분갈이 한 날',
            child: RoundedInputField(
              key: const ValueKey('plant_repotted_field'),
              controller: _repottedText,
              readOnly: true,
              hintText: '선택하기',
              height: 51,
              onTap: () => _pickDate(watered: false),
            ),
          ),
        ],
      ),
      bottomNavigationBar: PlantDetailBottomAction(
        label: '수정하기',
        onPressed: _busy ? null : _submit,
      ),
    );
  }

  /// 라벨 + 입력칸 묶음. RoundedInputField가 라벨을 함께 그리므로 라벨 top을
  /// 그대로 슬롯 top으로 쓴다(라벨 19 + 간격 5 + 칸 51 = 75).
  Widget _field({
    required double labelTop,
    required String label,
    required Widget child,
  }) {
    return Positioned(
      left: 34,
      width: 334,
      top: labelTop - PlantDetailBody.appBarBand,
      height: 75,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            // 라벨만 11px 들여쓴다(x34 -> x45).
            padding: const EdgeInsets.only(left: 11),
            child: Text(
              label,
              style: kItemStyle.copyWith(color: kOrangeMain, height: 19 / 16),
            ),
          ),
          const SizedBox(height: 5),
          SizedBox(height: 51, child: child),
        ],
      ),
    );
  }
}
