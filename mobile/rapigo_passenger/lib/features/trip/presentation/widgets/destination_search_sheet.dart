import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/config/app_brand.dart';
import '../../../../core/config/potosi_places.dart';

class DestinationSearchSheet extends StatefulWidget {
  const DestinationSearchSheet({
    super.key,
    required this.originLabel,
    required this.onClose,
    required this.onMapTap,
    required this.onSuggestionTap,
    this.autofocusSearch = true,
  });

  final String originLabel;
  final VoidCallback onClose;
  final VoidCallback onMapTap;
  final void Function(String label, LatLng point) onSuggestionTap;
  final bool autofocusSearch;

  @override
  State<DestinationSearchSheet> createState() => _DestinationSearchSheetState();
}

class _DestinationSearchSheetState extends State<DestinationSearchSheet> {
  final TextEditingController _controller = TextEditingController();
  bool _isActionLocked = false;

  List<PotosiPlace> get _suggestions =>
      PotosiPlaces.search(_controller.text.trim(), limit: 8);

  void _handleClose() {
    if (_isActionLocked || !mounted) {
      return;
    }
    _isActionLocked = true;
    FocusManager.instance.primaryFocus?.unfocus();
    widget.onClose();
  }

  void _handleMapTap() {
    if (_isActionLocked || !mounted) {
      return;
    }
    _isActionLocked = true;
    FocusManager.instance.primaryFocus?.unfocus();
    widget.onMapTap();
  }

  void _handleSuggestionTap(PotosiPlace place) {
    if (_isActionLocked || !mounted) {
      return;
    }
    _isActionLocked = true;
    FocusManager.instance.primaryFocus?.unfocus();
    widget.onSuggestionTap(place.name, place.point);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final suggestions = _suggestions;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return ColoredBox(
      color: const Color(0xFFF8FAFC),
      child: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final availableHeight =
                (constraints.maxHeight - bottomInset).clamp(0.0, double.infinity);
            return Padding(
              padding: EdgeInsets.fromLTRB(20, 14, 20, bottomInset),
              child: SizedBox(
                width: constraints.maxWidth,
                height: availableHeight,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 46,
                        height: 5,
                        decoration: BoxDecoration(
                          color: const Color(0xFFD7DCE4),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        IconButton.filled(
                          onPressed: _handleClose,
                          style: IconButton.styleFrom(
                            backgroundColor: AppBrand.surfaceSoft,
                            foregroundColor: AppBrand.textPrimary,
                          ),
                          icon: const Icon(Icons.arrow_back_rounded),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Agregar parada',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: AppBrand.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 56),
                      ],
                    ),
                    const SizedBox(height: 22),
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x100F172A),
                            blurRadius: 18,
                            offset: Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          _SheetFieldRow(
                            dotColor: const Color(0xFF16A34A),
                            title: 'Origen',
                            value: widget.originLabel,
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: AppBrand.surfaceSoft,
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.search_rounded,
                                  color: AppBrand.primaryBlue,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                   child: TextField(
                                     controller: _controller,
                                     autofocus: widget.autofocusSearch,
                                     textInputAction: TextInputAction.search,
                                    onChanged: (_) => setState(() {}),
                                    onSubmitted: (_) {
                                      final first = suggestions.isEmpty
                                          ? null
                                          : suggestions.first;
                                      if (first != null) {
                                        _handleSuggestionTap(first);
                                      }
                                    },
                                    decoration: const InputDecoration(
                                      hintText: 'Destino - ¿A dónde vas?',
                                      border: InputBorder.none,
                                      hintStyle: TextStyle(
                                        color: AppBrand.textSecondary,
                                      ),
                                    ),
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                      color: AppBrand.textPrimary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                FilledButton.tonal(
                                  onPressed: _handleMapTap,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: AppBrand.surfaceMuted,
                                    foregroundColor: AppBrand.primaryBlue,
                                    minimumSize: const Size(66, 42),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  child: const Text('Mapa'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    if (_controller.text.trim().isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Text(
                            'Ingresa una ubicación o usa Mapa para fijar el punto exacto.',
                            style: GoogleFonts.plusJakartaSans(
                              color: AppBrand.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    Expanded(
                      child: suggestions.isEmpty
                          ? Center(
                              child: Text(
                                'No encontramos coincidencias todavía.',
                                style: GoogleFonts.plusJakartaSans(
                                  color: AppBrand.textSecondary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.only(bottom: 28),
                              itemCount: suggestions.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final place = suggestions[index];
                                return _SheetSuggestionTile(
                                  place: place,
                                  onTap: () => _handleSuggestionTap(place),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SheetFieldRow extends StatelessWidget {
  const _SheetFieldRow({
    required this.dotColor,
    required this.title,
    required this.value,
  });

  final Color dotColor;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    final isOrigin = title == 'Origen';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isOrigin)
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: _OriginNavigationBadge(),
          )
        else
          Container(
            width: 12,
            height: 12,
            margin: const EdgeInsets.only(top: 6),
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppBrand.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppBrand.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _OriginNavigationBadge extends StatelessWidget {
  const _OriginNavigationBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8D9),
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFFFE27A), width: 1.1),
      ),
      child: const Icon(
        Icons.navigation_rounded,
        color: AppBrand.primaryBlue,
        size: 13,
      ),
    );
  }
}

class _SheetSuggestionTile extends StatelessWidget {
  const _SheetSuggestionTile({required this.place, required this.onTap});

  final PotosiPlace place;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppBrand.surfaceSoft,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.place_rounded,
                  color: AppBrand.primaryBlue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      place.name,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppBrand.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      place.aliases.isNotEmpty
                          ? place.aliases.first
                          : 'Destino sugerido en Potosí',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppBrand.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppBrand.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
