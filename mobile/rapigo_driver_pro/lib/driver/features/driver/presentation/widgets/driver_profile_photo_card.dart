import 'package:flutter/material.dart';

import '../../../../../shared/theme/rapigo_theme.dart';

class DriverProfilePhotoCard extends StatelessWidget {
  const DriverProfilePhotoCard({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.url,
    required this.onPick,
    this.uploading = false,
    this.changed = false,
  });

  final String title;
  final String description;
  final IconData icon;
  final String? url;
  final VoidCallback? onPick;
  final bool uploading;
  final bool changed;

  @override
  Widget build(BuildContext context) {
    final palette = context.rapigoPalette;
    final hasPhoto = url != null && url!.isNotEmpty;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: palette.surfaceSecondary,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.outlineSoft),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 156,
            child: hasPhoto
                ? Image.network(
                    url!,
                    fit: BoxFit.contain,
                    errorBuilder: (_, error, stack) => Center(
                      child: Text(
                        'Vista previa no disponible',
                        style: TextStyle(color: palette.textSecondary),
                      ),
                    ),
                  )
                : Center(child: Icon(icon, size: 42, color: palette.textMuted)),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    color: palette.textSecondary,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  changed
                      ? 'Nueva foto · pendiente de guardar'
                      : hasPhoto
                      ? 'Foto guardada'
                      : 'Falta subir esta foto',
                  style: TextStyle(
                    color: changed || !hasPhoto
                        ? palette.accentYellow
                        : palette.accentGreen,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: uploading ? null : onPick,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: uploading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          hasPhoto
                              ? Icons.edit_outlined
                              : Icons.add_a_photo_outlined,
                          size: 19,
                        ),
                  label: Text(
                    uploading
                        ? 'Subiendo foto…'
                        : hasPhoto
                        ? 'Cambiar foto'
                        : 'Subir foto',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
