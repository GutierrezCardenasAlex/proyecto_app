import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class RapigoDrawerShell extends StatelessWidget {
  const RapigoDrawerShell({
    super.key,
    required this.header,
    required this.children,
  });

  final Widget header;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(18),
              child: header,
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: children,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
              child: Text(
                'RAPIGO - PRO',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w900,
                  color: theme.colorScheme.secondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
