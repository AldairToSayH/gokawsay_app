import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import 'motion.dart';

String soles(int cents) =>
    'S/ ${(cents / 100).toStringAsFixed(cents % 100 == 0 ? 0 : 2)}';
String? requiredText(String? value) =>
    value == null || value.trim().isEmpty ? 'Completa este campo.' : null;
String day(int epoch) =>
    DateFormat('dd/MM/yyyy')
        .format(DateTime.fromMillisecondsSinceEpoch(epoch, isUtc: true));
String time(int epoch) =>
    DateFormat('dd/MM HH:mm')
        .format(DateTime.fromMillisecondsSinceEpoch(epoch));

int? cents(String input) {
  final value = input.trim().replaceAll(',', '.');
  if (!RegExp(r'^\d{1,5}(\.\d{1,2})?$').hasMatch(value)) return null;
  final parts = value.split('.');
  return int.parse(parts.first) * 100 +
      (parts.length == 1 ? 0 : int.parse(parts.last.padRight(2, '0')));
}

String friendlyError(Object error) {
  final text = error.toString().toLowerCase();
  if (text.contains('permission') || text.contains('denied')) {
    return 'Esta acción ya no está disponible. Revisa el estado e inténtalo de nuevo.';
  }
  if (text.contains('network') || text.contains('unavailable')) {
    return 'No se pudo conectar. Comprueba tu conexión e inténtalo de nuevo.';
  }
  return 'No se pudo completar la acción. Inténtalo de nuevo.';
}

void notice(BuildContext context, String message) =>
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));

class AsyncAction extends StatefulWidget {
  const AsyncAction({
    super.key,
    required this.label,
    required this.run,
    this.icon,
    this.secondary = false,
    this.busyLabel = 'Guardando…',
    this.motion = AppMotion.internal,
  });

  final String label;
  final Future<void> Function() run;
  final IconData? icon;
  final bool secondary;
  final String busyLabel;
  final AppMotion motion;

  @override
  State<AsyncAction> createState() => _AsyncActionState();
}

class _AsyncActionState extends State<AsyncAction> {
  bool _busy = false;

  Future<void> _run() async {
    setState(() => _busy = true);
    try {
      await widget.run();
    } catch (error) {
      if (mounted) notice(context, friendlyError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = Text(_busy ? widget.busyLabel : widget.label);
    final icon = _busy
        ? MotionArtwork(widget.motion, size: 30)
        : widget.icon == null
        ? null
        : Icon(widget.icon);
    return widget.secondary
        ? OutlinedButton.icon(
            onPressed: _busy ? null : _run,
            icon: icon,
            label: label,
          )
        : FilledButton.icon(
            onPressed: _busy ? null : _run,
            icon: icon,
            label: label,
          );
  }
}

class DataView<T> extends StatelessWidget {
  const DataView({
    super.key,
    required this.stream,
    required this.buildData,
    this.motion = AppMotion.internal,
    this.loadingLabel = 'Cargando…',
  });

  final Stream<T> stream;
  final Widget Function(T) buildData;
  final AppMotion motion;
  final String loadingLabel;

  @override
  Widget build(BuildContext context) => StreamBuilder<T>(
    stream: stream,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              friendlyError(snapshot.error!),
              textAlign: TextAlign.center,
            ),
          ),
        );
      }
      if (snapshot.connectionState == ConnectionState.waiting &&
          !snapshot.hasData) {
        return LoadingState(motion: motion, label: loadingLabel);
      }
      return buildData(snapshot.data as T);
    },
  );
}

class PageList extends StatelessWidget {
  const PageList({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      final side = ((bounds.maxWidth - 744) / 2).clamp(20.0, double.infinity);
      return ListView(
        padding: EdgeInsets.fromLTRB(side, 16, side, 28),
        children: children,
      );
    },
  );
}

class Panel extends StatelessWidget {
  const Panel({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 14),
    child: Padding(padding: const EdgeInsets.all(18), child: child),
  );
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.label, {super.key, this.subtitle});

  final String label;
  final String? subtitle;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 10, bottom: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.titleLarge),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(subtitle!, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ],
    ),
  );
}

class EmptyState extends StatelessWidget {
  const EmptyState(
    this.title,
    this.detail, {
    super.key,
    this.icon = Icons.inbox_outlined,
  });

  final String title;
  final String detail;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Panel(
    child: Column(
      children: [
        CircleAvatar(
          radius: 27,
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
          child: Icon(icon, size: 27),
        ),
        const SizedBox(height: 12),
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 5),
        Text(detail, textAlign: TextAlign.center),
      ],
    ),
  );
}

class StatusLabel extends StatelessWidget {
  const StatusLabel(this.label, {super.key, this.icon, this.emphasis = false});

  final String label;
  final IconData? icon;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final foreground = emphasis
        ? scheme.onPrimaryContainer
        : scheme.onSecondaryContainer;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: emphasis ? scheme.primaryContainer : scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              ExcludeSemantics(child: Icon(icon, size: 15, color: foreground)),
              const SizedBox(width: 5),
            ],
            Flexible(
              child: Text(
                label,
                style: Theme.of(context).textTheme.labelMedium
                    ?.copyWith(color: foreground),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class EvidencePicker extends StatefulWidget {
  const EvidencePicker({
    super.key,
    required this.onChange,
    this.label = 'Adjuntar foto',
  });

  final ValueChanged<Uint8List?> onChange;
  final String label;

  @override
  State<EvidencePicker> createState() => _EvidencePickerState();
}

class _EvidencePickerState extends State<EvidencePicker> {
  Uint8List? _photo;
  bool _picking = false;

  Future<void> _pick() async {
    setState(() => _picking = true);
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 65,
        requestFullMetadata: false,
      );
      if (file == null || !mounted) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      if (bytes.length > 500000) {
        notice(context, 'Elige una foto más liviana, de hasta 500 KB.');
        return;
      }
      setState(() => _photo = bytes);
      widget.onChange(bytes);
    } catch (_) {
      if (mounted) notice(context, 'No se pudo abrir la foto.');
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (_photo case final bytes?)
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.memory(
            bytes,
            height: 110,
            fit: BoxFit.cover,
            semanticLabel: 'Foto adjunta',
          ),
        ),
      OutlinedButton.icon(
        onPressed: _picking ? null : _pick,
        icon: _picking
            ? const MotionArtwork(AppMotion.internal, size: 27)
            : const Icon(Icons.add_photo_alternate_outlined),
        label: Text(
          _picking
              ? 'Abriendo fotos…'
              : _photo == null
              ? widget.label
              : 'Cambiar foto',
        ),
      ),
      if (_photo != null)
        TextButton(
          onPressed: () {
            setState(() => _photo = null);
            widget.onChange(null);
          },
          child: const Text('Quitar foto'),
        ),
    ],
  );
}

class RemotePhoto extends StatelessWidget {
  const RemotePhoto({
    super.key,
    required this.photo,
    required this.label,
    this.fit = BoxFit.cover,
  });

  final Future<Uint8List?> photo;
  final String label;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) => FutureBuilder(
    future: photo,
    builder: (context, snapshot) => switch (snapshot) {
      AsyncSnapshot(:final data?) => Image.memory(
        data,
        fit: fit,
        semanticLabel: label,
        width: double.infinity,
        errorBuilder: (_, _, _) => const PhotoPlaceholder(),
      ),
      AsyncSnapshot(connectionState: ConnectionState.waiting) => ColoredBox(
        color: Theme.of(context).colorScheme.surfaceContainer,
        child: const Center(child: MotionArtwork(AppMotion.internal, size: 62)),
      ),
      _ => const PhotoPlaceholder(),
    },
  );
}

class PhotoPlaceholder extends StatelessWidget {
  const PhotoPlaceholder({super.key});

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Theme.of(context).colorScheme.secondaryContainer,
    child: Center(
      child: Icon(
        Icons.other_houses_outlined,
        color: Theme.of(context).colorScheme.onSecondaryContainer,
        size: 46,
      ),
    ),
  );
}
