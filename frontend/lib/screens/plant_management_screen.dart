import 'package:flutter/material.dart';
import 'package:yeso_plant/services/leafie_api_client.dart';
import 'package:yeso_plant/services/plant_management_api.dart';
import 'package:yeso_plant/theme/app_colors.dart';
import 'package:yeso_plant/theme/app_layout.dart';
import 'package:yeso_plant/theme/app_text_styles.dart';
import 'package:yeso_plant/widgets/plant_character_art.dart';
import 'package:yeso_plant/widgets/primary_button.dart';
import 'package:yeso_plant/widgets/yeso_app_bar.dart';

class PlantManagementScreen extends StatefulWidget {
  const PlantManagementScreen({
    super.key,
    this.repository,
    this.onSelectedPlantChanged,
    this.onAddPlant,
  });

  final PlantManagementRepository? repository;
  final ValueChanged<String?>? onSelectedPlantChanged;
  final VoidCallback? onAddPlant;

  @override
  State<PlantManagementScreen> createState() => _PlantManagementScreenState();
}

class _PlantManagementScreenState extends State<PlantManagementScreen> {
  late final PlantManagementRepository _repository =
      widget.repository ?? PlantManagementApi();
  List<ManagedPlant> _plants = const [];
  bool _loading = true;
  String? _busyPlantId;

  @override
  void initState() {
    super.initState();
    _loadPlants();
  }

  Future<void> _loadPlants() async {
    setState(() => _loading = true);
    try {
      final plants = await _repository.listPlants();
      if (mounted) setState(() => _plants = plants);
    } on LeafieApiException catch (error) {
      if (mounted) _showError(error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _selectPlant(ManagedPlant plant) async {
    if (plant.isSelected || _busyPlantId != null) return;
    setState(() => _busyPlantId = plant.id);
    try {
      final selectedId = await _repository.selectPlant(plant.id);
      if (!mounted) return;
      setState(() {
        _plants = [
          for (final item in _plants)
            item.copyWith(isSelected: item.id == selectedId),
        ];
      });
      widget.onSelectedPlantChanged?.call(selectedId);
    } on LeafieApiException catch (error) {
      if (mounted) _showError(error.message);
    } finally {
      if (mounted) setState(() => _busyPlantId = null);
    }
  }

  Future<void> _renamePlant(ManagedPlant plant) async {
    var draftNickname = plant.nickname;
    final nickname = await showDialog<String>(
      context: context,
      barrierColor: kModalBarrier,
      builder: (context) => AlertDialog(
        title: const Text('식물 이름 변경', style: kItemStyle),
        content: TextFormField(
          key: const ValueKey('plant_nickname_field'),
          initialValue: plant.nickname,
          autofocus: true,
          maxLength: 100,
          style: kBodyStyle,
          decoration: const InputDecoration(hintText: '식물 이름을 입력하세요.'),
          onChanged: (value) => draftNickname = value,
          onFieldSubmitted: (value) => Navigator.pop(context, value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            key: const ValueKey('confirm_plant_rename'),
            onPressed: () => Navigator.pop(context, draftNickname.trim()),
            child: const Text('변경'),
          ),
        ],
      ),
    );
    if (nickname == null || nickname.isEmpty || nickname == plant.nickname) {
      return;
    }
    await _mutatePlant(
      plant.id,
      () => _repository.updateNickname(plant.id, nickname),
    );
  }

  Future<void> _editAppearance(ManagedPlant plant) async {
    final selectedColor = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      backgroundColor: kBackgroundWhite,
      builder: (context) => _AppearanceSheet(plant: plant),
    );
    if (selectedColor == null || selectedColor == plant.colorId) return;
    await _mutatePlant(
      plant.id,
      () => _repository.updateAppearance(plant.id, colorId: selectedColor),
    );
  }

  Future<void> _deletePlant(ManagedPlant plant) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: kModalBarrier,
      builder: (context) => AlertDialog(
        title: const Text('식물 삭제', style: kItemStyle),
        content: Text(
          '${plant.nickname}와 관련된 일정과 기록도 함께 삭제돼요.',
          style: kSmallStyle.copyWith(color: kTextDark),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            key: const ValueKey('confirm_plant_delete'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제', style: TextStyle(color: kErrorRed)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busyPlantId = plant.id);
    try {
      await _repository.deletePlant(plant.id);
      final plants = await _repository.listPlants();
      if (!mounted) return;
      setState(() => _plants = plants);
      widget.onSelectedPlantChanged?.call(
        plants.where((item) => item.isSelected).firstOrNull?.id,
      );
    } on LeafieApiException catch (error) {
      if (mounted) _showError(error.message);
    } finally {
      if (mounted) setState(() => _busyPlantId = null);
    }
  }

  Future<void> _mutatePlant(
    String plantId,
    Future<ManagedPlant> Function() request,
  ) async {
    setState(() => _busyPlantId = plantId);
    try {
      final updated = await request();
      if (!mounted) return;
      setState(() {
        _plants = [
          for (final plant in _plants)
            if (plant.id == plantId)
              updated.copyWith(isSelected: plant.isSelected)
            else
              plant,
        ];
      });
    } on LeafieApiException catch (error) {
      if (mounted) _showError(error.message);
    } finally {
      if (mounted) setState(() => _busyPlantId = null);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundWhite,
      appBar: YesoAppBar(
        title: '식물 관리',
        actions: [
          IconButton(
            key: const ValueKey('add_plant'),
            tooltip: '식물 등록',
            onPressed: widget.onAddPlant,
            icon: const Icon(Icons.add, color: kOrangeMain),
          ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: kOrangeMain))
            : _plants.isEmpty
            ? _EmptyPlants(onAddPlant: widget.onAddPlant)
            : RefreshIndicator(
                color: kOrangeMain,
                onRefresh: _loadPlants,
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    AppLayout.myPageHorizontalPadding,
                    24,
                    AppLayout.myPageHorizontalPadding,
                    32,
                  ),
                  itemCount: _plants.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 14),
                  itemBuilder: (context, index) {
                    final plant = _plants[index];
                    return _PlantCard(
                      plant: plant,
                      busy: _busyPlantId == plant.id,
                      onSelect: () => _selectPlant(plant),
                      onRename: () => _renamePlant(plant),
                      onAppearance: () => _editAppearance(plant),
                      onDelete: () => _deletePlant(plant),
                    );
                  },
                ),
              ),
      ),
    );
  }
}

class _PlantCard extends StatelessWidget {
  const _PlantCard({
    required this.plant,
    required this.busy,
    required this.onSelect,
    required this.onRename,
    required this.onAppearance,
    required this.onDelete,
  });

  final ManagedPlant plant;
  final bool busy;
  final VoidCallback onSelect;
  final VoidCallback onRename;
  final VoidCallback onAppearance;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 150),
      opacity: busy ? 0.55 : 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: plant.isSelected ? kProfileCardYellow : kBackgroundWhite,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: plant.isSelected ? kOrangeMain : const Color(0xFFE8E8E8),
            width: plant.isSelected ? 2 : 1,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 5,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 10, 10),
          child: Column(
            children: [
              InkWell(
                key: ValueKey('select_plant_${plant.id}'),
                onTap: busy ? null : onSelect,
                borderRadius: BorderRadius.circular(16),
                child: Row(
                  children: [
                    const PlantCharacterArt(width: 66, sprouted: true),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(plant.nickname, style: kItemStyle),
                              ),
                              if (plant.isSelected) ...[
                                const SizedBox(width: 7),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: kOrangeMain,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    '선택됨',
                                    style: kCaptionStyle.copyWith(
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 5),
                          Text(
                            '${plant.speciesDisplayName} · 함께한 지 ${plant.daysTogether}일',
                            style: kSmallStyle,
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      plant.isSelected
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                      color: plant.isSelected ? kOrangeMain : kGrayLightest,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _CardAction(label: '이름 변경', onTap: busy ? null : onRename),
                  _CardAction(label: '꾸미기', onTap: busy ? null : onAppearance),
                  _CardAction(
                    label: '삭제',
                    color: kErrorRed,
                    onTap: busy ? null : onDelete,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CardAction extends StatelessWidget {
  const _CardAction({required this.label, required this.onTap, this.color});

  final String label;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      child: Text(
        label,
        style: kCaptionStyle.copyWith(color: color ?? kTextDark),
      ),
    );
  }
}

class _EmptyPlants extends StatelessWidget {
  const _EmptyPlants({required this.onAddPlant});

  final VoidCallback? onAddPlant;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppLayout.registrationHorizontalPadding,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const PlantCharacterArt(width: 150),
          const SizedBox(height: 24),
          const Text('등록된 식물이 없어요', style: kTitleStyle),
          const SizedBox(height: 8),
          const Text('식물을 등록하면 여기에서 전환하고 관리할 수 있어요.', style: kSmallStyle),
          const SizedBox(height: 30),
          PrimaryButton(
            label: '식물 등록하기',
            variant: onAddPlant == null
                ? PrimaryButtonVariant.disabled
                : PrimaryButtonVariant.enabled,
            onPressed: onAddPlant,
          ),
        ],
      ),
    );
  }
}

class _AppearanceSheet extends StatefulWidget {
  const _AppearanceSheet({required this.plant});

  final ManagedPlant plant;

  @override
  State<_AppearanceSheet> createState() => _AppearanceSheetState();
}

class _AppearanceSheetState extends State<_AppearanceSheet> {
  static const _colors = <String, Color>{
    'color_orange_01': Color(0xFFFFC98B),
    'color_purple_01': Color(0xFFD9B3FA),
    'color_mint_01': Color(0xFFA8E6C1),
    'color_yellow_01': Color(0xFFFFF176),
    'color_red_01': Color(0xFFFF8A8A),
    'color_skyblue_01': Color(0xFFA8D8FF),
    'color_blue_01': Color(0xFF7FA6F5),
    'color_gray_01': Color(0xFFB0B0B0),
    'color_pink_01': Color(0xFFFFC1DA),
  };

  late String _selected = widget.plant.colorId;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(34, 4, 34, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${widget.plant.nickname} 꾸미기', style: kTitleStyle),
            const SizedBox(height: 8),
            const Text('헤어와 액세서리는 디자인 확정 후 추가돼요.', style: kSmallStyle),
            const SizedBox(height: 24),
            Wrap(
              spacing: 14,
              runSpacing: 14,
              alignment: WrapAlignment.center,
              children: [
                for (final entry in _colors.entries)
                  GestureDetector(
                    key: ValueKey('appearance_${entry.key}'),
                    onTap: () => setState(() => _selected = entry.key),
                    child: Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: entry.value,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _selected == entry.key
                              ? kOrangeMain
                              : Colors.white,
                          width: _selected == entry.key ? 4 : 2,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 28),
            PrimaryButton(
              label: '적용하기',
              variant: PrimaryButtonVariant.enabled,
              onPressed: () => Navigator.pop(context, _selected),
            ),
          ],
        ),
      ),
    );
  }
}
