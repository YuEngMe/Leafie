import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:yeso_plant/screens/diagnosis_camera_screen.dart';
import 'package:yeso_plant/services/diagnosis_api.dart';
import 'package:yeso_plant/services/home_api.dart';
import 'package:yeso_plant/services/leafie_api_client.dart';
import 'package:yeso_plant/theme/app_colors.dart';
import 'package:yeso_plant/theme/app_layout.dart';
import 'package:yeso_plant/theme/app_text_styles.dart';
import 'package:yeso_plant/widgets/diagnosis_components.dart';
import 'package:yeso_plant/widgets/photo_confirm_bar.dart';
import 'package:yeso_plant/widgets/primary_button.dart';
import 'package:yeso_plant/widgets/retry_feedback.dart';
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

  /// 오류 화면을 둔 채 다시 불러오고, 성공했을 때만 갈아 끼운다. 실패한
  /// Future로 바꾸면 오류 화면이 새로 그려져 RetryFeedback 상태가 사라진다.
  Future<bool> _retryFromError() async {
    final next = _load();
    try {
      await next;
    } catch (_) {
      return false;
    }
    if (mounted) setState(() => _history = next);
    return true;
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
      widget.photoPicker ?? _inAppCamera(context),
    );
    if (photo == null || !mounted) return;
    final submitted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => DiagnosisPhotoConfirmScreen(
          plantId: data.plantId!,
          photo: photo,
          repository: _repository,
          photoPicker: widget.photoPicker ?? _inAppCamera(context),
          imageProviderBuilder: widget.imageProviderBuilder,
        ),
      ),
    );
    if (submitted == true && mounted) _retry();
  }

  Future<void> _openRecord(DiagnosisSummary record) async {
    if (record.status != 'COMPLETED') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            record.status == 'NEEDS_RETAKE'
                ? retakeReasonMessage(record.retakeReasonCode)
                : _summaryStatusMessage(record.status),
          ),
        ),
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
          appBar: YesoAppBar(title: isEmpty ? '' : '진단기록'),
          body: SafeArea(
            top: false,
            child: switch (snapshot.connectionState) {
              != ConnectionState.done => const Center(
                child: CircularProgressIndicator(),
              ),
              _ when snapshot.hasError => _DiagnosisErrorState(
                message: _errorMessage(snapshot.error),
                onRetry: _retryFromError,
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

  /// 재시도·취소가 도는 동안 버튼을 잠근다.
  bool _busy = false;

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

  /// 오류 화면을 둔 채 다시 불러오고, 성공했을 때만 갈아 끼운다.
  Future<bool> _retryFromError() async {
    final next = _load();
    try {
      await next;
    } catch (_) {
      return false;
    }
    if (mounted) setState(() => _prescription = next);
    return true;
  }

  /// 서버가 받아 주는 실패만 같은 사진으로 다시 맡긴다. 재시도 불가한
  /// 실패(사진 문제 등)는 버튼이 뜨지 않지만, 서버가 409를 주면 그 문구를
  /// 그대로 보여 준다.
  Future<void> _retryOnServer() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _repository.retryDiagnosis(widget.diagnosisId);
      if (!mounted) return;
      setState(() {
        _prescription = _load();
      });
    } on LeafieApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// 아직 시작하지 않은 진단을 접는다.
  Future<void> _cancelOnServer() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _repository.cancelDiagnosis(widget.diagnosisId);
      if (!mounted) return;
      setState(() {
        _prescription = _load();
      });
    } on LeafieApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _startAgain(String plantId) async {
    final callback = widget.onStartDiagnosis;
    if (callback != null) {
      callback();
      return;
    }
    final photo = await _captureDiagnosisPhoto(
      context,
      widget.photoPicker ?? _inAppCamera(context),
    );
    if (photo == null || !mounted) return;
    final submitted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => DiagnosisPhotoConfirmScreen(
          plantId: plantId,
          photo: photo,
          repository: _repository,
          photoPicker: widget.photoPicker ?? _inAppCamera(context),
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
                onRetry: _retryFromError,
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
                      symptoms: _symptomsFor(diagnosis),
                      causes: _prescriptionCauses(diagnosis.possibleCauses),
                      recommendations: _condenseItems(
                        diagnosis.recommendedCare.map(_firstSentence).toList(),
                      ),
                      onClose: () => Navigator.maybePop(context),
                      plantName: data.plant.nickname,
                    ),
                  ),
                  // 서버가 받아 주는 동작만 띄운다. 재시도 가능한 실패는
                  // 같은 사진으로 다시, 대기 중이면 취소, 그 밖에는 새 사진.
                  Positioned(
                    left: 34,
                    top: 698,
                    child: _PrescriptionAction(
                      diagnosis: diagnosis,
                      busy: _busy,
                      onRetry: _retryOnServer,
                      onCancel: _cancelOnServer,
                      onStartAgain: () => _startAgain(diagnosis.plantId),
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
          _error = diagnosis.status == 'NEEDS_RETAKE'
              ? retakeReasonMessage(diagnosis.retakeReasonCode)
              : _submissionStatusMessage(diagnosis.status);
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
    // 시안(4534:20043) 막대 4534:20064. 자리와 버튼은 [PhotoConfirmBar].
    final actionBarHeight = PhotoConfirmBar.heightOf(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: PopScope(
        canPop: !_submitting,
        child: Scaffold(
          backgroundColor: Colors.black,
          extendBodyBehindAppBar: true,
          appBar: YesoAppBar(
            title: '',
            // 시안(4534-20043)엔 상단 뒤로가 없음. '다시 촬영'이 되돌아가는 역할.
            showBack: false,
            // 시안은 사진이 맨 위까지 그대로 보인다.
            backgroundColor: Colors.transparent,
            backIconColor: Colors.white,
          ),
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
                child: PhotoConfirmBar(
                  retakeKey: const ValueKey('diagnosis-retake-button'),
                  nextKey: const ValueKey('diagnosis-submit-button'),
                  onRetake: _submitting ? null : _retake,
                  onNext: _submitting ? null : _submit,
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

/// 시안 4534:20001의 인앱 카메라를 띄운다. 예전에는 OS 카메라를 썼지만
/// 초점 가이드·플래시·앨범이 시안에 있어 앱 안에서 찍는다.
DiagnosisPhotoPicker _inAppCamera(BuildContext context) => () async {
  final bytes = await Navigator.of(context).push<Uint8List>(
    MaterialPageRoute(builder: (_) => const DiagnosisCameraScreen()),
  );
  return bytes == null ? null : DiagnosisPhoto(bytes);
};

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

/// 서버가 사진을 다시 찍으라고 한 이유(`retake_reason_code`)를 사용자 문구로
/// 바꾼다. 예전에는 이유와 상관없이 같은 문구라 무엇을 고칠지 몰랐다(10/31).
/// 코드는 백엔드 integrations/diagnosis.py(사진 품질)·kindwise.py(식물 여부).
String retakeReasonMessage(String? reasonCode) => switch (reasonCode) {
  'PLANT_NOT_VISIBLE' => '사진에서 식물을 찾지 못했어요. 식물이 잘 보이게 다시 찍어 주세요.',
  'IMAGE_TOO_DARK' => '사진이 너무 어두워요. 밝은 곳에서 다시 찍어 주세요.',
  'IMAGE_TOO_BRIGHT' => '사진이 너무 밝아요. 빛이 덜 비치는 곳에서 다시 찍어 주세요.',
  'IMAGE_BLURRY' => '사진이 흐려요. 흔들리지 않게 초점을 맞춰 다시 찍어 주세요.',
  'IMAGE_TOO_SMALL' => '사진이 너무 작아요. 식물을 가까이에서 다시 찍어 주세요.',
  'IMAGE_TYPE_UNSUPPORTED' => '지원하지 않는 사진 형식이에요. 카메라로 다시 찍어 주세요.',
  'IMAGE_INVALID' => '사진을 읽지 못했어요. 다시 찍어 주세요.',
  _ => '사진을 다시 촬영해주세요.',
};

String _submissionStatusMessage(String status) => switch (status) {
  'FAILED' => '진단을 완료하지 못했습니다. 새 사진으로 다시 시도해 주세요.',
  'CANCELLED' => '진단 요청이 취소됐습니다.',
  _ => '진단이 진행 중이에요. 잠시 후 진단 기록에서 확인해 주세요.',
};

/// 시안 좌표(본문 기준)를 그대로 쓰는 본문 틀.
///
/// 기준 높이는 지원 기기의 실제 본문 높이다: 874 − 상태바 46 − 앱바 46 −
/// 하단 안전 영역 34 = 748. 이 값이 실제와 다르면 FittedBox가 세로로 늘이거나
/// 눌러 글자·버튼이 시안에서 벗어난다(예전 빈 상태 795는 0.94배로 눌렸다).
class _ReferenceBody extends StatelessWidget {
  const _ReferenceBody({required this.child});

  static const double referenceHeight = 748;

  final Widget child;

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
        // 4534:19705 제목 글자 y390~409(본문 기준 298~317). 예전엔 기준
        // 높이 795를 실제 본문 748에 눌러 담아 글자가 5~9px 위로, 버튼이
        // 51→48로 줄었다. Flutter 글자 상자가 시안보다 커서 보이는 글자
        // 윗변이 390에 오도록 297로 둔다.
        const Positioned(
          left: 0,
          right: 0,
          top: 297,
          child: Center(child: DiagnosisEmptyState()),
        ),
        // 4534:19703 버튼 y790 → 본문 기준 698(목록 화면과 같은 자리).
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
        // 4534:19874·19875 절 제목은 시안 SemiBold 16에서 디자이너 요청으로
        // 1 키운 17. 글자 상자가 시안보다 커서 시안 top(140·267.2)에서 2를
        // 빼야 보이는 글자가 맞는다.
        Positioned(
          left: 34,
          top: 46,
          child: Text('오늘의 진단', style: kItemStyle.copyWith(fontSize: 17)),
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
        Positioned(
          left: 34,
          top: 173.2,
          child: Text('지난 진단', style: kItemStyle.copyWith(fontSize: 17)),
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
        child: Text(emptyLabel, style: kCaptionStyle.copyWith(fontSize: 13)),
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
  final Future<bool> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return RetryFeedback(
      onRetry: onRetry,
      builder: (context, phase, retry) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              phase == RetryPhase.failed ? kRetryFailedMessage : message,
              style: kSmallStyle,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: retry,
              child: Text(phase == RetryPhase.busy ? kRetryBusyLabel : '다시 시도'),
            ),
          ],
        ),
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

/// 백엔드 `RETRYABLE_FAILURE_CODES`(app/services/diagnosis.py:34)와 같은
/// 목록. 이 코드로 실패했을 때만 서버가 같은 사진 재시도를 받아 준다.
const _kRetryableFailureCodes = {
  'DATABASE_UNAVAILABLE',
  'DIAGNOSIS_EXTERNAL_TIMEOUT',
  'DIAGNOSIS_PROVIDER_UNAVAILABLE',
  'DIAGNOSIS_RETRY_EXHAUSTED',
  'DIAGNOSIS_UNEXPECTED_ERROR',
  'KINDWISE_INVALID_RESPONSE',
  'STORAGE_UNAVAILABLE',
};

/// 처방전 하단 버튼. 진단 상태에 따라 서버가 허용하는 동작만 띄운다.
///
/// - 재시도 가능한 실패: '다시 시도하기'(같은 사진, `POST /retry`)
/// - 대기 중: '진단 취소하기'(`POST /cancel`)
/// - 그 밖: '다시 진단하기'(새 사진)
class _PrescriptionAction extends StatelessWidget {
  const _PrescriptionAction({
    required this.diagnosis,
    required this.busy,
    required this.onRetry,
    required this.onCancel,
    required this.onStartAgain,
  });

  final DiagnosisDetailData diagnosis;
  final bool busy;
  final VoidCallback onRetry;
  final VoidCallback onCancel;
  final VoidCallback onStartAgain;

  bool get _canRetryOnServer =>
      diagnosis.status == 'FAILED' &&
      _kRetryableFailureCodes.contains(diagnosis.failureCode);

  bool get _canCancel => diagnosis.status == 'PENDING';

  @override
  Widget build(BuildContext context) {
    final (label, onPressed) = switch (this) {
      _ when _canRetryOnServer => ('다시 시도하기', onRetry),
      _ when _canCancel => ('진단 취소하기', onCancel),
      _ => ('다시 진단하기', onStartAgain),
    };
    return PrimaryButton(
      key: ValueKey('diagnosis-action-$label'),
      width: 334,
      label: busy ? '처리 중...' : label,
      variant: busy
          ? PrimaryButtonVariant.disabled
          : PrimaryButtonVariant.enabled,
      onPressed: busy ? null : onPressed,
    );
  }
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

/// 원인 이름 속 말로 짐작한 증상(시안 4534:19767처럼 '잎 마름' 같은 짧은 말).
///
/// 서버 증상은 '건강 이상 가능성' 하나뿐이다. Kindwise는 원인 후보만 주고
/// 증상은 주지 않아 백엔드가 지어내지 않았다(kindwise.py 주석). 시안처럼
/// 짧은 증상을 보여 달라는 요청(10/31)에 따라 원인에서 흔히 나타나는 증상을
/// 짐작해 보여 준다. 사진에서 본 증상이 아니라는 점을 알고 쓴다.
const List<(List<String>, String)> _kCauseSymptoms = [
  (['과습', '배수'], '잎 처짐'),
  (['물 부족', '건조', '가뭄'], '잎 마름'),
  (['영양', '결핍', '질소', '칼륨'], '잎 변색'),
  (['빛 부족', '햇빛 부족', '그늘'], '웃자람'),
  (['화상', '일소'], '잎 탐'),
  (['곰팡이', '흰가루', '녹병', '균'], '잎 반점'),
  (['해충', '벌레', '진딧물', '응애', '깍지'], '벌레 흔적'),
  (['세균', '박테리아', '무름'], '잎 무름'),
  (['냉해', '저온'], '냉해 흔적'),
  (['뿌리'], '뿌리 상함'),
];

/// 원인 순서대로 짐작한 증상을 최대 3개 고른다. 하나도 못 짐작하면 서버
/// 증상을 그대로 쓴다.
List<String> _symptomsFor(DiagnosisDetailData diagnosis) {
  final symptoms = <String>[];
  for (final cause in diagnosis.possibleCauses) {
    for (final (keywords, symptom) in _kCauseSymptoms) {
      if (keywords.any(cause.name.contains) && !symptoms.contains(symptom)) {
        symptoms.add(symptom);
        break;
      }
    }
  }
  if (symptoms.isEmpty) return _condenseItems(diagnosis.observations);
  return symptoms.take(3).toList();
}

/// 추천 관리는 Kindwise 관리법을 옮긴 여러 문장이라 처방전 한 줄을 넘친다.
/// 시안(4534:19777 등)처럼 짧게 첫 문장만 보여 준다(10/31 피드백).
String _firstSentence(String text) {
  final trimmed = text.trim();
  final end = RegExp(r'[.!?。](?=\s|$)').firstMatch(trimmed);
  return end == null ? trimmed : trimmed.substring(0, end.end);
}

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
        percent: switch (causes[index].confidence) {
          final confidence? => (confidence * 100).round().clamp(0, 100),
          null => null,
        },
        color: colors[index],
      ),
  ];
}
