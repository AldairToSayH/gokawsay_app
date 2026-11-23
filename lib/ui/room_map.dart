import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:material_ui/material_ui.dart';

import '../locations/precise_location.dart';
import 'components.dart';
import 'external_links.dart';

const _mapsChannel = MethodChannel('gokawsay/maps');
final _canEmbedMaps = _configuredForMaps();

Future<bool> _configuredForMaps() async {
  try {
    return await _mapsChannel.invokeMethod<bool>('isConfigured') ?? false;
  } on PlatformException {
    return false;
  } on MissingPluginException {
    return false;
  }
}

Uri googleMapsSearch(String query) =>
    Uri.https('www.google.com', '/maps/search/', {'api': '1', 'query': query});

class RoomLocationField extends StatelessWidget {
  const RoomLocationField({
    super.key,
    required this.value,
    required this.districtCode,
    required this.area,
    required this.onChange,
  });

  final PreciseLocation? value;
  final String? districtCode;
  final String area;
  final ValueChanged<PreciseLocation?> onChange;

  @override
  Widget build(BuildContext context) => Panel(
    child: Column(
      spacing: 8,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(
          'Ubicación exacta',
          subtitle:
              value?.label ??
              'Opcional. El pin se mostrará en la ficha del anuncio.',
        ),
        FutureBuilder<bool>(
          future: _canEmbedMaps,
          builder: (context, snapshot) => Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              if (snapshot.data == true)
                OutlinedButton.icon(
                  icon: const Icon(Icons.pin_drop_outlined),
                  label: Text(value == null ? 'Colocar pin' : 'Mover pin'),
                  onPressed: () async {
                    final location = await Navigator.of(context)
                        .push<PreciseLocation>(
                          MaterialPageRoute(
                            builder: (_) => _RoomMap(
                              initial: value,
                              center:
                                  _districtCenters[districtCode] ??
                                  _cuscoCenter,
                              editable: true,
                            ),
                          ),
                        );
                    if (context.mounted && location != null) onChange(location);
                  },
                ),
              OutlinedButton.icon(
                icon: const Icon(Icons.edit_location_alt_outlined),
                label: const Text('Ingresar coordenadas'),
                onPressed: () async {
                  final location = await showDialog<PreciseLocation>(
                    context: context,
                    builder: (_) => _CoordinatesDialog(initial: value),
                  );
                  if (context.mounted && location != null) onChange(location);
                },
              ),
              TextButton(
                onPressed: () => openExternal(
                  context,
                  googleMapsSearch(value?.label ?? area),
                ),
                child: const Text('Abrir Google Maps'),
              ),
              if (value != null)
                TextButton(
                  onPressed: () => onChange(null),
                  child: const Text('Quitar pin'),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}

class PublishedLocation extends StatelessWidget {
  const PublishedLocation({
    super.key,
    required this.location,
    required this.area,
  });

  final PreciseLocation location;
  final String area;

  @override
  Widget build(BuildContext context) => Panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle('Ubicación exacta', subtitle: area),
        FutureBuilder<bool>(
          future: _canEmbedMaps,
          builder: (context, snapshot) => Wrap(
            spacing: 8,
            runSpacing: 5,
            children: [
              if (snapshot.data == true)
                OutlinedButton.icon(
                  icon: const Icon(Icons.map_outlined),
                  label: const Text('Ver mapa'),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => _RoomMap(
                        initial: location,
                        center: LatLng(location.latitude, location.longitude),
                      ),
                    ),
                  ),
                ),
              OutlinedButton.icon(
                icon: const Icon(Icons.location_on_outlined),
                label: const Text('Abrir en Google Maps'),
                onPressed: () =>
                    openExternal(context, googleMapsSearch(location.label)),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _RoomMap extends StatefulWidget {
  const _RoomMap({
    required this.initial,
    required this.center,
    this.editable = false,
  });

  final PreciseLocation? initial;
  final LatLng center;
  final bool editable;

  @override
  State<_RoomMap> createState() => _RoomMapState();
}

class _RoomMapState extends State<_RoomMap> {
  late PreciseLocation? _pin = widget.initial;

  void _mark(LatLng point) {
    final precise = PreciseLocation.fromValues(point.latitude, point.longitude);
    if (precise != null) setState(() => _pin = precise);
  }

  @override
  Widget build(BuildContext context) {
    final pin = _pin;
    final initial = widget.initial;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.editable ? 'Marcar ubicación' : 'Ubicación de la habitación',
        ),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.editable)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Text(
                  pin?.label ?? 'Toca la entrada de la habitación en el mapa.',
                ),
              ),
            Expanded(
              child: GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: initial == null
                      ? widget.center
                      : LatLng(initial.latitude, initial.longitude),
                  zoom: initial == null ? 13 : 17,
                ),
                onTap: widget.editable ? _mark : null,
                mapToolbarEnabled: false,
                myLocationButtonEnabled: false,
                myLocationEnabled: false,
                markers: {
                  if (pin != null)
                    Marker(
                      markerId: const MarkerId('room'),
                      position: LatLng(pin.latitude, pin.longitude),
                      infoWindow: const InfoWindow(
                        title: 'Ubicación de la habitación',
                      ),
                      draggable: widget.editable,
                      onDragEnd: widget.editable ? _mark : null,
                    ),
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: widget.editable
                  ? FilledButton(
                      onPressed: pin == null
                          ? null
                          : () => Navigator.pop(context, pin),
                      child: const Text('Usar esta ubicación'),
                    )
                  : OutlinedButton.icon(
                      icon: const Icon(Icons.open_in_new),
                      onPressed: pin == null
                          ? null
                          : () => openExternal(
                              context,
                              googleMapsSearch(pin.label),
                            ),
                      label: const Text('Abrir en Google Maps'),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CoordinatesDialog extends StatefulWidget {
  const _CoordinatesDialog({this.initial});

  final PreciseLocation? initial;

  @override
  State<_CoordinatesDialog> createState() => _CoordinatesDialogState();
}

class _CoordinatesDialogState extends State<_CoordinatesDialog> {
  final _form = GlobalKey<FormState>();
  late final _latitude = TextEditingController(
    text: widget.initial?.latitude.toString(),
  );
  late final _longitude = TextEditingController(
    text: widget.initial?.longitude.toString(),
  );

  double? _number(String text) =>
      double.tryParse(text.trim().replaceAll(',', '.'));

  @override
  void dispose() {
    _latitude.dispose();
    _longitude.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Coordenadas del pin'),
    content: SingleChildScrollView(
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 12,
          children: [
            TextFormField(
              controller: _latitude,
              keyboardType: const TextInputType.numberWithOptions(
                signed: true,
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Latitud'),
              validator: (value) =>
                  PreciseLocation.fromValues(_number(value ?? ''), 0) == null
                  ? 'Ingresa una latitud entre −90 y 90.'
                  : null,
            ),
            TextFormField(
              controller: _longitude,
              keyboardType: const TextInputType.numberWithOptions(
                signed: true,
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Longitud'),
              validator: (value) =>
                  PreciseLocation.fromValues(0, _number(value ?? '')) == null
                  ? 'Ingresa una longitud entre −180 y 180.'
                  : null,
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: () {
          if (!_form.currentState!.validate()) return;
          Navigator.pop(
            context,
            PreciseLocation.fromValues(
              _number(_latitude.text),
              _number(_longitude.text),
            ),
          );
        },
        child: const Text('Usar coordenadas'),
      ),
    ],
  );
}

const _cuscoCenter = LatLng(-13.517, -71.978);

// Inicios de cámara aproximados. La ubicación del anuncio sale del pin elegido.
const _districtCenters = {
  '080101': _cuscoCenter,
  '080104': LatLng(-13.546, -71.883),
  '080105': LatLng(-13.532, -71.936),
  '080106': LatLng(-13.526, -71.979),
  '080108': LatLng(-13.523, -71.963),
  '080401': LatLng(-13.322, -71.955),
  '080405': LatLng(-13.422, -71.851),
  '081301': LatLng(-13.305, -72.116),
  '081302': LatLng(-13.393, -72.047),
  '081304': LatLng(-13.154, -72.526),
  '081305': LatLng(-13.331, -72.157),
  '081306': LatLng(-13.258, -72.265),
  '081307': LatLng(-13.316, -72.086),
};
