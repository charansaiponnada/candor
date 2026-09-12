/// Glassmorphism App Bar & Navigation Widgets
///
/// Translucent app bars with blur that work seamlessly with scrolling content.
library;

import 'dart:ui';

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import 'glass_container.dart';

/// A glass app bar that blurs content behind it.
///
/// Designed to be used as a [SliverAppBar] or regular [AppBar] with
/// `backgroundColor: Colors.transparent` and `elevation: 0`.
class GlassAppBar extends StatelessWidget implements PreferredSizeWidget {
  const GlassAppBar({
    super.key,
    this.title,
    this.leading,
    this.actions,
    this.centerTitle = false,
    this.titleSpacing,
    this.bottom,
    this.elevation = 0,
    this.scrolledUnderElevation = 0,
    this.surfaceLevel = GlassSurfaceLevel.level2,
    this.blurStrength = GlassBlurStrength.normal,
    this.border = GlassBorder.subtle,
    this.padding,
    this.height = kToolbarHeight,
    this.flexibleSpace,
  });

  final Widget? title;
  final Widget? leading;
  final List<Widget>? actions;
  final bool centerTitle;
  final double? titleSpacing;
  final PreferredSizeWidget? bottom;
  final double elevation;
  final double scrolledUnderElevation;
  final GlassSurfaceLevel surfaceLevel;
  final GlassBlurStrength blurStrength;
  final GlassBorder border;
  final EdgeInsetsGeometry? padding;
  final double height;
  final Widget? flexibleSpace;

  @override
  Size get preferredSize => Size.fromHeight(height + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final borderRadius = BorderRadius.vertical(
      bottom: Radius.circular(CandorRadius.lg),
    );

    final bar = Container(
      height: height,
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 16),
      child: Stack(
        children: [
          // Glass background with blur
          Positioned.fill(
            child: ClipRRect(
              borderRadius: borderRadius,
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
                  decoration: BoxDecoration(
                    borderRadius: borderRadius,
                    color: switch (surfaceLevel) {
                      GlassSurfaceLevel.level1 => colors.glassSurface1,
                      GlassSurfaceLevel.level2 => colors.glassSurface2,
                      GlassSurfaceLevel.level3 => colors.glassSurface3,
                      GlassSurfaceLevel.level4 => colors.glassSurface4,
                    },
                    border: Border(
                      bottom: BorderSide(
                        color: switch (border) {
                          GlassBorder.none => Colors.transparent,
                          GlassBorder.subtle => colors.glassBorder1,
                          GlassBorder.normal => colors.glassBorder2,
                          GlassBorder.strong => colors.glassBorder3,
                        },
                        width: 1,
                      ),
                    ),
                    boxShadow: CandorElevation.level1,
                  ),
                ),
              ),
            ),
          ),
          // Content
          SafeArea(
            bottom: false,
            child: Row(
              children: [
                if (leading != null) ...[
                  leading!,
                  SizedBox(width: titleSpacing ?? 16),
                ],
                if (title != null)
                  Expanded(
                    child: centerTitle
                        ? Center(child: title!)
                        : Align(alignment: Alignment.centerLeft, child: title!),
                  ),
                if (actions != null) ...[
                  ...actions!.map((a) => Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: a,
                      )),
                ],
              ],
            ),
          ),
          // Optional flexible space (e.g., for tabs)
          if (flexibleSpace != null)
            Positioned.fill(
              top: height - (flexibleSpace is PreferredSizeWidget
                  ? (flexibleSpace as PreferredSizeWidget).preferredSize.height
                  : 0),
              child: flexibleSpace!,
            ),
        ],
      ),
    );

    if (bottom != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: height, child: bar),
          bottom!,
        ],
      );
    }

    return SizedBox(height: height, child: bar);
  }
}

/// A glass sliver app bar for use in [CustomScrollView].
class GlassSliverAppBar extends StatelessWidget {
  const GlassSliverAppBar({
    super.key,
    this.title,
    this.leading,
    this.actions,
    this.centerTitle = false,
    this.titleSpacing,
    this.pinned = true,
    this.floating = false,
    this.snap = false,
    this.expandedHeight,
    this.flexibleSpace,
    this.surfaceLevel = GlassSurfaceLevel.level2,
    this.blurStrength = GlassBlurStrength.normal,
    this.border = GlassBorder.subtle,
    this.elevation = 0,
  });

  final Widget? title;
  final Widget? leading;
  final List<Widget>? actions;
  final bool centerTitle;
  final double? titleSpacing;
  final bool pinned;
  final bool floating;
  final bool snap;
  final double? expandedHeight;
  final Widget? flexibleSpace;
  final GlassSurfaceLevel surfaceLevel;
  final GlassBlurStrength blurStrength;
  final GlassBorder border;
  final double elevation;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final toolbarHeight = kToolbarHeight + MediaQuery.of(context).padding.top;

    return SliverAppBar(
      pinned: pinned,
      floating: floating,
      snap: snap,
      expandedHeight: expandedHeight,
      elevation: elevation,
      scrolledUnderElevation: 0,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      flexibleSpace: flexibleSpace != null
          ? FlexibleSpaceBar(
              background: flexibleSpace,
              stretchModes: const [StretchMode.blurBackground],
            )
          : FlexibleSpaceBar(
              background: _buildGlassBackground(context, colors, toolbarHeight),
              stretchModes: const [StretchMode.blurBackground],
            ),
      leading: leading,
      title: title,
      centerTitle: centerTitle,
      titleSpacing: titleSpacing,
      actions: actions,
    );
  }

  Widget _buildGlassBackground(BuildContext context, ColorScheme colors, double height) {
    return ClipRRect(
      borderRadius: BorderRadius.vertical(bottom: Radius.circular(CandorRadius.lg)),
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
          height: height,
          decoration: BoxDecoration(
            color: switch (surfaceLevel) {
              GlassSurfaceLevel.level1 => colors.glassSurface1,
              GlassSurfaceLevel.level2 => colors.glassSurface2,
              GlassSurfaceLevel.level3 => colors.glassSurface3,
              GlassSurfaceLevel.level4 => colors.glassSurface4,
            },
            border: Border(
              bottom: BorderSide(
                color: switch (border) {
                  GlassBorder.none => Colors.transparent,
                  GlassBorder.subtle => colors.glassBorder1,
                  GlassBorder.normal => colors.glassBorder2,
                  GlassBorder.strong => colors.glassBorder3,
                },
                width: 1,
              ),
            ),
            boxShadow: CandorElevation.level1,
          ),
        ),
      ),
    );
  }
}

/// A glass navigation bar for bottom navigation.
class GlassNavigationBar extends StatelessWidget {
  const GlassNavigationBar({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
    this.surfaceLevel = GlassSurfaceLevel.level2,
    this.blurStrength = GlassBlurStrength.strong,
    this.border = GlassBorder.normal,
    this.elevation = GlassElevation.level2,
    this.height = 80,
    this.padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
  });

  final List<NavigationDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final GlassSurfaceLevel surfaceLevel;
  final GlassBlurStrength blurStrength;
  final GlassBorder border;
  final GlassElevation elevation;
  final double height;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      height: height,
      padding: padding,
      child: ClipRRect(
        borderRadius: BorderRadius.vertical(top: Radius.circular(CandorRadius.xl)),
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
            decoration: BoxDecoration(
              color: switch (surfaceLevel) {
                GlassSurfaceLevel.level1 => colors.glassSurface1,
                GlassSurfaceLevel.level2 => colors.glassSurface2,
                GlassSurfaceLevel.level3 => colors.glassSurface3,
                GlassSurfaceLevel.level4 => colors.glassSurface4,
              },
              border: Border(
                top: BorderSide(
                  color: switch (border) {
                    GlassBorder.none => Colors.transparent,
                    GlassBorder.subtle => colors.glassBorder1,
                    GlassBorder.normal => colors.glassBorder2,
                    GlassBorder.strong => colors.glassBorder3,
                  },
                  width: 1,
                ),
              ),
              boxShadow: switch (elevation) {
                GlassElevation.none => [],
                GlassElevation.level1 => CandorElevation.level1,
                GlassElevation.level2 => CandorElevation.level2,
                GlassElevation.level3 => CandorElevation.level3,
                GlassElevation.level4 => CandorElevation.level4,
              },
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(destinations.length, (index) {
                final dest = destinations[index];
                final isSelected = index == selectedIndex;
                return Expanded(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => onDestinationSelected(index),
                      borderRadius: BorderRadius.circular(CandorRadius.pill),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOutCubic,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(CandorRadius.pill),
                          color: isSelected
                              ? colors.accentContainer
                              : Colors.transparent,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconTheme.merge(
                              data: IconThemeData(
                                size: 24,
                                color: isSelected
                                    ? colors.accent
                                    : colors.textTertiary,
                              ),
                              child: isSelected
                                  ? (dest.selectedIcon ?? dest.icon)
                                  : dest.icon,
                            ),
                            if (dest.label.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                dest.label,
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                      color: isSelected
                                          ? colors.accent
                                          : colors.textTertiary,
                                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                    ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

/// A glass search bar — commonly used in app bars or as a persistent header.
class GlassSearchBar extends StatelessWidget {
  const GlassSearchBar({
    super.key,
    this.controller,
    this.hintText = 'Search…',
    this.onChanged,
    this.onSubmitted,
    this.onTap,
    this.leading,
    this.trailing,
    this.enabled = true,
    this.readOnly = false,
    this.surfaceLevel = GlassSurfaceLevel.level2,
    this.blurStrength = GlassBlurStrength.normal,
    this.border = GlassBorder.subtle,
  });

  final TextEditingController? controller;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onTap;
  final Widget? leading;
  final Widget? trailing;
  final bool enabled;
  final bool readOnly;
  final GlassSurfaceLevel surfaceLevel;
  final GlassBlurStrength blurStrength;
  final GlassBorder border;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return GlassContainer(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      surfaceLevel: surfaceLevel,
      blurStrength: blurStrength,
      border: border,
      borderRadius: CandorRadius.pill,
      child: Row(
        children: [
          leading ?? Icon(Icons.search_rounded, color: colors.textTertiary, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              enabled: enabled,
              readOnly: readOnly,
              onChanged: onChanged,
              onSubmitted: onSubmitted,
              onTap: onTap,
              style: TextStyle(color: colors.textPrimary, fontSize: 16),
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: TextStyle(color: colors.textDisabled, fontSize: 16),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}