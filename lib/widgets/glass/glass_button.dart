/// Glassmorphism Button Widgets
///
/// Frosted glass buttons with various styles: filled, outlined, tonal, text, icon.
library;

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import 'glass_container.dart';

/// A glass-filled button — primary action with accent background.
class GlassFilledButton extends StatelessWidget {
  const GlassFilledButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.disabled = false,
    this.loading = false,
    this.icon,
    this.iconAlignment = IconAlignment.end,
    this.gap = 8,
    this.padding = const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
    this.borderRadius = CandorRadius.pill,
    this.minSize = const Size(88, 48),
    this.surfaceLevel = GlassSurfaceLevel.level3,
    this.blurStrength = GlassBlurStrength.normal,
    this.border = GlassBorder.none,
    this.elevation = GlassElevation.level2,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final bool disabled;
  final bool loading;
  final Widget? icon;
  final IconAlignment iconAlignment;
  final double gap;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final Size minSize;
  final GlassSurfaceLevel surfaceLevel;
  final GlassBlurStrength blurStrength;
  final GlassBorder border;
  final GlassElevation elevation;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDisabled = disabled || loading || onPressed == null;

    return GlassContainer(
      padding: EdgeInsets.zero,
      surfaceLevel: surfaceLevel,
      blurStrength: blurStrength,
      border: border,
      borderRadius: borderRadius,
      elevation: isDisabled ? GlassElevation.none : elevation,
      onTap: isDisabled ? null : onPressed,
      child: Container(
        constraints: BoxConstraints(minWidth: minSize.width, minHeight: minSize.height),
        padding: padding,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
          color: isDisabled
              ? colors.glassSurface2
              : colors.accent,
        ),
        child: Center(
          child: loading
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(colors.onAccent),
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (icon != null && iconAlignment == IconAlignment.start) ...[
                      icon!,
                      SizedBox(width: gap),
                    ],
                    DefaultTextStyle.merge(
                      style: TextStyle(
                        color: isDisabled ? colors.textDisabled : colors.onAccent,
                        fontWeight: FontWeight.w600,
                      ),
                      child: child,
                    ),
                    if (icon != null && iconAlignment == IconAlignment.end) ...[
                      SizedBox(width: gap),
                      icon!,
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}

/// A glass-outlined button — secondary action with glass border.
class GlassOutlinedButton extends StatelessWidget {
  const GlassOutlinedButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.disabled = false,
    this.loading = false,
    this.icon,
    this.iconAlignment = IconAlignment.end,
    this.gap = 8,
    this.padding = const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
    this.borderRadius = CandorRadius.pill,
    this.minSize = const Size(88, 48),
    this.surfaceLevel = GlassSurfaceLevel.level2,
    this.blurStrength = GlassBlurStrength.normal,
    this.border = GlassBorder.normal,
    this.elevation = GlassElevation.level1,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final bool disabled;
  final bool loading;
  final Widget? icon;
  final IconAlignment iconAlignment;
  final double gap;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final Size minSize;
  final GlassSurfaceLevel surfaceLevel;
  final GlassBlurStrength blurStrength;
  final GlassBorder border;
  final GlassElevation elevation;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDisabled = disabled || loading || onPressed == null;

    return GlassContainer(
      padding: EdgeInsets.zero,
      surfaceLevel: surfaceLevel,
      blurStrength: blurStrength,
      border: border,
      borderRadius: borderRadius,
      elevation: isDisabled ? GlassElevation.none : elevation,
      onTap: isDisabled ? null : onPressed,
      child: Container(
        constraints: BoxConstraints(minWidth: minSize.width, minHeight: minSize.height),
        padding: padding,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
          color: isDisabled ? colors.glassSurface1 : Colors.transparent,
        ),
        child: Center(
          child: loading
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(colors.accent),
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (icon != null && iconAlignment == IconAlignment.start) ...[
                      IconTheme.merge(
                        data: IconThemeData(
                          color: isDisabled ? colors.textDisabled : colors.accent,
                        ),
                        child: icon!,
                      ),
                      SizedBox(width: gap),
                    ],
                    DefaultTextStyle.merge(
                      style: TextStyle(
                        color: isDisabled ? colors.textDisabled : colors.accent,
                        fontWeight: FontWeight.w600,
                      ),
                      child: child,
                    ),
                    if (icon != null && iconAlignment == IconAlignment.end) ...[
                      SizedBox(width: gap),
                      IconTheme.merge(
                        data: IconThemeData(
                          color: isDisabled ? colors.textDisabled : colors.accent,
                        ),
                        child: icon!,
                      ),
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}

/// A glass-tonal button — tertiary action with subtle glass background.
class GlassTonalButton extends StatelessWidget {
  const GlassTonalButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.disabled = false,
    this.loading = false,
    this.icon,
    this.iconAlignment = IconAlignment.end,
    this.gap = 8,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    this.borderRadius = CandorRadius.pill,
    this.minSize = const Size(72, 40),
    this.surfaceLevel = GlassSurfaceLevel.level2,
    this.blurStrength = GlassBlurStrength.normal,
    this.border = GlassBorder.subtle,
    this.elevation = GlassElevation.level1,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final bool disabled;
  final bool loading;
  final Widget? icon;
  final IconAlignment iconAlignment;
  final double gap;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final Size minSize;
  final GlassSurfaceLevel surfaceLevel;
  final GlassBlurStrength blurStrength;
  final GlassBorder border;
  final GlassElevation elevation;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDisabled = disabled || loading || onPressed == null;

    return GlassContainer(
      padding: EdgeInsets.zero,
      surfaceLevel: surfaceLevel,
      blurStrength: blurStrength,
      border: border,
      borderRadius: borderRadius,
      elevation: isDisabled ? GlassElevation.none : elevation,
      onTap: isDisabled ? null : onPressed,
      child: Container(
        constraints: BoxConstraints(minWidth: minSize.width, minHeight: minSize.height),
        padding: padding,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
          color: isDisabled ? colors.glassSurface1 : colors.accentContainer,
        ),
        child: Center(
          child: loading
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(colors.accent),
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (icon != null && iconAlignment == IconAlignment.start) ...[
                      IconTheme.merge(
                        data: IconThemeData(
                          color: isDisabled ? colors.textDisabled : colors.accent,
                        ),
                        child: icon!,
                      ),
                      SizedBox(width: gap),
                    ],
                    DefaultTextStyle.merge(
                      style: TextStyle(
                        color: isDisabled ? colors.textDisabled : colors.accent,
                        fontWeight: FontWeight.w600,
                      ),
                      child: child,
                    ),
                    if (icon != null && iconAlignment == IconAlignment.end) ...[
                      SizedBox(width: gap),
                      IconTheme.merge(
                        data: IconThemeData(
                          color: isDisabled ? colors.textDisabled : colors.accent,
                        ),
                        child: icon!,
                      ),
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}

/// A glass text button — minimal action, no background.
class GlassTextButton extends StatelessWidget {
  const GlassTextButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.disabled = false,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    this.borderRadius = CandorRadius.pill,
    this.surfaceLevel = GlassSurfaceLevel.level1,
    this.blurStrength = GlassBlurStrength.subtle,
    this.border = GlassBorder.none,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final bool disabled;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final GlassSurfaceLevel surfaceLevel;
  final GlassBlurStrength blurStrength;
  final GlassBorder border;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDisabled = disabled || onPressed == null;

    return GlassContainer(
      padding: EdgeInsets.zero,
      surfaceLevel: surfaceLevel,
      blurStrength: blurStrength,
      border: border,
      borderRadius: borderRadius,
      elevation: GlassElevation.none,
      onTap: isDisabled ? null : onPressed,
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
          color: Colors.transparent,
        ),
        child: DefaultTextStyle.merge(
          style: TextStyle(
            color: isDisabled ? colors.textDisabled : colors.accent,
            fontWeight: FontWeight.w600,
          ),
          child: child,
        ),
      ),
    );
  }
}

/// A glass icon button — circular button with icon.
class GlassIconButton extends StatelessWidget {
  const GlassIconButton({
    super.key,
    required this.onPressed,
    required this.icon,
    this.disabled = false,
    this.tooltip,
    this.size = 44,
    this.iconSize = 24,
    this.surfaceLevel = GlassSurfaceLevel.level2,
    this.blurStrength = GlassBlurStrength.normal,
    this.border = GlassBorder.subtle,
    this.elevation = GlassElevation.level1,
  });

  final VoidCallback? onPressed;
  final Widget icon;
  final bool disabled;
  final String? tooltip;
  final double size;
  final double iconSize;
  final GlassSurfaceLevel surfaceLevel;
  final GlassBlurStrength blurStrength;
  final GlassBorder border;
  final GlassElevation elevation;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDisabled = disabled || onPressed == null;

    final button = GlassContainer(
      width: size,
      height: size,
      padding: EdgeInsets.zero,
      surfaceLevel: surfaceLevel,
      blurStrength: blurStrength,
      border: border,
      borderRadius: CandorRadius.pill,
      elevation: isDisabled ? GlassElevation.none : elevation,
      onTap: isDisabled ? null : onPressed,
      child: Center(
        child: IconTheme.merge(
          data: IconThemeData(
            color: isDisabled ? colors.textDisabled : colors.textPrimary,
            size: iconSize,
          ),
          child: icon,
        ),
      ),
    );

    if (tooltip != null) {
      return Tooltip(message: tooltip!, child: button);
    }
    return button;
  }
}

/// A glass-floating action button (FAB).
class GlassFAB extends StatelessWidget {
  const GlassFAB({
    super.key,
    required this.onPressed,
    this.child,
    this.disabled = false,
    this.tooltip,
    this.size = 56,
    this.surfaceLevel = GlassSurfaceLevel.level3,
    this.blurStrength = GlassBlurStrength.strong,
    this.border = GlassBorder.normal,
    this.elevation = GlassElevation.level3,
    this.extended = false,
    this.label,
    this.icon,
  });

  final VoidCallback? onPressed;
  final Widget? child;
  final bool disabled;
  final String? tooltip;
  final double size;
  final GlassSurfaceLevel surfaceLevel;
  final GlassBlurStrength blurStrength;
  final GlassBorder border;
  final GlassElevation elevation;
  final bool extended;
  final String? label;
  final Widget? icon;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDisabled = disabled || onPressed == null;

    Widget content;
    if (extended) {
      content = GlassContainer(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        surfaceLevel: surfaceLevel,
        blurStrength: blurStrength,
        border: border,
        borderRadius: CandorRadius.pill,
        elevation: isDisabled ? GlassElevation.none : elevation,
        onTap: isDisabled ? null : onPressed,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(CandorRadius.pill),
            color: isDisabled ? colors.glassSurface2 : colors.accent,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                IconTheme.merge(
                  data: IconThemeData(
                    color: isDisabled ? colors.textDisabled : colors.onAccent,
                    size: 24,
                  ),
                  child: icon!,
                ),
                const SizedBox(width: 8),
              ],
              Text(
                label ?? '',
                style: TextStyle(
                  color: isDisabled ? colors.textDisabled : colors.onAccent,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      content = GlassContainer(
        width: size,
        height: size,
        padding: EdgeInsets.zero,
        surfaceLevel: surfaceLevel,
        blurStrength: blurStrength,
        border: border,
        borderRadius: CandorRadius.pill,
        elevation: isDisabled ? GlassElevation.none : elevation,
        onTap: isDisabled ? null : onPressed,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(CandorRadius.pill),
            color: isDisabled ? colors.glassSurface2 : colors.accent,
          ),
          child: Center(
            child: IconTheme.merge(
              data: IconThemeData(
                color: isDisabled ? colors.textDisabled : colors.onAccent,
                size: 28,
              ),
              child: child ?? icon ?? const Icon(Icons.add),
            ),
          ),
        ),
      );
    }

    if (tooltip != null) {
      return Tooltip(message: tooltip!, child: content);
    }
    return content;
  }
}

/// A glass segmented button group — for theme mode, filter tabs, etc.
class GlassSegmentedButton<T> extends StatelessWidget {
  const GlassSegmentedButton({
    super.key,
    required this.segments,
    required this.selected,
    required this.onSelectionChanged,
    this.emptySelectionAllowed = false,
    this.padding = const EdgeInsets.all(4),
    this.surfaceLevel = GlassSurfaceLevel.level1,
    this.blurStrength = GlassBlurStrength.subtle,
    this.border = GlassBorder.none,
  });

  final List<ButtonSegment<T>> segments;
  final Set<T> selected;
  final ValueChanged<Set<T>> onSelectionChanged;
  final bool emptySelectionAllowed;
  final EdgeInsetsGeometry padding;
  final GlassSurfaceLevel surfaceLevel;
  final GlassBlurStrength blurStrength;
  final GlassBorder border;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      padding: padding,
      surfaceLevel: surfaceLevel,
      blurStrength: blurStrength,
      border: border,
      borderRadius: CandorRadius.pill,
      elevation: GlassElevation.none,
      child: SegmentedButton<T>(
        segments: segments,
        selected: selected,
        onSelectionChanged: onSelectionChanged,
        emptySelectionAllowed: emptySelectionAllowed,
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            final colors = Theme.of(context).colorScheme;
            if (states.contains(WidgetState.selected)) return colors.accentContainer;
            if (states.contains(WidgetState.hovered)) return colors.glassSurface2;
            if (states.contains(WidgetState.pressed)) return colors.glassSurface3;
            return Colors.transparent;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            final colors = Theme.of(context).colorScheme;
            if (states.contains(WidgetState.selected)) return colors.accent;
            return colors.textPrimary;
          }),
          side: WidgetStateProperty.all(BorderSide.none),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(CandorRadius.pill)),
          ),
          padding: WidgetStateProperty.all(const EdgeInsets.symmetric(horizontal: 16, vertical: 10)),
          textStyle: WidgetStateProperty.all(
            Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}

/// A glass toggle button — for on/off states.
class GlassToggleButton extends StatefulWidget {
  const GlassToggleButton({
    super.key,
    required this.value,
    required this.onChanged,
    this.label,
    this.icon,
    this.activeIcon,
    this.disabled = false,
    this.surfaceLevel = GlassSurfaceLevel.level2,
    this.blurStrength = GlassBlurStrength.normal,
    this.border = GlassBorder.subtle,
    this.elevation = GlassElevation.level1,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final String? label;
  final Widget? icon;
  final Widget? activeIcon;
  final bool disabled;
  final GlassSurfaceLevel surfaceLevel;
  final GlassBlurStrength blurStrength;
  final GlassBorder border;
  final GlassElevation elevation;

  @override
  State<GlassToggleButton> createState() => _GlassToggleButtonState();
}

class _GlassToggleButtonState extends State<GlassToggleButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    if (widget.value) _controller.value = 1;
  }

  @override
  void didUpdateWidget(covariant GlassToggleButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value) {
      widget.value ? _controller.forward() : _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDisabled = widget.disabled;

    return GlassContainer(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      surfaceLevel: widget.surfaceLevel,
      blurStrength: widget.blurStrength,
      border: widget.border,
      borderRadius: CandorRadius.pill,
      elevation: isDisabled ? GlassElevation.none : widget.elevation,
      onTap: isDisabled ? null : () => widget.onChanged(!widget.value),
      child: AnimatedBuilder(
        animation: _animation,
        builder: (_, _) {
          return Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(CandorRadius.pill),
              color: Color.lerp(
                colors.glassSurface1,
                colors.accentContainer,
                _animation.value,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.icon != null || widget.activeIcon != null) ...[
                  IconTheme.merge(
                    data: IconThemeData(
                      color: Color.lerp(
                        colors.textTertiary,
                        colors.accent,
                        _animation.value,
                      ),
                      size: 20,
                    ),
                    child: widget.value && widget.activeIcon != null
                        ? widget.activeIcon!
                        : widget.icon ?? const SizedBox.shrink(),
                  ),
                  const SizedBox(width: 8),
                ],
                if (widget.label != null)
                  DefaultTextStyle.merge(
                    style: TextStyle(
                      color: Color.lerp(
                        colors.textSecondary,
                        colors.accent,
                        _animation.value,
                      ),
                      fontWeight: FontWeight.w600,
                    ),
                    child: Text(widget.label!),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// A glass pill button — compact action chip style.
class GlassPillButton extends StatelessWidget {
  const GlassPillButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.icon,
    this.disabled = false,
    this.selected = false,
    this.surfaceLevel = GlassSurfaceLevel.level1,
    this.blurStrength = GlassBlurStrength.subtle,
    this.border = GlassBorder.subtle,
  });

  final VoidCallback? onPressed;
  final String label;
  final Widget? icon;
  final bool disabled;
  final bool selected;
  final GlassSurfaceLevel surfaceLevel;
  final GlassBlurStrength blurStrength;
  final GlassBorder border;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDisabled = disabled || onPressed == null;

    return GlassContainer(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      surfaceLevel: surfaceLevel,
      blurStrength: blurStrength,
      border: selected ? GlassBorder.normal : border,
      borderRadius: CandorRadius.pill,
      elevation: GlassElevation.none,
      onTap: isDisabled ? null : onPressed,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(CandorRadius.pill),
          color: selected
              ? (isDisabled ? colors.glassSurface2 : colors.accentContainer)
              : (isDisabled ? colors.glassSurface1.withValues(alpha: 0.5) : Colors.transparent),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              IconTheme.merge(
                data: IconThemeData(
                  color: selected
                      ? (isDisabled ? colors.textDisabled : colors.accent)
                      : (isDisabled ? colors.textDisabled : colors.textSecondary),
                  size: 16,
                ),
                child: icon!,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                color: selected
                    ? (isDisabled ? colors.textDisabled : colors.accent)
                    : (isDisabled ? colors.textDisabled : colors.textPrimary),
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}