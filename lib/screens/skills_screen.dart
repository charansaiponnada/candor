import 'package:flutter/material.dart';

import '../services/skills.dart';

/// Skills hub — a tile grid (Gallery-style: skim, tap an example, it runs in
/// the chat). Tapping an example pops the screen and returns that prompt.
class SkillsScreen extends StatelessWidget {
  const SkillsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Skills'),
        backgroundColor: Colors.transparent,
        scrolledUnderElevation: 0,
      ),
      body: GridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
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
    );
  }
}