import 'package:material_ui/material_ui.dart';

import '../rentals/models.dart';
import '../rentals/rental_store.dart';
import 'components.dart';
import 'motion.dart';

class UserRating extends StatefulWidget {
  const UserRating({super.key, required this.store, required this.uid});

  final RentalStore store;
  final String uid;

  @override
  State<UserRating> createState() => _UserRatingState();
}

class _UserRatingState extends State<UserRating> {
  late var _summary = widget.store.ratingSummary(widget.uid);

  @override
  void didUpdateWidget(covariant UserRating oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.uid != widget.uid || oldWidget.store != widget.store) {
      _summary = widget.store.ratingSummary(widget.uid);
    }
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<RatingSummary>(
    key: ValueKey(widget.uid),
    stream: _summary,
    builder: (context, snapshot) {
      final theme = Theme.of(context);
      final summary = snapshot.data;
      var label = 'Cargando calificación…';
      if (snapshot.hasError) {
        label = 'Calificación no disponible';
      } else if (summary != null) {
        final count = summary.count;
        label = count == 0
            ? 'Aún sin calificaciones'
            : '${summary.average.toStringAsFixed(1)} de 5 · '
                  '$count ${count == 1 ? 'calificación' : 'calificaciones'}';
      }
      return Row(
        spacing: 6,
        children: [
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData)
            const MotionArtwork(AppMotion.internal, size: 20)
          else
            Icon(
              summary != null && summary.count > 0
                  ? Icons.star_rounded
                  : Icons.star_outline_rounded,
              size: 20,
              color: theme.colorScheme.primary,
            ),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      );
    },
  );
}

class RentalRatingPanel extends StatefulWidget {
  const RentalRatingPanel({
    super.key,
    required this.rental,
    required this.store,
    required this.uid,
  });

  final Rental rental;
  final RentalStore store;
  final String uid;

  @override
  State<RentalRatingPanel> createState() => _RentalRatingPanelState();
}

class _RentalRatingPanelState extends State<RentalRatingPanel> {
  late final _rating = widget.store.rentalRating(
    widget.rental.counterpartUid(widget.uid),
    widget.rental.id,
  );
  int _score = 0;

  Future<void> _submit() async {
    await widget.store.rateRental(widget.rental, widget.uid, _score);
    if (mounted) {
      notice(context, 'Tu calificación quedó registrada. Gracias.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final rental = widget.rental;
    if (rental.phase != RentalPhase.closed ||
        (widget.uid != rental.owner && widget.uid != rental.tenant)) {
      return const SizedBox.shrink();
    }
    final owner = rental.isOwner(widget.uid);
    return Panel(
      child: DataView<int?>(
        stream: _rating,
        loadingLabel: 'Consultando tu calificación…',
        buildData: (sentScore) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 10,
          children: [
            SectionTitle(
              sentScore == null
                  ? 'Califica a tu ${owner ? 'arrendatario' : 'arrendador'}'
                  : 'Tu calificación fue enviada',
              subtitle: rental.counterpart(widget.uid),
            ),
            Wrap(
              alignment: WrapAlignment.center,
              children: [
                for (var value = 1; value <= 5; value++)
                  IconButton(
                    key: ValueKey('rating-star-$value'),
                    tooltip: '$value ${value == 1 ? 'estrella' : 'estrellas'}',
                    onPressed: sentScore == null
                        ? () => setState(() => _score = value)
                        : null,
                    style: IconButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.primary,
                      disabledForegroundColor: Theme.of(context)
                          .colorScheme
                          .primary,
                      minimumSize: const Size(48, 48),
                    ),
                    icon: Icon(
                      value <= (sentScore ?? _score)
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      size: 32,
                    ),
                  ),
              ],
            ),
            Text(
              sentScore != null
                  ? '$sentScore de 5 estrellas. Esta calificación es definitiva.'
                  : _score == 0
                  ? 'Selecciona de una a cinco estrellas.'
                  : 'Has seleccionado $_score de 5 estrellas.',
              textAlign: TextAlign.center,
            ),
            if (sentScore == null)
              if (_score == 0)
                const FilledButton(
                  onPressed: null,
                  child: Text('Enviar calificación'),
                )
              else
                AsyncAction(
                  key: const ValueKey('submit-rating'),
                  label: 'Enviar calificación',
                  icon: Icons.star_rounded,
                  busyLabel: 'Enviando calificación…',
                  run: _submit,
                ),
          ],
        ),
      ),
    );
  }
}
