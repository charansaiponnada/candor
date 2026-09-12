import 'package:flutter/material.dart';

import '../widgets/glass.dart';

/// Three-panel first-run intro, shown once until the user taps through
/// (persisted via `SettingsStore.onboardingDone`).
class OnboardingScreen extends StatefulWidget {
  final Future<void> Function() onDone;
  const OnboardingScreen({super.key, required this.onDone});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _Page {
  final IconData icon;
  final String title;
  final String body;
  const _Page(this.icon, this.title, this.body);
}

const _pages = [
  _Page(Icons.cloud_off_outlined, 'Private by design',
      'Candor runs 100% on this phone. No cloud, no account, no tracking '
      'and no internet needed — your questions never leave the device.'),
  _Page(Icons.layers_outlined, 'Two minds, one honest voice',
      'A small, fast model answers instantly. When it isn\'t sure, a larger '
      'on-device model takes over — and Candor tells you which one replied, '
      'under every answer.'),
  _Page(Icons.tips_and_updates_outlined, 'Candid about itself',
      'The tier tag shows whether your reply came from the small model, the '
      'large model or a fallback — and why. No silent black box.'),
];

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _page = PageController();
  int _index = 0;

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  void _next() {
    if (_index == _pages.length - 1) {
      widget.onDone();
    } else {
      _page.nextPage(
          duration: const Duration(milliseconds: 280), curve: Curves.easeOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final last = _index == _pages.length - 1;
    return Scaffold(
      backgroundColor: CandorColors.black,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 8, right: 8),
                child: GlassTextButton(
                  onPressed: widget.onDone,
                  child: const Text('Skip'),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _page,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) {
                  final p = _pages[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        GlassCircle(
                          size: 120,
                          surfaceLevel: GlassSurfaceLevel.level2,
                          border: GlassBorder.normal,
                          child: Icon(p.icon, size: 56, color: cs.accent),
                        ),
                        const SizedBox(height: 40),
                        Text(p.title,
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium
                                ?.copyWith(fontWeight: FontWeight.w600, color: cs.textPrimary)),
                        const SizedBox(height: 16),
                        Text(p.body,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                height: 1.5, color: cs.textSecondary)),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 0, 32, 24),
              child: Row(
                children: [
                  for (var i = 0; i < _pages.length; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(right: 6),
                      width: i == _index ? 22 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: i == _index ? cs.accent : cs.glassBorder1,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  const Spacer(),
                  GlassFilledButton(
                    onPressed: _next,
                    child: Text(last ? 'Start chatting' : 'Next'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}