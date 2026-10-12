import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:yeso_plant/theme/app_colors.dart';
import 'package:yeso_plant/theme/app_layout.dart';
import 'package:yeso_plant/theme/app_text_styles.dart';
import 'package:yeso_plant/widgets/figma_glyphs.dart';

// 온보딩 공통 입력칸(Figma nodes 2315:2440, 2315:2457, 2315:2477).
// 테두리 대신 그림자를 쓰고 모서리를 완전히 굴린다. 라벨은 오렌지이고,
// 로그인 화면처럼 라벨이 없는 자리에서는 label을 비워 둔다.
/// 오류 문구 한 줄이 차지하는 높이(top 6 + 12px 글자).
const double _errorRowHeight = 18;

/// 시안 라벨 글자 상자 높이. 16pt 라벨은 h19다(회원가입 4534:1700·1695 등.
/// 캐릭터 정보 수정은 같은 값을 화면에서 직접 쓴다).
const double _labelLineHeight = 19;

/// 라벨 자리 높이. 예전에는 라벨을 Flutter 기본 줄 높이(Paperlogy 16 → 23)로
/// 그렸고, 화면마다 labelGap을 이 높이에 맞춰 잡아 두었다(23 + 1 = 칸 top
/// 24). 글자 상자만 시안 19로 줄이고 남는 4는 아래에 비워 칸 자리를 지킨다.
const double _labelSlotHeight = 23;

class RoundedInputField extends StatefulWidget {
  const RoundedInputField({
    super.key,
    this.label,
    this.controller,
    this.hintText,
    this.suffix,
    this.onTap,
    this.onChanged,
    this.onSubmitted,
    this.textInputAction,
    this.readOnly = false,
    this.enabled = true,
    this.obscureText = false,
    this.centerText = false,
    this.errorText,
    this.hasError = false,
    this.height = AppLayout.controlHeight,
    this.labelGap = 8,
    this.centerVertically = false,
    this.labelColor = kOrangeMain,
    this.suffixIconConstraints,
    this.errorTrailing,
    this.contentPadding,
    this.overlaySuffix = false,
    this.hintStyle = kCaptionStyle,
    this.textStyle,
    this.obscuredTextStyle = kCaptionStyle,
    this.obscuringCharacter = '●',
    this.eyeVariant = FigmaEyeVariant.auth,
    this.showShadow = true,
    this.alwaysShowEye = false,
    this.labelIndent = AppLayout.inputLabelIndent,
    this.hintLift = 2,
    this.keyboardType,
    this.inputFormatters,
  });

  final String? label;
  final TextEditingController? controller;
  final String? hintText;
  final Widget? suffix;
  final VoidCallback? onTap;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextInputAction? textInputAction;
  final bool readOnly;
  final bool enabled;
  final bool obscureText;

  /// 로그인 화면은 입력 내용을 가운데로 정렬한다.
  final bool centerText;
  final String? errorText;
  final bool hasError;
  final double height;
  final double labelGap;
  final bool centerVertically;
  final Color labelColor;
  final BoxConstraints? suffixIconConstraints;
  final Widget? errorTrailing;

  final EdgeInsetsGeometry? contentPadding;
  final bool overlaySuffix;
  final TextStyle hintStyle;
  final TextStyle? textStyle;

  /// 가려진 동안의 글자 스타일. 시안의 가림 문자는 평문과 달리 연한 회색
  /// ●다 — 회원가입(4534:2075)·비밀번호 변경(4534:2783)·기기 PIN(5728:5760)은
  /// 12 Regular, 로그인(4534:1342)만 14 SemiBold라 호출부가 넘긴다.
  final TextStyle obscuredTextStyle;
  final String obscuringCharacter;

  /// 눈 아이콘 에셋과 자리. 기기연결 화면만 다른 시안 그룹을 쓴다.
  final FigmaEyeVariant eyeVariant;
  final bool showShadow;

  /// 회원가입(2395:40)은 값이 있을 때만 눈을 보여주지만, 로그인(2395:31)은
  /// 빈 칸에도 띄운다. 화면마다 다르니 호출부가 정한다.
  final bool alwaysShowEye;

  /// 시안은 모든 화면에서 라벨을 입력칸(x34)보다 11px 들여쓴다(x45).
  /// 회원가입(2307:891)·재설정(2307:1502)·등록·마이페이지 전부 같다.
  final double labelIndent;

  /// 힌트 글자를 위로 올리는 양. Material 입력칸은 힌트를 입력 글자(14pt)와
  /// 같은 baseline에 앉혀서, 12pt 힌트는 시안보다 2px 아래로 내려간다(회원가입
  /// 4534:1673·내 정보 수정 4534:2909·키우는 장소 4534:85·캐릭터 정보 수정
  /// 4534:20068 모두 1.9~2.0). 입력 글자는 시안과 맞으므로 힌트만 그린 자리에서
  /// 올린다. 세로 contentPadding으로 글자 자리를 직접 잡은 로그인은 0을 넘긴다.
  final double hintLift;

  /// 센서 PIN처럼 숫자만 받는 칸에서 넘긴다.
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;

  @override
  State<RoundedInputField> createState() => _RoundedInputFieldState();
}

class _RoundedInputFieldState extends State<RoundedInputField> {
  late bool _obscured = widget.obscureText;

  @override
  void initState() {
    super.initState();
    // 값 유무로 눈 아이콘이 나타났다 사라지므로 직접 듣는다. 호출부가
    // 리스너를 달아 두지 않은 화면에서도 동작해야 한다.
    if (widget.obscureText) widget.controller?.addListener(_onTextChanged);
  }

  @override
  void didUpdateWidget(RoundedInputField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.removeListener(_onTextChanged);
      if (widget.obscureText) widget.controller?.addListener(_onTextChanged);
    }
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final align = widget.centerText ? TextAlign.center : TextAlign.start;
    final eye = _buildEye();
    // 눈이 나타났다 사라져도 TextField가 같은 자리에 있어야 포커스가 유지된다.
    // 그래서 눈을 쓸 수 있는 칸은 값 유무와 관계없이 겹쳐 그리는 배치를 쓴다.
    final hasEyeSlot = widget.obscureText && widget.suffix == null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null) ...[
          Padding(
            padding: EdgeInsets.only(left: widget.labelIndent),
            child: Text(
              widget.label!,
              // 기본 23 상자로 그리면 글자가 시안보다 1.75px 아래였다. 줄
              // 높이를 시안 상자(19)에 맞추면 2px 올라가 0.3px 안으로 맞는다.
              style: kItemStyle.copyWith(
                color: widget.labelColor,
                height: _labelLineHeight / 16,
              ),
            ),
          ),
          SizedBox(
            height: _labelSlotHeight - _labelLineHeight + widget.labelGap,
          ),
        ],
        _OverflowRow(
          errorText: widget.errorText,
          errorTrailing: widget.errorTrailing,
          // 글자를 세로 중앙에 두느라 TextField가 칸보다 작아졌다. readOnly로
          // 탭만 받는 칸은 여백을 눌러도 반응해야 한다.
          child: GestureDetector(
            onTap: widget.readOnly ? widget.onTap : null,
            behavior: HitTestBehavior.opaque,
            child: Container(
              height: widget.height,
              decoration: BoxDecoration(
                color: kBackgroundWhite,
                borderRadius: BorderRadius.circular(kButtonRadius),
                border: widget.errorText == null && !widget.hasError
                    ? null
                    : Border.all(color: kErrorRed),
                boxShadow: widget.showShadow
                    ? const [BoxShadow(color: Color(0x2E000000), blurRadius: 2)]
                    : null,
              ),
              // 눈 아이콘은 시안이 칸 오른쪽 끝에서 잰 자리에 얹으므로 항상
              // 겹쳐 그린다. suffixIcon으로 넣으면 입력 여백·버튼 크기에 따라
              // 화면마다 자리가 달라진다.
              child: widget.overlaySuffix || hasEyeSlot
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        Center(
                          child: _buildTextField(
                            align,
                            includeSuffix: false,
                            reserveEye: hasEyeSlot,
                          ),
                        ),
                        if (widget.overlaySuffix && widget.suffix != null)
                          Align(
                            alignment: Alignment.centerRight,
                            child: Padding(
                              padding: const EdgeInsets.only(right: 10),
                              child: widget.suffix,
                            ),
                          ),
                        ?eye,
                      ],
                    )
                  : Align(
                      alignment: Alignment.center,
                      heightFactor: 1,
                      child: _buildTextField(align, includeSuffix: true),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField(
    TextAlign align, {
    required bool includeSuffix,
    bool reserveEye = false,
  }) {
    final hasText = widget.controller?.text.isNotEmpty ?? false;
    // 가림 문자는 값이 있을 때만 보이므로, 빈 칸에서는 평문 스타일을 둔다.
    // 그래야 힌트가 놓이는 줄 높이가 지금과 같다.
    final style = _obscured && hasText
        ? widget.obscuredTextStyle
        : widget.textStyle ?? kBodyStyle.copyWith(fontSize: 14);
    final padding =
        widget.contentPadding ?? const EdgeInsets.symmetric(horizontal: 20);
    return TextField(
      controller: widget.controller,
      readOnly: widget.readOnly,
      enabled: widget.enabled,
      obscureText: _obscured,
      obscuringCharacter: widget.obscuringCharacter,
      onTap: widget.onTap,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      textInputAction: widget.textInputAction,
      keyboardType: widget.keyboardType,
      inputFormatters: widget.inputFormatters,
      textAlign: align,
      // 입력칸은 높이가 고정이라 글자는 항상 세로 중앙에 온다.
      textAlignVertical: TextAlignVertical.center,
      style: _withDesignSpacing(style),
      decoration: InputDecoration(
        // isDense로 InputDecoration의 기본 최소 높이를 걷어낸다. 이게 없으면
        // 바깥에서 아무리 정렬해도 글자가 아래로 붙는다.
        isDense: true,
        // hintText 대신 hint 위젯을 넘겨야 그린 자리만 옮길 수 있다. 입력칸은
        // 힌트를 baseline으로 배치하므로 Transform은 배치(입력 글자 자리)를
        // 건드리지 않는다. Text가 그대로 트리에 있어 읽어 주기도 같다.
        hint: widget.hintText == null
            ? null
            : Transform.translate(
                offset: Offset(0, -widget.hintLift),
                child: Text(
                  widget.hintText!,
                  // hintText로 그릴 때처럼 bodyLarge 위에 얹는다. 줄 높이 등
                  // 나머지 값이 달라지면 힌트 상자 크기가 바뀌어, 칸이 낮은
                  // 로그인에서 입력 글자까지 1px 밀린다.
                  style: Theme.of(context).textTheme.bodyLarge!.merge(
                    _withDesignSpacing(widget.hintStyle),
                  ),
                  textAlign: align,
                ),
              ),
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        disabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        // 세로 여백은 textAlignVertical이 잡으므로 좌우만 준다. 왼쪽 정렬
        // 칸은 긴 값이 눈 아이콘 밑으로 들어가지 않게 그 자리를 비운다.
        contentPadding: reserveEye && !widget.centerText
            ? padding.resolve(TextDirection.ltr).copyWith(right: _eyeReserve)
            : padding,
        suffixIcon: includeSuffix ? _buildSuffix() : null,
        suffixIconConstraints: includeSuffix
            ? widget.suffixIconConstraints
            : null,
      ),
    );
  }

  Widget? _buildSuffix() => widget.suffix;

  /// 눈 아이콘이 차지하는 오른쪽 폭(칸 끝 ~ 아이콘 왼쪽 끝) + 글자와의 틈 8.
  double get _eyeReserve =>
      widget.eyeVariant.rightInset + widget.eyeVariant.closedSize.width + 8;

  Widget? _buildEye() {
    if (widget.suffix != null || !widget.obscureText) return null;
    // 시안(2395:40)은 값이 있을 때만 눈을 보여준다. 가릴 게 없으면 숨긴다.
    // 로그인(2395:31)만 빈 칸에도 띄운다.
    if (!widget.alwaysShowEye && (widget.controller?.text.isEmpty ?? true)) {
      return null;
    }
    // 아이콘 상자 오른쪽 끝을 시안 자리(eyeVariant.rightInset)에 두고,
    // 터치 영역만 좌우로 넓혀 가로 48을 확보한다.
    final variant = widget.eyeVariant;
    final hitPad = (_eyeHitWidth - variant.closedSize.width) / 2;
    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: EdgeInsets.only(right: variant.rightInset - hitPad),
        child: Semantics(
          button: true,
          label: _obscured ? '비밀번호 보기' : '비밀번호 숨기기',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _obscured = !_obscured),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: hitPad, vertical: 8),
              child: FigmaEyeIcon(obscured: _obscured, variant: variant),
            ),
          ),
        ),
      ),
    );
  }
}

/// 눈 아이콘 터치 영역의 가로 폭.
const double _eyeHitWidth = 48;

/// Material 3 입력칸은 글자·힌트에 bodyLarge의 자간 0.5를 덧씌운다. 시안
/// 텍스트 스타일은 자간 0이 기본이므로, 호출부가 자간을 정하지 않았으면
/// 0으로 못박는다(정한 경우 — 로그인 보정 자간 등 — 는 그대로 둔다).
TextStyle _withDesignSpacing(TextStyle style) =>
    style.letterSpacing == null ? style.copyWith(letterSpacing: 0) : style;

/// 입력칸 아래 오류 문구를 흐름 밖으로 흘려보내는 래퍼.
///
/// 시안(2395:46)은 오류가 떠도 다음 필드가 밀리지 않는다. 문구를 Column의
/// 형제로 두면 높이를 차지하므로, 겹쳐 그리고 clip은 끈다.
class _OverflowRow extends StatelessWidget {
  const _OverflowRow({
    required this.child,
    required this.errorText,
    required this.errorTrailing,
  });

  final Widget child;
  final String? errorText;
  final Widget? errorTrailing;

  @override
  Widget build(BuildContext context) {
    if (errorText == null) return child;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          left: 11,
          right: 11,
          // 입력칸 바닥에서 6px 아래.
          bottom: -_errorRowHeight,
          child: Row(
            children: [
              Text(
                errorText!,
                style: kCaptionStyle.copyWith(color: kErrorRed, height: 1),
              ),
              if (errorTrailing != null) ...[const Spacer(), errorTrailing!],
            ],
          ),
        ),
      ],
    );
  }
}
