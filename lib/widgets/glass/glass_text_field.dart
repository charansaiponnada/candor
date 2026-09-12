/// Glassmorphism Text Fields & Input Widgets
///
/// Frosted glass input fields with consistent styling across the app.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';

import '../../theme/app_theme.dart';
import 'glass_container.dart';

/// A glass-styled text field with integrated label, hint, and error states.
///
/// Wraps a [TextField] inside a [GlassContainer] for the frosted glass effect.
/// Supports all standard [TextField] properties plus glass-specific customization.
class GlassTextField extends StatefulWidget {
  const GlassTextField({
    super.key,
    this.controller,
    this.focusNode,
    this.decoration,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.style,
    this.strutStyle,
    this.textAlign = TextAlign.start,
    this.textAlignVertical,
    this.textDirection,
    this.readOnly = false,
    this.showCursor,
    this.autofocus = false,
    this.obscureText = false,
    this.autocorrect = true,
    this.smartDashesType,
    this.smartQuotesType,
    this.enableSuggestions = true,
    this.maxLines = 1,
    this.minLines,
    this.expands = false,
    this.maxLength,
    this.maxLengthEnforcement,
    this.onChanged,
    this.onEditingComplete,
    this.onSubmitted,
    this.onAppPrivateCommand,
    this.onTap,
    this.onTapOutside,
    this.inputFormatters,
    this.enabled,
    this.cursorWidth = 2.0,
    this.cursorHeight,
    this.cursorRadius,
    this.cursorColor,
    this.selectionControls,
    this.scrollPadding = const EdgeInsets.all(20.0),
    this.dragStartBehavior = DragStartBehavior.start,
    this.enableInteractiveSelection = true,
    this.autofillHints,
    this.scrollController,
    this.scrollPhysics,
    this.restorationId,
    this.enableIMEPersonalizedLearning = true,
    this.mouseCursor,
    this.buildCounter,
    this.spellCheckConfiguration,
    this.magnifierConfiguration,
    // Glass-specific
    this.surfaceLevel = GlassSurfaceLevel.level2,
    this.blurStrength = GlassBlurStrength.normal,
    this.border = GlassBorder.subtle,
    this.filled = true,
    this.contentPadding = const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    this.prefixIcon,
    this.suffixIcon,
    this.prefix,
    this.suffix,
    this.counterText,
    this.errorText,
    this.helperText,
    this.hintText,
    this.labelText,
    this.floatingLabelBehavior,
    this.isDense = false,
    this.alignLabelWithHint = false,
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final InputDecoration? decoration;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final TextStyle? style;
  final StrutStyle? strutStyle;
  final TextAlign textAlign;
  final TextAlignVertical? textAlignVertical;
  final TextDirection? textDirection;
  final bool readOnly;
  final bool? showCursor;
  final bool autofocus;
  final bool obscureText;
  final bool autocorrect;
  final SmartDashesType? smartDashesType;
  final SmartQuotesType? smartQuotesType;
  final bool enableSuggestions;
  final int maxLines;
  final int? minLines;
  final bool expands;
  final int? maxLength;
  final MaxLengthEnforcement? maxLengthEnforcement;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onEditingComplete;
  final ValueChanged<String>? onSubmitted;
  final AppPrivateCommandCallback? onAppPrivateCommand;
  final VoidCallback? onTap;
  final TapRegionCallback? onTapOutside;
  final List<TextInputFormatter>? inputFormatters;
  final bool? enabled;
  final double cursorWidth;
  final double? cursorHeight;
  final Radius? cursorRadius;
  final Color? cursorColor;
  final TextSelectionControls? selectionControls;
  final EdgeInsets scrollPadding;
  final DragStartBehavior dragStartBehavior;
  final bool enableInteractiveSelection;
  final Iterable<String>? autofillHints;
  final ScrollController? scrollController;
  final ScrollPhysics? scrollPhysics;
  final String? restorationId;
  final bool enableIMEPersonalizedLearning;
  final MouseCursor? mouseCursor;
  final InputCounterWidgetBuilder? buildCounter;
  final SpellCheckConfiguration? spellCheckConfiguration;
  final TextMagnifierConfiguration? magnifierConfiguration;

  // Glass-specific
  final GlassSurfaceLevel surfaceLevel;
  final GlassBlurStrength blurStrength;
  final GlassBorder border;
  final bool filled;
  final EdgeInsetsGeometry contentPadding;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final Widget? prefix;
  final Widget? suffix;
  final String? counterText;
  final String? errorText;
  final String? helperText;
  final String? hintText;
  final String? labelText;
  final FloatingLabelBehavior? floatingLabelBehavior;
  final bool isDense;
  final bool alignLabelWithHint;

  @override
  State<GlassTextField> createState() => _GlassTextFieldState();
}

class _GlassTextFieldState extends State<GlassTextField> {
  late FocusNode _focusNode;
  bool _hasFocus = false;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    if (widget.focusNode == null) _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (mounted) setState(() => _hasFocus = _focusNode.hasFocus);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isEnabled = widget.enabled ?? true;
    final hasError = widget.errorText != null && widget.errorText!.isNotEmpty;

    // Determine border color based on state
    Color effectiveBorderColor;
    double effectiveBorderWidth = 1;

    if (!isEnabled) {
      effectiveBorderColor = colors.glassBorder1;
    } else if (hasError) {
      effectiveBorderColor = colors.error;
      effectiveBorderWidth = 2;
    } else if (_hasFocus) {
      effectiveBorderColor = colors.accent;
      effectiveBorderWidth = 2;
    } else {
      effectiveBorderColor = switch (widget.border) {
        GlassBorder.none => Colors.transparent,
        GlassBorder.subtle => colors.glassBorder1,
        GlassBorder.normal => colors.glassBorder2,
        GlassBorder.strong => colors.glassBorder3,
      };
    }

    // Determine border color

    return GlassContainer(
      padding: EdgeInsets.zero,
      surfaceLevel: widget.surfaceLevel,
      blurStrength: widget.blurStrength,
      border: GlassBorder.none, // We handle border manually
      borderRadius: CandorRadius.md,
      elevation: _hasFocus ? GlassElevation.level2 : GlassElevation.level1,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(CandorRadius.md),
          border: Border.all(color: effectiveBorderColor, width: effectiveBorderWidth),
        ),
        child: TextField(
          controller: widget.controller,
          focusNode: _focusNode,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          textCapitalization: widget.textCapitalization,
          style: widget.style ??
              Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: isEnabled ? colors.textPrimary : colors.textDisabled,
                  ),
          strutStyle: widget.strutStyle,
          textAlign: widget.textAlign,
          textAlignVertical: widget.textAlignVertical,
          textDirection: widget.textDirection,
          readOnly: widget.readOnly,
          showCursor: widget.showCursor,
          autofocus: widget.autofocus,
          obscureText: widget.obscureText,
          autocorrect: widget.autocorrect,
          smartDashesType: widget.smartDashesType,
          smartQuotesType: widget.smartQuotesType,
          enableSuggestions: widget.enableSuggestions,
          maxLines: widget.maxLines,
          minLines: widget.minLines,
          expands: widget.expands,
          maxLength: widget.maxLength,
          maxLengthEnforcement: widget.maxLengthEnforcement,
          onChanged: widget.onChanged,
          onEditingComplete: widget.onEditingComplete,
          onSubmitted: widget.onSubmitted,
          onAppPrivateCommand: widget.onAppPrivateCommand,
          onTap: widget.onTap,
          onTapOutside: widget.onTapOutside,
          inputFormatters: widget.inputFormatters,
          enabled: isEnabled,
          cursorWidth: widget.cursorWidth,
          cursorHeight: widget.cursorHeight,
          cursorRadius: widget.cursorRadius,
          cursorColor: widget.cursorColor ?? colors.accent,
          selectionControls: widget.selectionControls,
          scrollPadding: widget.scrollPadding,
          dragStartBehavior: widget.dragStartBehavior,
          enableInteractiveSelection: widget.enableInteractiveSelection,
          autofillHints: widget.autofillHints,
          scrollController: widget.scrollController,
          scrollPhysics: widget.scrollPhysics,
          restorationId: widget.restorationId,
          enableIMEPersonalizedLearning: widget.enableIMEPersonalizedLearning,
          mouseCursor: widget.mouseCursor,
          buildCounter: widget.buildCounter,
          spellCheckConfiguration: widget.spellCheckConfiguration,
          magnifierConfiguration: widget.magnifierConfiguration,
          decoration: InputDecoration(
            filled: widget.filled,
            fillColor: Colors.transparent, // GlassContainer handles background
            contentPadding: widget.contentPadding,
            prefixIcon: widget.prefixIcon,
            suffixIcon: widget.suffixIcon,
            prefix: widget.prefix,
            suffix: widget.suffix,
            counterText: widget.counterText,
            errorText: widget.errorText,
            helperText: widget.helperText,
            labelText: widget.labelText,
            floatingLabelBehavior: widget.floatingLabelBehavior,
            isDense: widget.isDense,
            alignLabelWithHint: widget.alignLabelWithHint,
            border: InputBorder.none,
            disabledBorder: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            errorBorder: InputBorder.none,
            focusedErrorBorder: InputBorder.none,
            labelStyle: TextStyle(
              color: _hasFocus ? colors.accent : colors.textTertiary,
            ),
            hintStyle: TextStyle(color: colors.textDisabled),
            helperStyle: TextStyle(color: colors.textTertiary),
            errorStyle: TextStyle(color: colors.error),
            floatingLabelStyle: TextStyle(color: colors.accent),
            counterStyle: TextStyle(color: colors.textTertiary),
          ),
        ),
      ),
    );
  }
}

/// A glass-styled text area (multi-line text field) with auto-resize support.
class GlassTextArea extends StatelessWidget {
  const GlassTextArea({
    super.key,
    this.controller,
    this.focusNode,
    this.hintText,
    this.labelText,
    this.helperText,
    this.errorText,
    this.maxLines = 4,
    this.minLines = 2,
    this.maxLength,
    this.onChanged,
    this.onSubmitted,
    this.enabled = true,
    this.readOnly = false,
    this.textCapitalization = TextCapitalization.sentences,
    this.surfaceLevel = GlassSurfaceLevel.level2,
    this.blurStrength = GlassBlurStrength.normal,
    this.border = GlassBorder.subtle,
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? hintText;
  final String? labelText;
  final String? helperText;
  final String? errorText;
  final int maxLines;
  final int minLines;
  final int? maxLength;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool enabled;
  final bool readOnly;
  final TextCapitalization textCapitalization;
  final GlassSurfaceLevel surfaceLevel;
  final GlassBlurStrength blurStrength;
  final GlassBorder border;

  @override
  Widget build(BuildContext context) {
    return GlassTextField(
      controller: controller,
      focusNode: focusNode,
      hintText: hintText,
      labelText: labelText,
      helperText: helperText,
      errorText: errorText,
      maxLines: maxLines,
      minLines: minLines,
      maxLength: maxLength,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      enabled: enabled,
      readOnly: readOnly,
      textCapitalization: textCapitalization,
      surfaceLevel: surfaceLevel,
      blurStrength: blurStrength,
      border: border,
      contentPadding: const EdgeInsets.all(16),
    );
  }
}

/// A glass search field — optimized for search input with clear button.
class GlassSearchField extends StatefulWidget {
  const GlassSearchField({
    super.key,
    this.controller,
    this.focusNode,
    this.hintText = 'Search…',
    this.onChanged,
    this.onSubmitted,
    this.onClear,
    this.onTap,
    this.enabled = true,
    this.surfaceLevel = GlassSurfaceLevel.level2,
    this.blurStrength = GlassBlurStrength.normal,
    this.border = GlassBorder.subtle,
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onClear;
  final VoidCallback? onTap;
  final bool enabled;
  final GlassSurfaceLevel surfaceLevel;
  final GlassBlurStrength blurStrength;
  final GlassBorder border;

  @override
  State<GlassSearchField> createState() => _GlassSearchFieldState();
}

class _GlassSearchFieldState extends State<GlassSearchField> {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  bool _hasFocus = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    if (widget.focusNode == null) _focusNode.dispose();
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (mounted) setState(() => _hasFocus = _focusNode.hasFocus);
  }

  void _clear() {
    _controller.clear();
    widget.onClear?.call();
    widget.onChanged?.call('');
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final showClear = _controller.text.isNotEmpty && _hasFocus && widget.enabled;

    return GlassContainer(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      surfaceLevel: widget.surfaceLevel,
      blurStrength: widget.blurStrength,
      border: widget.border,
      borderRadius: CandorRadius.pill,
      elevation: _hasFocus ? GlassElevation.level2 : GlassElevation.level1,
      child: Row(
        children: [
          Icon(Icons.search_rounded, color: colors.textTertiary, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              enabled: widget.enabled,
              onChanged: widget.onChanged,
              onSubmitted: widget.onSubmitted,
              onTap: widget.onTap,
              style: TextStyle(color: colors.textPrimary, fontSize: 16),
              decoration: InputDecoration(
                hintText: widget.hintText,
                hintStyle: TextStyle(color: colors.textDisabled, fontSize: 16),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          if (showClear)
            IconButton(
              icon: Icon(Icons.close_rounded, color: colors.textTertiary, size: 20),
              onPressed: _clear,
              tooltip: 'Clear',
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              padding: EdgeInsets.zero,
            ),
        ],
      ),
    );
  }
}