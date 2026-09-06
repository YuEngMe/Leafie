import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:yeso_plant/services/diagnosis_api.dart';
import 'package:yeso_plant/services/home_api.dart';
import 'package:yeso_plant/services/leafie_api_client.dart';
import 'package:yeso_plant/theme/app_colors.dart';
import 'package:yeso_plant/theme/app_layout.dart';
import 'package:yeso_plant/theme/app_text_styles.dart';
import 'package:yeso_plant/widgets/diagnosis_components.dart';
import 'package:yeso_plant/widgets/primary_button.dart';
import 'package:yeso_plant/widgets/yeso_app_bar.dart';

typedef DiagnosisImageProviderBuilder =
    ImageProvider<Object> Function(String url);
typedef DiagnosisPhotoPicker = Future<DiagnosisPhoto?> Function();

class DiagnosisPhoto {
  const DiagnosisPhoto(this.bytes);

  final Uint8List bytes;
}

ImageProvider<Object> _networkImage(String url) => NetworkImage(url);

/// Figma 2346:738(빈 상태), 2346:1345(진단 기록).
class DiagnosisScreen extends StatefulWidget {
  const DiagnosisScreen({
    super.key,
    this.plantId,
    this.plantName,
    this.repository,
    this.loadHome,
    this.onStartDiagnosis,
    this.photoPicker,
    this.now,
    this.imageProviderBuilder = _networkImage,
  });

  final String? plantId;
  final String? plantName;
  final DiagnosisRepository? repository;
  final Future<HomeDashboardData> Function()? loadHome;
  final VoidCallback? onStartDiagnosis;
  final DiagnosisPhotoPicker? photoPicker;
  final DateTime Function()? now;
  final DiagnosisImageProviderBuilder imageProviderBuilder;

  @override
  State<DiagnosisScreen> createState() => _DiagnosisScreenState();
}

class _DiagnosisScreenState extends State<DiagnosisScreen> {
  late final DiagnosisRepository _repository;
  late Future<_DiagnosisHistoryData> _history;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? DiagnosisApi();
    _history = _load();
  }

  Future<_DiagnosisHistoryData> _load() async {
    var plantId = widget.plantId;
    var plantName = widget.plantName;
    if (plantId == null || plantId.isEmpty) {
      final home = await (widget.loadHome ?? HomeApi().fetchHome)();
      plantId = home.plant?.id;
      plantName ??= home.plant?.nickname;
    }
    if (plantId == null || plantId.isEmpty) {
      return _DiagnosisHistoryData(
        plantId: null,
        plantName: plantName ?? '식물',
        records: const [],
      );
    }
    return _DiagnosisHistoryData(
      plantId: plantId,
      plantName: plantName ?? '식물',
      records: await _repository.listDiagnoses(plantId),
    );
  }

  void _retry() {
    setState(() {
      _history = _load();
    });
  }

  Future<void> _startDiagnosis(_DiagnosisHistoryData data) async {
    if (data.plantId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('먼저 식물을 등록해주세요.')));
      return;
    }
    final callback = widget.onStartDiagnosis;
    if (callback != null) {
      callback();
      return;
    }
    final photo = await _captureDiagnosisPhoto(
      context,
      widget.photoPicker ?? _pickDiagnosisPhoto,
    );
    if (photo == null || !mounted) return;
    final submitted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => DiagnosisPhotoConfirmScreen(
          plantId: data.plantId!,
          photo: photo,
          repository: _repository,
          photoPicker: widget.photoPicker ?? _pickDiagnosisPhoto,
          imageProviderBuilder: widget.imageProviderBuilder,
        ),
      ),
    );
    if (submitted == true && mounted) _retry();
  }

  Future<void> _openRecord(DiagnosisSummary record) async {
    if (record.status != 'COMPLETED') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_summaryStatusMessage(record.status))),
      );
      return;
    }
    final submitted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => DiagnosisDetailScreen(
          diagnosisId: record.id,
          repository: _repository,
          imageProviderBuilder: widget.imageProviderBuilder,
          onStartDiagnosis: widget.onStartDiagnosis,
          photoPicker: widget.photoPicker,
        ),
      ),
    );
    if (submitted == true && mounted) _retry();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_DiagnosisHistoryData>(
      future: _history,
      builder: (context, snapshot) {
        final isEmpty =
            snapshot.hasData && snapshot.requireData.records.isEmpty;
        return Scaffold(
          backgroundColor: kBackgroundWhite,
          appBar: isEmpty ? null : const YesoAppBar(title: '진단기록'),
          body: SafeArea(
            top: isEmpty,
            child: switch (snapshot.connectionState) {
              != ConnectionState.done => const Center(
                child: CircularProgressIndicator(),
              ),
              _ when snapshot.hasError => _DiagnosisErrorState(
                message: _errorMessage(snapshot.error),
                onRetry: _retry,
              ),
              _ => _diagnosisBody(snapshot.requireData),
            },
          ),
        );
      },
    );
  }

  Widget _diagnosisBody(_DiagnosisHistoryData data) {
    if (data.records.isEmpty) {
      return _ReferenceBody(
        referenceHeight: 795,
        child: _DiagnosisEmptyBody(
          onStartDiagnosis: () => _startDiagnosis(data),
        ),
      );
    }
    return _ReferenceBody(
      child: _DiagnosisHistoryBody(
        data: data,
        now: (widget.now ?? DateTime.now)(),
        imageProviderBuilder: widget.imageProviderBuilder,
        onStartDiagnosis: () => _startDiagnosis(data),
        onRecordTap: _openRecord,
      ),
    );
  }
}

class DiagnosisDetailScreen extends StatefulWidget {
  const DiagnosisDetailScreen({
    super.key,
    required this.diagnosisId,
    this.repository,
    this.onStartDiagnosis,
    this.photoPicker,
    this.imageProviderBuilder = _networkImage,
  });

  final String diagnosisId;
  final DiagnosisRepository? repository;
  final VoidCallback? onStartDiagnosis;
  final DiagnosisPhotoPicker? photoPicker;
  final DiagnosisImageProviderBuilder imageProviderBuilder;

  @override
  State<DiagnosisDetailScreen> createState() => _DiagnosisDetailScreenState();
}

class _DiagnosisDetailScreenState extends State<DiagnosisDetailScreen> {
  late final DiagnosisRepository _repository;
  late Future<_PrescriptionData> _prescription;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? DiagnosisApi();
    _prescription = _load();
  }

  Future<_PrescriptionData> _load() async {
    final diagnosis = await _repository.getDiagnosis(widget.diagnosisId);
    final plant = await _repository.getPlant(diagnosis.plantId);
    return _PrescriptionData(diagnosis: diagnosis, plant: plant);
  }

  void _retry() {
    setState(() {
      _prescription = _load();
    });
  }

  Future<void> _startAgain(String plantId) async {
    final callback = widget.onStartDiagnosis;
    if (callback != null) {
      callback();
      return;
    }
    final photo = await _captureDiagnosisPhoto(
      context,
      widget.photoPicker ?? _pickDiagnosisPhoto,
    );
    if (photo == null || !mounted) return;
    final submitted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => DiagnosisPhotoConfirmScreen(
          plantId: plantId,
          photo: photo,
          repository: _repository,
          photoPicker: widget.photoPicker ?? _pickDiagnosisPhoto,
          imageProviderBuilder: widget.imageProviderBuilder,
        ),
      ),
    );
    if (submitted == true && mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundWhite,
      appBar: const YesoAppBar(title: '진단하기'),
      body: SafeArea(
        top: false,
        child: FutureBuilder<_PrescriptionData>(
          future: _prescription,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _DiagnosisErrorState(
                message: _errorMessage(snapshot.error),
                onRetry: _retry,
              );
            }
            final data = snapshot.requireData;
            final diagnosis = data.diagnosis;
            return _ReferenceBody(
              child: Stack(
                children: [
                  Positioned(
                    left: 12,
                    top: 6,
                    width: 378.656,
                    height: 643,
                    child: PrescriptionCard(
                      photo: widget.imageProviderBuilder(diagnosis.photoUrl),
                      statusLabel: _diagnosisStatusLabel(diagnosis),
                      patientRows: [
                        ('환자성명', data.plant.nickname),
                        ('식물명', data.plant.speciesDisplayName),
                        ('생년월일', _shortDate(data.plant.startedOn)),
                        ('진단일', _shortDate(diagnosis.diagnosedAt)),
                      ],
                      symptoms: _condenseItems(diagnosis.observations),
                      causes: _prescriptionCauses(diagnosis.possibleCauses),
                      recommendations: _condenseItems(
                        diagnosis.recommendedCare,
                      ),
                      onClose: () => Navigator.maybePop(context),
                    ),
                  ),
                  Positioned(
                    left: 34,
                    top: 698,
                    child: PrimaryButton(
                      width: 334,
                      label: '다시 진단하기',
                      variant: PrimaryButtonVariant.enabled,
                      onPressed: () => _startAgain(diagnosis.plantId),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Figma 2346:809. The live camera is provided by iOS/Android through
/// image_picker; this screen reproduces the app-owned photo confirmation UI.
class DiagnosisPhotoConfirmScreen extends StatefulWidget {
  const DiagnosisPhotoConfirmScreen({
    super.key,
    required this.plantId,
    required this.photo,
    required this.repository,
    required this.photoPicker,
    this.imageProviderBuilder = _networkImage,
  });

  final String plantId;
  final DiagnosisPhoto photo;
  final DiagnosisRepository repository;
  final DiagnosisPhotoPicker photoPicker;
  final DiagnosisImageProviderBuilder imageProviderBuilder;

  @override
  State<DiagnosisPhotoConfirmScreen> createState() =>
      _DiagnosisPhotoConfirmScreenState();
}

class _DiagnosisPhotoConfirmScreenState
    extends State<DiagnosisPhotoConfirmScreen> {
  late DiagnosisPhoto _photo = widget.photo;
  bool _submitting = false;
  String? _error;

  Future<void> _retake() async {
    final photo = await _captureDiagnosisPhoto(context, widget.photoPicker);
    if (photo == null || !mounted) return;
    setState(() {
      _photo = photo;
      _error = null;
    });
  }

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final diagnosis = await widget.repository.submitDiagnosis(
        plantId: widget.plantId,
        photoBytes: _photo.bytes,
      );
      if (!mounted) return;
      if (diagnosis.status != 'COMPLETED') {
        setState(() {
          _submitting = false;
          _error = _submissionStatusMessage(diagnosis.status);
        });
        return;
      }
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => DiagnosisDetailScreen(
            diagnosisId: diagnosis.id,
            repository: widget.repository,
            imageProviderBuilder: widget.imageProviderBuilder,
            photoPicker: widget.photoPicker,
          ),
        ),
      );
      if (mounted) Navigator.of(context).pop(true);
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = _errorMessage(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final actionBarHeight = bottomInset > 34 ? bottomInset + 25 : 59.0;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: PopScope(
        canPop: !_submitting,
        child: Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            fit: StackFit.expand,
            children: [
              Image.memory(
                _photo.bytes,
                key: const ValueKey('diagnosis-confirm-photo'),
                fit: BoxFit.cover,
                gaplessPlayback: true,
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: actionBarHeight,
                child: ColoredBox(
                  color: Colors.black.withValues(alpha: 0.6),
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: 19,
                      right: 13,
                      bottom: bottomInset,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          key: const ValueKey('diagnosis-retake-button'),
                          onPressed: _submitting ? null : _retake,
                          child: const Text(
                            '다시 촬영',
                            style: _captureActionStyle,
                          ),
                        ),
                        TextButton(
                          key: const ValueKey('diagnosis-submit-button'),
                          onPressed: _submitting ? null : _submit,
                          child: const Text('다음', style: _captureActionStyle),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (_submitting)
                const ColoredBox(
                  color: Color(0x73000000),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: kOrangeMain),
                        SizedBox(height: 18),
                        Text(
                          '식물 상태를 진단하고 있어요.',
                          style: TextStyle(
                            color: Colors.white,
                            fontFamily: 'Paperlogy',
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (_error != null)
                Positioned(
                  left: 24,
                  right: 24,
                  bottom: actionBarHeight + 18,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.72),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontFamily: 'Paperlogy',
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

const _captureActionStyle = TextStyle(
  color: Colors.white,
  fontFamily: 'Paperlogy',
  fontSize: 16,
  fontWeight: FontWeight.w500,
);

Future<DiagnosisPhoto?> _pickDiagnosisPhoto() async {
  final picked = await ImagePicker().pickImage(
    source: ImageSource.camera,
    maxWidth: 1600,
    imageQuality: 88,
    requestFullMetadata: false,
  );
  if (picked == null) return null;
  return DiagnosisPhoto(Uint8List.fromList(await picked.readAsBytes()));
}

Future<DiagnosisPhoto?> _captureDiagnosisPhoto(
  BuildContext context,
  DiagnosisPhotoPicker picker,
) async {
  try {
    return await picker();
  } on Object {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('카메라를 사용할 수 없습니다. 다시 시도해 주세요.')),
      );
    }
    return null;
  }
}

String _submissionStatusMessage(String status) => switch (status) {
  'NEEDS_RETAKE' => '식물을 더 밝고 선명하게 촬영해 주세요.',
  'FAILED' => '진단을 완료하지 못했습니다. 새 사진으로 다시 시도해 주세요.',
  'CANCELLED' => '진단 요청이 취소됐습니다.',
  _ => '진단이 진행 중이에요. 잠시 후 진단 기록에서 확인해 주세요.',
};

class _ReferenceBody extends StatelessWidget {
  const _ReferenceBody({required this.child, this.referenceHeight = 749});

  final Widget child;
  final double referenceHeight;

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.fill,
        child: SizedBox(
          width: AppLayout.referenceViewport.width,
          height: referenceHeight,
          child: child,
        ),
      ),
    );
  }
}

class _DiagnosisEmptyBody extends StatelessWidget {
  const _DiagnosisEmptyBody({required this.onStartDiagnosis});

  final VoidCallback onStartDiagnosis;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned(
          left: 0,
          right: 0,
          top: 341,
          child: Center(child: DiagnosisEmptyState()),
        ),
        Positioned(
          left: 34,
          top: 744,
          child: PrimaryButton(
            width: 334,
            label: '진단하기',
            variant: PrimaryButtonVariant.enabled,
            onPressed: onStartDiagnosis,
          ),
        ),
      ],
    );
  }
}

class _DiagnosisHistoryBody extends StatelessWidget {
  const _DiagnosisHistoryBody({
    required this.data,
    required this.now,
    required this.imageProviderBuilder,
    required this.onStartDiagnosis,
    required this.onRecordTap,
  });

  final _DiagnosisHistoryData data;
  final DateTime now;
  final DiagnosisImageProviderBuilder imageProviderBuilder;
  final VoidCallback onStartDiagnosis;
  final ValueChanged<DiagnosisSummary> onRecordTap;

  @override
  Widget build(BuildContext context) {
    final today = data.records.where((item) => _sameDay(item.diagnosedAt, now));
    final past = data.records.where((item) => !_sameDay(item.diagnosedAt, now));
    return Stack(
      children: [
        const Positioned(
          left: 34,
          top: 48,
          child: Text('오늘의 진단', style: kBodyStyle),
        ),
        Positioned(
          left: 14,
          right: 14,
          top: 77,
          height: 82,
          child: _DiagnosisRecordList(
            records: today.toList(),
            plantName: data.plantName,
            imageProviderBuilder: imageProviderBuilder,
            onTap: onRecordTap,
            emptyLabel: '오늘 진단한 기록이 없습니다.',
          ),
        ),
        const Positioned(
          left: 34,
          top: 175.2,
          child: Text('지난 진단', style: kBodyStyle),
        ),
        Positioned(
          left: 14,
          right: 14,
          top: 204.2,
          height: 421,
          child: _DiagnosisRecordList(
            records: past.toList(),
            plantName: data.plantName,
            imageProviderBuilder: imageProviderBuilder,
            onTap: onRecordTap,
            emptyLabel: '지난 진단 기록이 없습니다.',
          ),
        ),
        Positioned(
          left: 34,
          top: 698,
          child: PrimaryButton(
            width: 334,
            label: '진단하기',
            variant: PrimaryButtonVariant.enabled,
            onPressed: onStartDiagnosis,
          ),
        ),
      ],
    );
  }
}

class _DiagnosisRecordList extends StatelessWidget {
  const _DiagnosisRecordList({
    required this.records,
    required this.plantName,
    required this.imageProviderBuilder,
    required this.onTap,
    required this.emptyLabel,
  });

  final List<DiagnosisSummary> records;
  final String plantName;
  final DiagnosisImageProviderBuilder imageProviderBuilder;
  final ValueChanged<DiagnosisSummary> onTap;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(left: 20, top: 17),
        child: Text(emptyLabel, style: kCaptionStyle),
      );
    }
    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: records.length,
      separatorBuilder: (_, _) => const SizedBox(height: 15),
      itemBuilder: (context, index) {
        final record = records[index];
        return DiagnosisRecordTile(
          thumbnail: imageProviderBuilder(record.photoUrl),
          title: '$plantName 진단 기록',
          dateLabel: _historyDate(record.diagnosedAt),
          onTap: () => onTap(record),
        );
      },
    );
  }
}

class _DiagnosisErrorState extends StatelessWidget {
  const _DiagnosisErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, style: kSmallStyle, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          TextButton(onPressed: onRetry, child: const Text('다시 시도')),
        ],
      ),
    );
  }
}

class _DiagnosisHistoryData {
  const _DiagnosisHistoryData({
    required this.plantId,
    required this.plantName,
    required this.records,
  });

  final String? plantId;
  final String plantName;
  final List<DiagnosisSummary> records;
}

class _PrescriptionData {
  const _PrescriptionData({required this.diagnosis, required this.plant});

  final DiagnosisDetailData diagnosis;
  final DiagnosisPlantData plant;
}

String _errorMessage(Object? error) => switch (error) {
  LeafieApiException(:final message) => message,
  _ => '진단 정보를 불러오지 못했어요.',
};

bool _sameDay(DateTime left, DateTime right) {
  final localLeft = left.toLocal();
  final localRight = right.toLocal();
  return localLeft.year == localRight.year &&
      localLeft.month == localRight.month &&
      localLeft.day == localRight.day;
}

String _historyDate(DateTime value) {
  const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
  final local = value.toLocal();
  return '${local.year}. ${local.month}. ${local.day} ${weekdays[local.weekday - 1]}';
}

String _shortDate(DateTime value) {
  final local = value.toLocal();
  String twoDigits(int number) => number.toString().padLeft(2, '0');
  return '${local.year}. ${twoDigits(local.month)}. ${twoDigits(local.day)}';
}

String _diagnosisStatusLabel(DiagnosisDetailData diagnosis) {
  final condition = diagnosis.conditionLabel?.trim();
  if (condition != null && condition.isNotEmpty) return condition;
  return switch (diagnosis.status) {
    'PENDING' => '진단을 기다리고 있어요',
    'PROCESSING' => '진단 중이에요',
    'NEEDS_RETAKE' => '사진을 다시 촬영해주세요',
    'FAILED' => '진단을 완료하지 못했어요',
    'CANCELLED' => '진단이 취소됐어요',
    _ => '진단 결과를 확인했어요',
  };
}

String _summaryStatusMessage(String status) => switch (status) {
  'PENDING' => '진단을 기다리고 있어요.',
  'PROCESSING' => '진단이 진행 중이에요.',
  'NEEDS_RETAKE' => '사진을 다시 촬영해주세요.',
  'FAILED' => '진단을 완료하지 못했어요.',
  'CANCELLED' => '취소된 진단이에요.',
  _ => '아직 처방전을 열 수 없는 진단이에요.',
};

List<String> _condenseItems(List<String> items) {
  if (items.length <= 3) return items;
  return [items[0], items[1], '${items[2]} 외 ${items.length - 3}개'];
}

List<PrescriptionCause> _prescriptionCauses(List<DiagnosisCauseData> causes) {
  const colors = [kCauseOverwater, kCauseLowLight, kCausePest];
  return [
    for (var index = 0; index < causes.take(3).length; index++)
      PrescriptionCause(
        label: causes[index].name,
        percent: ((causes[index].confidence ?? 0) * 100).round().clamp(0, 100),
        color: colors[index],
      ),
  ];
}
