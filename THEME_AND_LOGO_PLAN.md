# Candor App - Theme & Logo Redesign Plan

## Project Overview
Flutter app (Candor) - On-device two-tier SLM assistant. Current theme uses Material 3 with warm clay seed color (0xFFA64B2A).

---

## Task 1: Theme Overhaul - Black Background + White Text + iOS-style Glassmorphism

### Current State
- Material 3 theme with `ColorScheme.fromSeed(seedColor: 0xFFA64B2A)`
- Light/dark theme support via `ThemeMode` (system/light/dark)
- Settings screen has segmented button for theme mode selection
- App uses standard Material components (AppBar, Scaffold, Cards, etc.)

### Target Design
- **Pure black background** (`#000000`) - OLED-friendly true black
- **White text** (`#FFFFFF`) for primary content
- **Glassmorphism/iOS-style frosted glass effects**:
  - Semi-transparent surfaces with blur
  - Subtle borders (1px, white with low opacity)
  - Layered depth with elevation shadows
- **Accent color**: Keep a refined accent (maybe a cooler blue/cyan or keep warm accent for brand consistency)

### Implementation Strategy

#### 1.1 Create Custom Theme Data (`lib/theme/app_theme.dart`)
- Define custom `ColorScheme` for "OLED Black" theme
- Create glassmorphism helper widgets:
  - `GlassContainer` - frosted glass card with blur
  - `GlassAppBar` - translucent app bar with blur background
  - `GlassBottomSheet` - for modals
  - `GlassTextField` - input with glass effect
- Define custom `ThemeData` with overridden component themes

#### 1.2 Update `main.dart`
- Replace `_theme()` function with new glassmorphism theme
- Ensure both light/dark modes use the new black-based theme (or make dark mode the default)
- Remove theme mode selector or simplify to just "OLED Black" default

#### 1.3 Update Screens to Use Glass Components
- **ChatScreen**: Glass message bubbles, glass composer, glass app bar
- **SettingsScreen**: Glass cards for sections, glass segmented button
- **OnboardingScreen**: Glass page indicators, glass buttons
- **ConversationsScreen**: Glass list items
- **PromptLabScreen**: Glass parameter cards
- **SkillsScreen**: Glass skill cards
- **DebugPanel**: Glass panels

#### 1.4 Glassmorphism Technical Details
```dart
// Frosted glass effect using BackdropFilter
ClipRRect(
  borderRadius: BorderRadius.circular(20),
  child: BackdropFilter(
    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
    child: Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05), // Very subtle white tint
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: content,
    ),
  ),
)
```

---

## Task 2: New Modern Logo Design

### Current Logo
- `assets/icon/app_icon.png` (48KB)
- `assets/icon/app_icon_foreground.png` + SVG
- Warm clay color (#A64B2A) background with "C" letter

### Target Logo
- **Modern, minimal, tech-forward** aesthetic
- **Glassmorphism-compatible** - works on black background
- **Scalable** - works at all sizes (app icon, splash, favicon)
- **Concept**: "Candor" = honesty, truth, clarity
  - Visual metaphor: Light through prism, clean typography, or abstract "C" with transparency layers

### Design Concepts
1. **Prism/Light Refraction** - White light splitting (honesty/clarity)
2. **Minimal "C" with Glass Layers** - Frosted glass "C" with depth
3. **Neural Pathway** - Abstract nodes connecting (AI/on-device)
4. **Typography-based** - Custom "Candor" wordmark with glass effect

### Deliverables
- **App Icon** (1024x1024) - for flutter_launcher_icons
- **Adaptive Icon Foreground** (432x432) - for Android adaptive icons
- **SVG Source** - for scaling
- **Variants**: Light (for light bg), Dark (for black bg)

### Implementation
1. Design in SVG (vector) using geometric shapes
2. Export PNGs at required sizes
3. Update `pubspec.yaml` flutter_launcher_icons config
4. Run `flutter pub run flutter_launcher_icons:main`
5. Update iOS/Android native configs if needed

---

## Execution Order

### Phase 1: Theme Foundation (Do First)
1. Create `lib/theme/app_theme.dart` with glassmorphism system
2. Update `main.dart` to use new theme
3. Create reusable glass widgets in `lib/widgets/glass/`

### Phase 2: Screen Updates
4. Update ChatScreen (most visible)
5. Update SettingsScreen
6. Update OnboardingScreen
7. Update remaining screens

### Phase 3: Logo Design
8. Create new logo SVG + PNG exports
9. Update pubspec.yaml and regenerate icons
10. Verify on device/emulator

### Phase 4: Polish
11. Test all screens in both orientations
12. Verify performance (blur filters can be expensive)
13. Fine-tune opacity/blur values

---

## Files to Create/Modify

### New Files
- `lib/theme/app_theme.dart` - Custom theme system
- `lib/widgets/glass/glass_container.dart` - Reusable glass card
- `lib/widgets/glass/glass_app_bar.dart` - Glass app bar
- `lib/widgets/glass/glass_text_field.dart` - Glass input
- `lib/widgets/glass/glass_button.dart` - Glass buttons
- `assets/icon/new_logo.svg` - Vector logo source
- `assets/icon/new_app_icon.png` - 1024x1024
- `assets/icon/new_app_icon_foreground.png` - 432x432

### Modified Files
- `lib/main.dart` - Theme integration
- `lib/screens/chat_screen.dart` - Glass components
- `lib/screens/settings_screen.dart` - Glass components
- `lib/screens/onboarding_screen.dart` - Glass components
- `lib/screens/conversations_screen.dart` - Glass components
- `lib/screens/prompt_lab_screen.dart` - Glass components
- `lib/screens/skills_screen.dart` - Glass components
- `lib/screens/debug_panel.dart` - Glass components
- `pubspec.yaml` - Update icon paths

---

## Technical Considerations

### Performance
- `BackdropFilter` with blur is GPU-intensive
- Use sparingly - only on key surfaces (app bar, cards, modals)
- Consider `ClipRRect` + `BackdropFilter` only where needed
- Test on lower-end devices

### Accessibility
- Ensure contrast ratios meet WCAG AA (white on black = 21:1 ✓)
- Glass surfaces must maintain readable text
- Provide "Reduce Motion" / "Reduce Transparency" options in settings

### Platform Specifics
- Android: Adaptive icons need foreground + background
- iOS: Icon needs square with rounded corners (system applies mask)
- Glassmorphism feels native on iOS, custom on Android (but works)

---

## Success Criteria
- [ ] App launches with true black (#000000) background
- [ ] All text is white/high-contrast
- [ ] Key surfaces use frosted glass effect with blur
- [ ] Smooth 60fps scrolling on mid-range devices
- [ ] New logo looks crisp at all sizes
- [ ] App icon updates correctly on device home screen
- [ ] Settings theme selector still works (or simplified)
- [ ] No visual regressions on existing functionality