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
    return ColoredBox(
      color: const Color(0xFFF5F6FA),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip: 'Volver al mapa',
                    onPressed: _handleClose,
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Agrega tu destino',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                '¿A dónde quieres ir?',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: AppBrand.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Busca un lugar o marca el punto exacto en el mapa.',
                style: TextStyle(color: AppBrand.textSecondary, height: 1.5),
              ),
              const SizedBox(height: 22),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: _SheetFieldRow(
                  dotColor: AppBrand.success,
                  title: 'Origen',
                  value: widget.originLabel,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _controller,
                autofocus: widget.autofocusSearch,
                textInputAction: TextInputAction.search,
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) {
                  if (suggestions.isNotEmpty) {
                    _handleSuggestionTap(suggestions.first);
                  }
                },
                decoration: InputDecoration(
                  labelText: 'Destino',
                  hintText: 'Escribe una dirección o lugar',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _controller.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Borrar búsqueda',
                          onPressed: () => setState(_controller.clear),
                          icon: const Icon(Icons.close_rounded),
                        ),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: const BorderSide(color: Color(0xFFE8EBF2)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _handleMapTap,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  foregroundColor: AppBrand.secondaryBlue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: const Icon(Icons.add_location_alt_outlined),
                label: const Text('Elegir en el mapa'),
              ),
              const SizedBox(height: 26),
              Text(
                _controller.text.trim().isEmpty
                    ? 'Lugares sugeridos'
                    : 'Resultados',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              if (suggestions.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(18),
                  child: Text(
                    'No encontramos ese lugar. Prueba otro nombre o elige el punto en el mapa.',
                    style: TextStyle(
                      color: AppBrand.textSecondary,
                      height: 1.5,
                    ),
                  ),
                )
              else
                ...suggestions.map(
                  (place) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _SheetSuggestionTile(
                      place: place,
                      onTap: () => _handleSuggestionTap(place),
                    ),
                  ),
                ),
            ],
          ),
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
