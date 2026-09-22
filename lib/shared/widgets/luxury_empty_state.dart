import 'package:flutter/material.dart';

class LuxuryEmptyState extends StatelessWidget {
  final IconData icon;
  final String eyebrow;
  final String title;
  final String subtitle;
  final String buttonLabel;
  final VoidCallback onPressed;
  final Color accent;
  final Widget? footer;
  final bool scrollable;

  const LuxuryEmptyState({
    super.key,
    required this.icon,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.onPressed,
    this.accent = const Color(0xFFD51B46),
    this.footer,
    this.scrollable = true,
  });

  @override
  Widget build(BuildContext context) {
    final content = Padding(
        padding: const EdgeInsets.fromLTRB(22, 28, 22, 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 26, 24, 24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: accent.withValues(alpha: .14)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x10000000),
                  blurRadius: 28,
                  offset: Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 82,
                  height: 82,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        accent.withValues(alpha: .08),
                        accent.withValues(alpha: .18),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(26),
                  ),
                  child: Icon(icon, size: 42, color: accent),
                ),
                const SizedBox(height: 20),
                Text(
                  eyebrow.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: accent,
                    fontSize: 12,
                    letterSpacing: 1.35,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF29272E),
                    fontSize: 27,
                    height: 1.12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF6F6A74),
                    fontSize: 16,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: FilledButton.icon(
                    onPressed: onPressed,
                    style: FilledButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(17),
                      ),
                    ),
                    icon: const Icon(Icons.add_rounded),
                    label: Text(
                      buttonLabel,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
                if (footer != null) ...[
                  const SizedBox(height: 20),
                  footer!,
                ],
              ],
            ),
          ),
        ),
    );
    return Center(
      child: scrollable ? SingleChildScrollView(child: content) : content,
    );
  }
}
