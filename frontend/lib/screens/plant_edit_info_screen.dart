import 'package:flutter/material.dart';
import 'package:yeso_plant/services/leafie_api_client.dart';
import 'package:yeso_plant/services/plant_management_api.dart';
import 'package:yeso_plant/theme/app_colors.dart';
import 'package:yeso_plant/theme/app_text_styles.dart';
import 'package:yeso_plant/widgets/plant_detail_components.dart';
import 'package:yeso_plant/widgets/primary_button.dart';
import 'package:yeso_plant/widgets/rounded_input_field.dart';
import 'package:yeso_plant/widgets/yeso_app_bar.dart';

/// 시안 2555:661 "캐릭터 상세_정보수정 1" + 2568:1639 "정보수정 2"(날짜 시트).
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
  // TODO(design): 장소(별명)는 ManagedPlant에도 PATCH /plants/{id}에도 없다.
  // API가 생기면 초기값을 채우고 저장에 함께 실어 보낸다.
  final _place = TextEditingController();
  // TODO(design): 마지막 물 준 날·분갈이 한 날도 API에 없다. 지금은 화면 안
  // 상태로만 남고 서버로 가지 않는다.
  DateTime? _lastWatered;
  DateTime? _lastRepotted;
  final _wateredText = TextEditingController();
  final _repottedText = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _nickname.dispose();
    _place.dispose();
    _wateredText.dispose();
    _repottedText.dispose();
    super.dispose();
  }

  Future<void> _pickDate({
    required DateTime? current,
    required ValueChanged<DateTime> onPicked,
  }) async {
    final picked = await showModalBottomSheet<DateTime>(
      context: context,
      barrierColor: kModalBarrier,
      backgroundColor: Colors.transparent,
      elevation: 0,
      // 시트가 시안(402x325)대로 화면 바닥에 붙어야 한다. useSafeArea를 켜면
      // 하단 인셋(34)만큼 위로 떠서 버튼이 휠 위로 올라온다.
      useSafeArea: false,
      isScrollControlled: true,
      builder: (_) => PlantDatePickerSheet(initialDate: current),
    );
    if (picked != null) onPicked(picked);
  }

  Future<void> _submit() async {
    final nickname = _nickname.text.trim();
    if (nickname.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('식물 이름을 입력해주세요.')));
      return;
    }
    if (nickname == widget.plant.nickname) {
      // 서버로 보낼 다른 필드가 아직 없어 그냥 닫는다.
      Navigator.of(context).pop(widget.plant);
      return;
    }
    setState(() => _busy = true);
    try {
      final updated = await widget.repository.updateNickname(
        widget.plant.id,
        nickname,
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

  /// 2568:1667/1672 등 입력칸 안 값은 x=20, 14 또는 12px이다.
  static String _formatDate(DateTime date) =>
      '${date.year}.${date.month.toString().padLeft(2, '0')}'
      '.${date.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundWhite,
      appBar: const YesoAppBar(title: '캐릭터 정보 수정'),
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
              readOnly: true,
              hintText: '선택하기',
              height: 51,
              controller: _wateredText,
              onTap: () => _pickDate(
                current: _lastWatered,
                onPicked: (value) => setState(() {
                  _lastWatered = value;
                  _wateredText.text = _formatDate(value);
                }),
              ),
            ),
          ),
          // 2555:707/709. 라벨 top 475.
          _field(
            labelTop: 475,
            label: '분갈이 한 날',
            child: RoundedInputField(
              key: const ValueKey('plant_repotted_field'),
              readOnly: true,
              hintText: '선택하기',
              height: 51,
              controller: _repottedText,
              onTap: () => _pickDate(
                current: _lastRepotted,
                onPicked: (value) => setState(() {
                  _lastRepotted = value;
                  _repottedText.text = _formatDate(value);
                }),
              ),
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

/// 시안 2568:1683 "정보수정 2"의 날짜 피커 시트.
///
/// 시트(2568:1686)는 **오렌지 #FFB52A**에 위 모서리만 35 굴린 402x325이고,
/// 글자는 흰색 80%, 고른 줄만 흰 반투명 알약(2568:1706) 위에 흰 18 SemiBold,
/// 아래 버튼(2568:1711)은 흰 배경에 오렌지 글자다. 시트 자체가 화면 바닥에
/// 붙으므로 하단 SafeArea는 시트 안에서 더하지 않는다 — 그렇게 하면 시트가
/// 시안보다 34px 커지고 버튼이 휠 위로 밀려 올라간다.
class PlantDatePickerSheet extends StatefulWidget {
  const PlantDatePickerSheet({super.key, this.initialDate});

  final DateTime? initialDate;

  /// 2568:1686. 시트 높이 325(시안 y=549..874).
  static const double sheetHeight = 325;

  /// 2568:1706 강조 줄. 시트 top 549 기준 y=647.66, 높이 39.686.
  static const double rowHeight = 39.686;
  static const double highlightTop = 647.664 - 549;

  /// 2568:1711 버튼. 시트 안 y=790-549=241, 334x51.
  static const double buttonTop = 790 - 549;

  @override
  State<PlantDatePickerSheet> createState() => _PlantDatePickerSheetState();
}

class _PlantDatePickerSheetState extends State<PlantDatePickerSheet> {
  late DateTime _selected = widget.initialDate ?? DateTime.now();

  /// 2568:1686 시트 바탕.
  static const Color _sheetOrange = kOrangeMain;

  /// 2568:1706 고른 줄 알약. rgba(255,197,136,0.42).
  static const Color _highlight = Color(0x6BFFC588);

  /// 하루 수는 달마다 다르다. 31일에 2월로 넘기면 날짜를 끝날로 당긴다.
  void _update({int? year, int? month, int? day}) {
    final y = year ?? _selected.year;
    final m = month ?? _selected.month;
    final lastDay = DateTime(y, m + 1, 0).day;
    final d = (day ?? _selected.day).clamp(1, lastDay);
    setState(() => _selected = DateTime(y, m, d));
  }

  @override
  Widget build(BuildContext context) {
    final thisYear = DateTime.now().year;
    // 휠은 강조 줄 위아래로 2줄씩 보인다(2568:1687~1704).
    const wheelHeight = PlantDatePickerSheet.rowHeight * 5;
    return Container(
      height: PlantDatePickerSheet.sheetHeight,
      decoration: const BoxDecoration(
        color: _sheetOrange,
        borderRadius: BorderRadius.vertical(top: Radius.circular(35)),
        boxShadow: [BoxShadow(color: Color(0x33000000), blurRadius: 5)],
      ),
      child: Stack(
        children: [
          // 강조 줄 2568:1706. x=1 w=399.95 radius 20.
          Positioned(
            left: 1,
            width: 399.954,
            top: PlantDatePickerSheet.highlightTop,
            height: PlantDatePickerSheet.rowHeight,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: _highlight,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(color: Color(0x2E000000), blurRadius: 4),
                ],
              ),
            ),
          ),
          // 년·월·일 세 휠. 강조 줄이 가운데 오도록 위로 2줄만큼 올린다.
          Positioned(
            left: 0,
            right: 0,
            top:
                PlantDatePickerSheet.highlightTop -
                PlantDatePickerSheet.rowHeight * 2,
            height: wheelHeight,
            child: Row(
              children: [
                Expanded(
                  child: _Wheel(
                    key: const ValueKey('date_year_wheel'),
                    values: [for (var y = thisYear - 20; y <= thisYear; y++) y],
                    selected: _selected.year,
                    suffix: '년',
                    onChanged: (value) => _update(year: value),
                  ),
                ),
                Expanded(
                  child: _Wheel(
                    key: const ValueKey('date_month_wheel'),
                    values: [for (var m = 1; m <= 12; m++) m],
                    selected: _selected.month,
                    suffix: '월',
                    onChanged: (value) => _update(month: value),
                  ),
                ),
                Expanded(
                  child: _Wheel(
                    key: const ValueKey('date_day_wheel'),
                    values: [
                      for (
                        var d = 1;
                        d <=
                            DateTime(
                              _selected.year,
                              _selected.month + 1,
                              0,
                            ).day;
                        d++
                      )
                        d,
                    ],
                    selected: _selected.day,
                    suffix: '일',
                    onChanged: (value) => _update(day: value),
                  ),
                ),
              ],
            ),
          ),
          // 버튼 2568:1711. 흰 배경 + 오렌지 글자라 PrimaryButton의 background를
          // 뒤집어 쓴다. SafeArea는 시트가 이미 바닥에 붙어 있어 넣지 않는다.
          Positioned(
            left: 34,
            width: 334,
            top: PlantDatePickerSheet.buttonTop,
            height: 51,
            child: PrimaryButton(
              label: '수정하기',
              variant: PrimaryButtonVariant.enabled,
              background: kBackgroundWhite,
              textStyle: kButtonStyle.copyWith(color: kOrangeMain),
              onPressed: () => Navigator.of(context).pop(_selected),
            ),
          ),
          // 핸들바 2568:1685. 시트 안 y=846.11-549.
          Positioned(
            left: 120.702,
            width: 160.595,
            top: 846.112 - 549,
            height: 6.436,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFF8E8E8E),
                borderRadius: BorderRadius.circular(3.218),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 한 자리 숫자 휠. 시안(2568:1687~1710)은 위아래 2줄씩 흐리게 보인다.
/// 안 고른 줄은 흰색 80% 16 Medium, 고른 줄은 흰색 18 SemiBold.
class _Wheel extends StatefulWidget {
  const _Wheel({
    super.key,
    required this.values,
    required this.selected,
    required this.suffix,
    required this.onChanged,
  });

  final List<int> values;
  final int selected;
  final String suffix;
  final ValueChanged<int> onChanged;

  @override
  State<_Wheel> createState() => _WheelState();
}

class _WheelState extends State<_Wheel> {
  late final FixedExtentScrollController _controller =
      FixedExtentScrollController(
        initialItem: widget.values.indexOf(widget.selected).clamp(
          0,
          widget.values.length - 1,
        ),
      );

  @override
  void didUpdateWidget(_Wheel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 달을 바꿔 날짜 수가 줄면 휠이 범위를 벗어나므로 되돌려 놓는다.
    final index = widget.values.indexOf(widget.selected);
    if (index >= 0 && _controller.hasClients && _controller.selectedItem != index) {
      _controller.jumpToItem(index);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListWheelScrollView.useDelegate(
      controller: _controller,
      itemExtent: PlantDatePickerSheet.rowHeight,
      diameterRatio: 100,
      physics: const FixedExtentScrollPhysics(),
      onSelectedItemChanged: (i) => widget.onChanged(widget.values[i]),
      childDelegate: ListWheelChildBuilderDelegate(
        childCount: widget.values.length,
        builder: (context, i) {
          final selected = widget.values[i] == widget.selected;
          return Center(
            child: Text(
              '${widget.values[i]}${widget.suffix}',
              style: TextStyle(
                fontFamily: kFontFamily,
                fontSize: selected ? 18 : 16,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: selected ? Colors.white : Colors.white.withValues(alpha: 0.8),
              ),
            ),
          );
        },
      ),
    );
  }
}
