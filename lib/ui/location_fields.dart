import 'package:material_ui/material_ui.dart';

import '../locations/cusco.dart';
import '../rentals/models.dart';

class RoomArea {
  const RoomArea({this.zone, this.province, this.district});

  final CuscoZone? zone;
  final String? province;
  final String? district;

  bool get isEmpty => zone == null && province == null && district == null;

  String? get selectionLabel => district == null
      ? cuscoProvinces[province]
      : cuscoDistrictsByCode[district]?.label;

  bool includes(Room room, String query) => room.matches(
    query,
    zone: zone,
    province: province,
    districtCode: district,
  );
}

class AreaFilterBar extends StatelessWidget {
  const AreaFilterBar({super.key, required this.area, required this.onChange});

  final RoomArea area;
  final ValueChanged<RoomArea> onChange;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 6,
    children: [
      ChoiceChip(
        label: const Text('Todo Cusco'),
        selected: area.isEmpty,
        onSelected: (_) => onChange(const RoomArea()),
      ),
      for (final zone in CuscoZone.values)
        ChoiceChip(
          label: Text(zone.label),
          selected: area.zone == zone,
          onSelected: (selected) =>
              onChange(RoomArea(zone: selected ? zone : null)),
        ),
      ActionChip(
        avatar: const Icon(Icons.place_outlined, size: 17),
        label: Text(area.selectionLabel ?? 'Provincia y distrito'),
        onPressed: () async {
          final selection = await showModalBottomSheet<RoomArea>(
            context: context,
            useSafeArea: true,
            isScrollControlled: true,
            showDragHandle: true,
            builder: (_) => AreaSheet(initial: area),
          );
          if (context.mounted && selection != null) onChange(selection);
        },
      ),
    ],
  );
}

class AreaSheet extends StatefulWidget {
  const AreaSheet({super.key, required this.initial});

  final RoomArea initial;

  @override
  State<AreaSheet> createState() => _AreaSheetState();
}

class _AreaSheetState extends State<AreaSheet> {
  late RoomArea _selection = widget.initial;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 5, 22, 24),
      child: Column(
        spacing: 14,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Ubicación en Cusco',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          DistrictFields(
            province: _selection.province,
            district: _selection.district,
            onChange: (province, district) => setState(
              () =>
                  _selection = RoomArea(province: province, district: district),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              context,
              RoomArea(
                province: _selection.province,
                district: _selection.district,
              ),
            ),
            child: const Text('Ver habitaciones'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, const RoomArea()),
            child: const Text('Quitar filtro de ubicación'),
          ),
        ],
      ),
    ),
  );
}

class DistrictFields extends StatelessWidget {
  const DistrictFields({
    super.key,
    required this.province,
    required this.district,
    required this.onChange,
    this.requiredSelection = false,
  });

  final String? province;
  final String? district;
  final bool requiredSelection;
  final void Function(String? province, String? district) onChange;

  @override
  Widget build(BuildContext context) {
    final districts =
        cuscoDistricts.where((entry) => entry.provinceCode == province).toList()
          ..sort(
            (a, b) =>
                normalizePlace(a.label).compareTo(normalizePlace(b.label)),
          );
    return Column(
      spacing: 12,
      children: [
        DropdownButtonFormField<String>(
          initialValue: province ?? '',
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Provincia'),
          items: [
            DropdownMenuItem(
              value: '',
              child: Text(
                requiredSelection
                    ? 'Elige una provincia'
                    : 'Todas las provincias',
              ),
            ),
            for (final entry in cuscoProvinces.entries)
              DropdownMenuItem(value: entry.key, child: Text(entry.value)),
          ],
          onChanged: (value) {
            final next = value == '' ? null : value;
            if (next != province) onChange(next, null);
          },
          validator: (value) => requiredSelection && value == ''
              ? 'Selecciona la provincia.'
              : null,
        ),
        DropdownButtonFormField<String>(
          key: ValueKey(province),
          initialValue: district ?? '',
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Distrito o localidad'),
          items: [
            DropdownMenuItem(
              value: '',
              child: Text(
                requiredSelection ? 'Elige un distrito' : 'Todos los distritos',
              ),
            ),
            for (final entry in districts)
              DropdownMenuItem(
                value: entry.code,
                child: Text(entry.label, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: province == null
              ? null
              : (value) => onChange(province, value == '' ? null : value),
          validator: (value) => requiredSelection && value == ''
              ? 'Selecciona el distrito.'
              : null,
        ),
      ],
    );
  }
}
