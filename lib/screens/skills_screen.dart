import 'package:flutter/material.dart';

import '../services/skills.dart';
import '../services/stores.dart';
import 'benchmarks_screen.dart';
import 'prompt_lab_screen.dart';

/// Skills hub — a tile grid (Gallery-style: skim, tap an example, it runs in
/// the chat). Tapping an example pops the screen and returns that prompt.
class SkillsScreen extends StatelessWidget {
  final SettingsStore? store;
  const SkillsScreen({super.key, this.store});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Skills'),
        backgroundColor: Colors.transparent,
        scrolledUnderElevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Row(
            children: [
              Expanded(
                child: _LinkCard(
                  icon: Icons.speed_rounded,
                  title: 'Models & Benchmarks',
                  subtitle: 'Prove the speed of every bundled model',
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const BenchmarksScreen())),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _LinkCard(
                  icon: Icons.science_outlined,
                  title: 'Prompt Lab',
                  subtitle: 'Tune sampling, test one-shot asks',
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => PromptLabScreen(store: store))),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.92,
            ),
            itemCount: skillsCatalog.length,
            itemBuilder: (context, i) {
              final skill = skillsCatalog[i];
              return Material(
                color: cs.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(20),
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => Navigator.of(context).pop(skill.examples.first),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: cs.primaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(toolIcon(skill.kind),
                              size: 20, color: cs.onPrimaryContainer),
                        ),
                        const SizedBox(height: 10),
                        Text(skill.name,
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Expanded(
                          child: Text(skill.description,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(color: cs.onSurfaceVariant, height: 1.35)),
                        ),
                        Text(skill.examples.first,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(color: cs.primary)),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _LinkCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _LinkCard(
      {required this.icon,
      required this.title,
      required this.subtitle,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.secondaryContainer,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 22, color: cs.onSecondaryContainer),
              const SizedBox(height: 8),
              Text(title,
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(color: cs.onSurfaceVariant, height: 1.3)),
            ],
          ),
        ),
      ),
    );
  }
}