/// Reusable Glassmorphism Container Widgets
///
/// Frosted glass surfaces with configurable blur, opacity, and elevation.
/// All widgets use [BackdropFilter] for the iOS-style blur effect.
library;

import 'dart:ui';

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// A frosted glass container with configurable blur, tint, border, and elevation.
///
/// The glass effect is created using [BackdropFilter] with [ImageFilter.blur].
/// Content is clipped to the border radius.
class GlassContainer extends StatelessWidget {
  /// Creates a glass container.
  const GlassContainer({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.borderRadius = CandorRadius.lg,
    this.surfaceLevel = GlassSurfaceLevel.level2,
    this.blurStrength = GlassBlurStrength.normal,
    this.border = GlassBorder.subtle,
    this.elevation = GlassElevation.level1,
    this.onTap,
    this.onLongPress,
    this.clipBehavior = Clip.antiAlias,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final double borderRadius;
  final GlassSurfaceLevel surfaceLevel;
  final GlassBlurStrength blurStrength;
  final GlassBorder border;
  final GlassElevation elevation;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Clip clipBehavior;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final borderRadiusObj = BorderRadius.circular(borderRadius);

    final decoratedChild = Container(
      width: width,
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: borderRadiusObj,
        color: _surfaceColor(colors),
        border: Border.all(color: _borderColor(colors), width: 1),
        boxShadow: _elevationShadows(),
      ),
      child: child,
    );

    final blurred = ClipRRect(
      borderRadius: borderRadiusObj,
      clipBehavior: clipBehavior,
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: _blurSigma(),
          sigmaY: _blurSigma(),
        ),
        child: decoratedChild,
      ),
    );

    if (onTap != null || onLongPress != null) {
      return Padding(
        padding: margin ?? EdgeInsets.zero,
        child: Material(
          color: Colors.transparent,
          borderRadius: borderRadiusObj,
          child: InkWell(
            onTap: onTap,
            onLongPress: onLongPress,
            borderRadius: borderRadiusObj,
            child: blurred,
          ),
        ),
      );
    }

    return Padding(padding: margin ?? EdgeInsets.zero, child: blurred);
  }

  Color _surfaceColor(ColorScheme colors) {
    return switch (surfaceLevel) {
      GlassSurfaceLevel.level1 => colors.glassSurface1,
      GlassSurfaceLevel.level2 => colors.glassSurface2,
      GlassSurfaceLevel.level3 => colors.glassSurface3,
      GlassSurfaceLevel.level4 => colors.glassSurface4,
    };
  }

  Color _borderColor(ColorScheme colors) {
    return switch (border) {
      GlassBorder.none => Colors.transparent,
      GlassBorder.subtle => colors.glassBorder1,
      GlassBorder.normal => colors.glassBorder2,
      GlassBorder.strong => colors.glassBorder3,
    };
  }

  List<BoxShadow> _elevationShadows() {
    return switch (elevation) {
      GlassElevation.none => [],
      GlassElevation.level1 => CandorElevation.level1,
      GlassElevation.level2 => CandorElevation.level2,
      GlassElevation.level3 => CandorElevation.level3,
      GlassElevation.level4 => CandorElevation.level4,
    };
  }

  double _blurSigma() {
    return switch (blurStrength) {
      GlassBlurStrength.subtle => CandorBlur.subtle,
      GlassBlurStrength.normal => CandorBlur.normal,
      GlassBlurStrength.strong => CandorBlur.strong,
      GlassBlurStrength.intense => CandorBlur.intense,
    };
  }
}

/// Predefined glass surface opacity levels.
enum GlassSurfaceLevel {
  level1, // 5%  — subtle backgrounds
  level2, // 8%  — cards, sheets (default)
  level3, // 12% — elevated surfaces
  level4, // 18% — pressed/focused states
}

/// Predefined blur strengths.
enum GlassBlurStrength {
  subtle, // 10px
  normal, // 20px (default)
  strong, // 30px
  intense, // 40px
}

/// Predefined border visibility.
enum GlassBorder {
  none,    // No border
  subtle,  // 8% white (default)
  normal,  // 12% white
  strong,  // 20% white
}

/// Predefined elevation shadow levels.
enum GlassElevation {
  none,
  level1, // Subtle
  level2, // Card (default)
  level3, // Elevated sheet
  level4, // Modal/dialog
}

/// A glass container that fills available space — useful for full-screen backgrounds.
class GlassBackground extends StatelessWidget {
  const GlassBackground({
    super.key,
    required this.child,
    this.surfaceLevel = GlassSurfaceLevel.level1,
    this.blurStrength = GlassBlurStrength.subtle,
  });

  final Widget child;
  final GlassSurfaceLevel surfaceLevel;
  final GlassBlurStrength blurStrength;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Stack(
      children: [
        // Base black background
        Container(color: CandorColors.black),
        // Glass overlay
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: switch (blurStrength) {
                GlassBlurStrength.subtle => CandorBlur.subtle,
                GlassBlurStrength.normal => CandorBlur.normal,
                GlassBlurStrength.strong => CandorBlur.strong,
                GlassBlurStrength.intense => CandorBlur.intense,
              },
              sigmaY: switch (blurStrength) {
                GlassBlurStrength.subtle => CandorBlur.subtle,
                GlassBlurStrength.normal => CandorBlur.normal,
                GlassBlurStrength.strong => CandorBlur.strong,
                GlassBlurStrength.intense => CandorBlur.intense,
              },
            ),
            child: Container(
              color: switch (surfaceLevel) {
                GlassSurfaceLevel.level1 => colors.glassSurface1,
                GlassSurfaceLevel.level2 => colors.glassSurface2,
                GlassSurfaceLevel.level3 => colors.glassSurface3,
                GlassSurfaceLevel.level4 => colors.glassSurface4,
              },
            ),
          ),
        ),
        // Content
        child,
      ],
    );
  }
}

/// A glass card with standard padding and elevation — the go-to for content cards.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.onTap,
    this.onLongPress,
    this.surfaceLevel = GlassSurfaceLevel.level2,
    this.border = GlassBorder.subtle,
    this.elevation = GlassElevation.level2,
    this.borderRadius = CandorRadius.lg,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final GlassSurfaceLevel surfaceLevel;
  final GlassBorder border;
  final GlassElevation elevation;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      padding: padding,
      margin: margin,
      surfaceLevel: surfaceLevel,
      border: border,
      elevation: elevation,
      borderRadius: borderRadius,
      onTap: onTap,
      onLongPress: onLongPress,
      child: child,
    );
  }
}

/// A glass sheet for bottom sheets, modals, and overlays.
class GlassSheet extends StatelessWidget {
  const GlassSheet({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.margin,
    this.borderRadius = CandorRadius.xl,
    this.surfaceLevel = GlassSurfaceLevel.level3,
    this.blurStrength = GlassBlurStrength.strong,
    this.elevation = GlassElevation.level3,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final GlassSurfaceLevel surfaceLevel;
  final GlassBlurStrength blurStrength;
  final GlassElevation elevation;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      padding: padding,
      margin: margin,
      borderRadius: borderRadius,
      surfaceLevel: surfaceLevel,
      blurStrength: blurStrength,
      elevation: elevation,
      border: GlassBorder.normal,
      child: child,
    );
  }
}

/// A glass pill — rounded capsule shape for chips, badges, small actions.
class GlassPill extends StatelessWidget {
  const GlassPill({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    this.margin,
    this.surfaceLevel = GlassSurfaceLevel.level1,
    this.border = GlassBorder.subtle,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final GlassSurfaceLevel surfaceLevel;
  final GlassBorder border;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      padding: padding,
      margin: margin,
      borderRadius: CandorRadius.pill,
      surfaceLevel: surfaceLevel,
      border: border,
      elevation: GlassElevation.none,
      onTap: onTap,
      child: child,
    );
  }
}

/// A glass circle — for avatars, icon buttons, indicators.
class GlassCircle extends StatelessWidget {
  const GlassCircle({
    super.key,
    required this.child,
    this.size = 40,
    this.surfaceLevel = GlassSurfaceLevel.level2,
    this.border = GlassBorder.subtle,
    this.onTap,
  });

  final Widget child;
  final double size;
  final GlassSurfaceLevel surfaceLevel;
  final GlassBorder border;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      width: size,
      height: size,
      padding: EdgeInsets.zero,
      borderRadius: CandorRadius.pill,
      surfaceLevel: surfaceLevel,
      border: border,
      elevation: GlassElevation.level1,
      onTap: onTap,
      child: Center(child: child),
    );
  }
}

