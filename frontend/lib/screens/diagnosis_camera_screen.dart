import 'dart:async';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:yeso_plant/theme/app_text_styles.dart';
import 'package:yeso_plant/widgets/figma_asset_icons.dart';

/// 초점 가이드 SVG 캔버스(288×287)가 노드(269.96×268.05)보다 사방으로
/// 넘치는 폭. 스트로크가 캔버스 밖으로 잘리지 않게 넣어 둔 여백이다.
const double _kFocusBleed = 9;

/// 시안이 그려진 기기의 상태바 높이. SafeArea 안에서는 시안 절대 y에서
/// 이만큼 빼야 같은 자리에 앉는다.
const double _kStatusBar = 46;

/// 카메라를 열어 주는 함수. 테스트가 갈아끼운다.
typedef CameraOpener = Future<List<CameraDescription>> Function();

/// 앨범에서 한 장 고르는 함수. 테스트가 갈아끼운다.
typedef AlbumPicker = Future<Uint8List?> Function();

/// Figma 4534:20001 "홈_진단 9". 앱 안에서 직접 찍는 카메라.
///
/// OS 카메라(`ImagePicker`)와 달리 초점 가이드와 플래시를 시안대로 그린다.
/// 찍은 사진은 바이트로 돌려주고, 확인 화면은 부르는 쪽이 띄운다.
class DiagnosisCameraScreen extends StatefulWidget {
  const DiagnosisCameraScreen({
    super.key,
    this.title = '내 식물 찾기',
    this.openCameras = availableCameras,
    this.albumPicker,
  });

  /// 진단은 '내 식물 찾기', 등록 흐름은 다른 제목을 쓸 수 있다.
  final String title;
  final CameraOpener openCameras;
  final AlbumPicker? albumPicker;

  @override
  State<DiagnosisCameraScreen> createState() => _DiagnosisCameraScreenState();
}

class _DiagnosisCameraScreenState extends State<DiagnosisCameraScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  Future<void>? _ready;
  bool _busy = false;
  bool _flashOn = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ready = _start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    // 앱이 내려가면 카메라를 놓아 주고, 돌아오면 다시 잡는다.
    // dispose 후에는 setState로 즉시 리빌드해야 이미 해제된 컨트롤러를
    // 참조하는 CameraPreview가 화면에 남지 않는다(로딩 상태로 전환).
    if (state == AppLifecycleState.inactive) {
      controller.dispose();
      if (mounted) setState(() => _controller = null);
    } else if (state == AppLifecycleState.resumed) {
      setState(() => _ready = _start());
    }
  }

  Future<void> _start() async {
    try {
      final cameras = await widget.openCameras();
      if (cameras.isEmpty) {
        throw CameraException('NO_CAMERA', '쓸 수 있는 카메라가 없어요.');
      }
      final back = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        back,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _error = null;
      });
    } on CameraException catch (error) {
      if (mounted) {
        setState(() => _error = error.description ?? '카메라를 열 수 없어요.');
      }
    }
  }

  Future<void> _shoot() async {
    final controller = _controller;
    if (_busy || controller == null || !controller.value.isInitialized) return;
    setState(() => _busy = true);
    try {
      final shot = await controller.takePicture();
      final bytes = await shot.readAsBytes();
      if (mounted) Navigator.of(context).pop(bytes);
    } on CameraException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.description ?? '사진을 찍지 못했어요.')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleFlash() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    final next = !_flashOn;
    try {
      await controller.setFlashMode(next ? FlashMode.torch : FlashMode.off);
      if (mounted) setState(() => _flashOn = next);
    } on CameraException {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('플래시를 켤 수 없어요.')));
    }
  }

  Future<void> _openAlbum() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final bytes = await (widget.albumPicker ?? _pickFromAlbum)();
      if (bytes != null && mounted) Navigator.of(context).pop(bytes);
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('앨범을 열 수 없어요.')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _preview(),
          // 4534:20026 초점 가이드 x66 y303 269.96×268.05. 미리보기와 같은
          // 절대 좌표계에 둬야 해서 SafeArea 밖에 얹는다. 내보낸 SVG
          // 캔버스(288×287)는 스트로크가 사방 9px씩 넘쳐 그만큼 보정한다.
          Positioned(
            left: 66 - _kFocusBleed,
            top: 303 - _kFocusBleed,
            width: 269.961 + _kFocusBleed * 2,
            height: 268.052 + _kFocusBleed * 2,
            child: IgnorePointer(
              child: SvgPicture.asset(
                'assets/images/icon_camera_focus.svg',
                fit: BoxFit.fill,
              ),
            ),
          ),
          // 시안은 상태바 위까지 미리보기가 찬다. 조작은 SafeArea 안에 둔다.
          SafeArea(
            child: Stack(
              children: [
                // 4534:20042 뒤로가기 x21.5 y60 → 앱바 밴드(46) 기준 14.
                Positioned(
                  left: 21.5 - 12,
                  top: 60 - _kStatusBar - 12,
                  child: IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const FigmaBackChevron(color: Colors.white),
                    tooltip: '뒤로',
                  ),
                ),
                // 4534:20022 제목 y60.
                Positioned(
                  left: 0,
                  right: 0,
                  top: 60 - _kStatusBar,
                  child: Center(
                    child: Text(
                      widget.title,
                      style: kBodyStyle.copyWith(color: Colors.white),
                    ),
                  ),
                ),
                _bottomBar(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _preview() {
    final error = _error;
    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 34),
          child: Text(
            error,
            textAlign: TextAlign.center,
            style: kBodyStyle.copyWith(color: Colors.white),
          ),
        ),
      );
    }
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return FutureBuilder<void>(
        future: _ready,
        builder: (context, _) =>
            const Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }
    // 미리보기는 화면을 가득 채우되 비율을 지킨다.
    return FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(
        width: controller.value.previewSize?.height ?? 1,
        height: controller.value.previewSize?.width ?? 1,
        child: CameraPreview(controller),
      ),
    );
  }

  /// 4534:20023 셔터 x168 y761.23 65.77, 4534:20037 앨범 x52 y779 33.24×33,
  /// 4534:20041 플래시 x325 y774 24.82×42.10. y는 바닥에서 잰다.
  Widget _bottomBar() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 874 - 827 - 34,
      height: 66,
      child: Stack(
        children: [
          // 탭 범위를 48로 넓혔으므로 그림이 시안 x·y에 오도록 그만큼 당긴다.
          Positioned(
            left: 52 - _IconButton.padFor(33.24),
            top: 779 - 761.234 - _IconButton.padFor(33),
            child: _IconButton(
              asset: 'assets/images/icon_camera_album.svg',
              size: const Size(33.24, 33),
              label: '앨범에서 고르기',
              onTap: _openAlbum,
            ),
          ),
          Positioned(
            left: 168,
            top: 0,
            child: Semantics(
              button: true,
              label: '사진 찍기',
              child: GestureDetector(
                onTap: _shoot,
                behavior: HitTestBehavior.opaque,
                child: Opacity(
                  opacity: _busy ? 0.5 : 1,
                  child: SvgPicture.asset(
                    'assets/images/icon_camera_shutter.svg',
                    width: 65.765,
                    height: 65.765,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 325 - _IconButton.padFor(24.822),
            top: 774 - 761.234 - _IconButton.padFor(42.102),
            child: Opacity(
              // 켜져 있을 때만 또렷하게 둔다. 시안엔 켠 상태가 없다.
              opacity: _flashOn ? 1 : 0.6,
              child: _IconButton(
                asset: 'assets/images/icon_camera_flash.svg',
                size: const Size(24.822, 42.102),
                label: _flashOn ? '플래시 끄기' : '플래시 켜기',
                onTap: _toggleFlash,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IconButton extends StatelessWidget {
  const _IconButton({
    required this.asset,
    required this.size,
    required this.label,
    required this.onTap,
  });

  final String asset;
  final Size size;
  final String label;
  final VoidCallback onTap;

  /// 아이콘이 작아 손가락보다 좁다. 그림은 그대로 두고 탭 범위만 48로 넓힌다.
  static double padFor(double side) => ((48 - side) / 2).clamp(0.0, 48.0);

  @override
  Widget build(BuildContext context) {
    final padX = padFor(size.width);
    final padY = padFor(size.height);
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: padX, vertical: padY),
          child: SvgPicture.asset(
            asset,
            width: size.width,
            height: size.height,
          ),
        ),
      ),
    );
  }
}

Future<Uint8List?> _pickFromAlbum() async {
  final picked = await ImagePicker().pickImage(
    source: ImageSource.gallery,
    maxWidth: 1600,
    imageQuality: 88,
    requestFullMetadata: false,
  );
  if (picked == null) return null;
  return Uint8List.fromList(await picked.readAsBytes());
}
