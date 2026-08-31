import 'package:flutter/material.dart';
import 'package:yeso_plant/theme/app_colors.dart';
import 'package:yeso_plant/theme/app_layout.dart';
import 'package:yeso_plant/theme/app_text_styles.dart';
import 'package:yeso_plant/widgets/figma_glyphs.dart';

// 온보딩 공통 입력칸(Figma nodes 2315:2440, 2315:2457, 2315:2477).
// 테두리 대신 그림자를 쓰고 모서리를 완전히 굴린다. 라벨은 오렌지이고,
// 로그인 화면처럼 라벨이 없는 자리에서는 label을 비워 둔다.
/// 오류 문구 한 줄이 차지하는 높이(top 6 + 12px 글자).
const double _errorRowHeight = 18;

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
    this.labelColor = kBrightOrange,
    this.suffixIconConstraints,
    this.errorTrailing,
    this.reserveErrorSpace = false,
    this.contentPadding,
    this.overlaySuffix = false,
    this.hintStyle = kCaptionStyle,
    this.textStyle,
    this.obscuringCharacter = '•',
    this.showShadow = true,
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

  /// 오류 문구가 없을 때도 그 높이를 비워 둘지. 여러 입력칸이 세로로 놓여
  /// 오류 때문에 아래가 밀리면 안 되는 화면에서 켠다.
  final bool reserveErrorSpace;
  final EdgeInsetsGeometry? contentPadding;
  final bool overlaySuffix;
  final TextStyle hintStyle;
  final TextStyle? textStyle;
  final String obscuringCharacter;
  final bool showShadow;

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null) ...[
          Text(
            widget.label!,
            style: kItemStyle.copyWith(color: widget.labelColor),
          ),
          SizedBox(height: widget.labelGap),
        ],
        Container(
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
          child: widget.overlaySuffix
              ? Stack(
                  fit: StackFit.expand,
                  children: [
                    _buildTextField(align, includeSuffix: false),
                    if (_buildSuffix() case final suffix?)
                      // 눈 아이콘은 IconButton이 48px로 퍼지므로 15를 주면
                      // Figma의 우측 21px(2353:1008)과 맞는다. 직접 넘긴
                      // suffix는 그 보정이 없어 여백을 따로 잡는다.
                      Align(
                        alignment: Alignment.centerRight,
                        child: Padding(
                          padding: EdgeInsets.only(
                            right: widget.suffix == null ? 15 : 10,
                          ),
                          child: suffix,
                        ),
                      ),
                  ],
                )
              : _buildTextField(align, includeSuffix: true),
        ),
        // 시안(2395:46)은 오류가 떠도 아래 필드가 밀리지 않는다. 문구 자리를
        // 항상 비워 두고 내용만 채운다.
        if (widget.reserveErrorSpace || widget.errorText != null)
          SizedBox(
            height: _errorRowHeight,
            child: widget.errorText == null
                ? null
                : Padding(
                    padding: const EdgeInsets.only(top: 6, left: 11, right: 11),
                    child: Row(
                      children: [
                        Text(
                          widget.errorText!,
                          style: kCaptionStyle.copyWith(
                            color: kErrorRed,
                            height: 1,
                          ),
                        ),
                        if (widget.errorTrailing != null) ...[
                          const Spacer(),
                          widget.errorTrailing!,
                        ],
                      ],
                    ),
                  ),
          ),
      ],
    );
  }

  Widget _buildTextField(TextAlign align, {required bool includeSuffix}) {
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
      textAlign: align,
      textAlignVertical: widget.centerVertically
          ? TextAlignVertical.center
          : null,
      style: widget.textStyle ?? kBodyStyle.copyWith(fontSize: 14),
      decoration: InputDecoration(
        isDense: widget.centerVertically,
        hintText: widget.hintText,
        hintStyle: widget.hintStyle,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        disabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        contentPadding:
            widget.contentPadding ??
            (widget.centerVertically
                ? const EdgeInsets.symmetric(horizontal: 20)
                : const EdgeInsets.symmetric(horizontal: 20, vertical: 16)),
        suffixIcon: includeSuffix ? _buildSuffix() : null,
        suffixIconConstraints: includeSuffix
            ? widget.suffixIconConstraints
            : null,
      ),
    );
  }

  Widget? _buildSuffix() {
    if (widget.suffix != null) return widget.suffix;
    if (!widget.obscureText) return null;
    // 시안(2395:40)은 값이 있을 때만 눈을 보여준다. 가릴 게 없으면 숨긴다.
    if (widget.controller?.text.isEmpty ?? true) return null;
    // 여백은 바깥 Padding(overlaySuffix)이 잡으므로 버튼은 아이콘 크기만
    // 차지하게 두고, 터치 영역은 가로 48px만 확보한다. minHeight를 키우면
    // 같은 자리를 쓰는 03:21 카운트다운의 세로 중심이 밀린다.
    return IconButton(
      icon: FigmaEyeIcon(obscured: _obscured),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 48),
      onPressed: () => setState(() => _obscured = !_obscured),
    );
  }
}
