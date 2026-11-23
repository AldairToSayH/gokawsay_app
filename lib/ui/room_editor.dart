import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';

import '../locations/cusco.dart';
import '../locations/precise_location.dart';
import '../rentals/models.dart';
import '../rentals/rental_store.dart';
import 'components.dart';
import 'location_fields.dart';
import 'motion.dart';
import 'room_map.dart';
import 'theme.dart';

class RoomEditor extends StatefulWidget {
  const RoomEditor({
    super.key,
    required this.store,
    required this.profile,
    this.room,
  });

  final RentalStore store;
  final Profile profile;
  final Room? room;

  @override
  State<RoomEditor> createState() => _RoomEditorState();
}

class _RoomEditorState extends State<RoomEditor> {
  final _form = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.room?.title);
  late final _neighborhood = TextEditingController(
    text: _initialNeighborhood(),
  );
  late final _description = TextEditingController(
    text: widget.room?.description,
  );
  late final _price = TextEditingController(
    text: widget.room == null
        ? ''
        : (widget.room!.monthly / 100).toStringAsFixed(2),
  );
  late String? _province = widget.room?.district?.provinceCode;
  late String? _district = widget.room?.district?.code;
  late PreciseLocation? _preciseLocation = widget.room?.preciseLocation;
  late bool _deposit = widget.room?.deposit ?? true;
  late final _existingPhoto = widget.store.roomPhoto(widget.room!.id);
  bool _removePhoto = false;
  Uint8List? _photo;

  String _initialNeighborhood() {
    final room = widget.room;
    if (room == null) return '';
    if (room.data.containsKey('ubigeo')) return room.neighborhood;
    final district = room.district;
    final administrativeNames = {
      'cusco',
      if (district != null) ...[
        normalizePlace(district.province),
        normalizePlace(district.name),
        if (district.town != null) normalizePlace(district.town!),
      ],
    };
    return room.location
        .split(',')
        .map((part) => part.trim())
        .where(
          (part) =>
              part.isNotEmpty &&
              !administrativeNames.contains(normalizePlace(part)),
        )
        .join(', ');
  }

  @override
  void dispose() {
    _title.dispose();
    _neighborhood.dispose();
    _description.dispose();
    _price.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final room = widget.room;
    return Scaffold(
      appBar: AppBar(
        title: Text(room == null ? 'Publicar habitación' : 'Editar habitación'),
      ),
      body: SafeArea(
        child: Form(
          key: _form,
          child: PageList(
            children: [
              Panel(
                child: Row(
                  spacing: 12,
                  children: [
                    const MotionArtwork(
                      AppMotion.landlord,
                      size: 64,
                      loop: false,
                    ),
                    Expanded(
                      child: Text(
                        room == null
                            ? 'Prepara tu publicación'
                            : 'Actualiza tu publicación',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                  ],
                ),
              ),
              Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionTitle('Foto principal'),
                    if (room?.photo == true &&
                        !_removePhoto &&
                        _photo == null) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(designRadius),
                        child: AspectRatio(
                          aspectRatio: 1.85,
                          child: RemotePhoto(
                            photo: _existingPhoto,
                            label: 'Foto actual de la habitación',
                          ),
                        ),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => setState(() => _removePhoto = true),
                        label: const Text('Quitar foto actual'),
                      ),
                    ],
                    if (_removePhoto && _photo == null)
                      TextButton(
                        onPressed: () => setState(() => _removePhoto = false),
                        child: const Text('Conservar foto actual'),
                      ),
                    EvidencePicker(
                      label: room?.photo == true && !_removePhoto
                          ? 'Reemplazar foto'
                          : 'Agregar foto de la habitación',
                      onChange: (photo) => setState(() => _photo = photo),
                    ),
                  ],
                ),
              ),
              TextFormField(
                controller: _title,
                decoration: const InputDecoration(
                  labelText: 'Nombre de la habitación',
                ),
                maxLength: 100,
                validator: requiredText,
              ),
              const SectionTitle('Ubicación en Cusco'),
              DistrictFields(
                province: _province,
                district: _district,
                requiredSelection: true,
                onChange: (province, district) => setState(() {
                  _province = province;
                  _district = district;
                }),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _neighborhood,
                decoration: const InputDecoration(
                  labelText: 'Barrio o zona (opcional)',
                ),
                maxLength: 70,
                validator: (value) => (value?.trim().length ?? 0) > 70
                    ? 'Usa hasta 70 caracteres.'
                    : null,
              ),
              RoomLocationField(
                value: _preciseLocation,
                districtCode: _district,
                area:
                    cuscoDistrictsByCode[_district]?.location('') ??
                    'Cusco, Perú',
                onChange: (location) =>
                    setState(() => _preciseLocation = location),
              ),
              TextFormField(
                controller: _price,
                decoration: const InputDecoration(
                  labelText: 'Renta mensual',
                  prefixText: 'S/ ',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (value) => (cents(value ?? '') ?? 0) <= 0
                    ? 'Ingresa un monto válido.'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _description,
                decoration: const InputDecoration(
                  labelText: 'Descripción y servicios',
                ),
                maxLength: 1600,
                maxLines: 4,
                validator: requiredText,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Garantía a coordinar'),
                subtitle: const Text('El monto se acuerda en privado.'),
                value: _deposit,
                onChanged: (value) => setState(() => _deposit = value),
              ),
              const SizedBox(height: 12),
              AsyncAction(
                label: room == null ? 'Publicar' : 'Guardar cambios',
                busyLabel: room == null
                    ? 'Publicando habitación…'
                    : 'Actualizando habitación…',
                motion: AppMotion.landlord,
                run: _save,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final district = cuscoDistrictsByCode[_district]!;
    final neighborhood = _neighborhood.text.trim();
    final details = {
      'title': _title.text.trim(),
      'location': district.location(neighborhood),
      'ubigeo': district.code,
      'neighborhood': neighborhood,
      'coordinates': _preciseLocation?.data,
      'description': _description.text.trim(),
      'monthly': cents(_price.text)!,
      'deposit': _deposit,
    };
    final room = widget.room;
    if (room == null) {
      await widget.store.publish(widget.profile, details, _photo);
    } else {
      await widget.store.updateRoom(
        room,
        details,
        photo: _photo,
        removePhoto: _removePhoto,
      );
    }
    if (mounted) {
      showOutcome(
        context,
        AppMotion.change,
        room == null ? 'Habitación publicada.' : 'Cambios guardados.',
      );
      Navigator.pop(context);
    }
  }
}
