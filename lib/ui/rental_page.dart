import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';

import '../rentals/models.dart';
import '../rentals/rental_store.dart';
import 'components.dart';
import 'motion.dart';
import 'ratings.dart';
import 'theme.dart';

class RentalPage extends StatefulWidget {
  const RentalPage({
    super.key,
    required this.id,
    required this.store,
    required this.profile,
  });
  final String id;
  final RentalStore store;
  final Profile profile;

  @override
  State<RentalPage> createState() => _RentalPageState();
}

class _RentalPageState extends State<RentalPage> {
  late final _rental = widget.store.rental(widget.id);
  Stream<Room?>? _listing;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Detalle del alquiler')),
    body: SafeArea(
      child: DataView(
        stream: _rental,
        loadingLabel: 'Cargando el alquiler…',
        buildData: (rental) {
          if (rental == null) {
            return const Center(child: Text('Solicitud no disponible.'));
          }
          if (rental.isOwner(widget.profile.uid) &&
              rental.phase == RentalPhase.requested) {
            return StreamBuilder<Room?>(
              stream: _listing ??= widget.store.room(rental.room.id),
              initialData: rental.room,
              builder: (context, listing) => RentalDetails(
                rental: rental,
                store: widget.store,
                profile: widget.profile,
                listingRemoved: listing.data == null || listing.data!.archived,
              ),
            );
          }
          return RentalDetails(
            rental: rental,
            store: widget.store,
            profile: widget.profile,
          );
        },
      ),
    ),
  );
}

class RentalDetails extends StatelessWidget {
  const RentalDetails({
    super.key,
    required this.rental,
    required this.store,
    required this.profile,
    this.listingRemoved = false,
  });
  final Rental rental;
  final RentalStore store;
  final Profile profile;
  final bool listingRemoved;

  String get uid => profile.uid;
  bool get owner => rental.isOwner(uid);
  bool recorded(String section) => rental.section(section).containsKey(uid);

  @override
  Widget build(BuildContext context) => PageList(
    children: [
      RentalHeader(rental: rental),
      const SizedBox(height: 12),
      UserRating(store: store, uid: rental.counterpartUid(uid)),
      const SizedBox(height: 12),
      OutlinedButton.icon(
        onPressed: () => _open(
          context,
          ChatPage(rental: rental, store: store, profile: profile),
        ),
        icon: const Icon(Icons.chat_bubble_outline_rounded),
        label: Text('Conversar con ${rental.counterpart(uid)}'),
      ),
      const SizedBox(height: 16),
      ..._next(context),
      if (rental.phase == RentalPhase.inspection ||
          rental.phase == RentalPhase.contract)
        AsyncAction(
          secondary: true,
          label: 'Cancelar acuerdo',
          run: () async {
            if (await _confirm(
              context,
              'Cancelar acuerdo',
              'Se libera la selección de la habitación y ambas partes conservan su historial.',
            )) {
              await store.cancel(rental);
            }
          },
        ),
      if (rental.terms.isNotEmpty)
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionTitle('Acuerdo de alquiler'),
              Text(
                '${day((rental.terms['start'] as num).toInt())} al ${day((rental.terms['end'] as num).toInt())}',
              ),
              Text('${soles(rental.room.monthly)} al mes'),
              Text('Garantía acordada: ${soles(rental.guarantee)}'),
              if (owner &&
                  rental.section('contract').isEmpty &&
                  rental.phase != RentalPhase.cancelled)
                TextButton(
                  onPressed: () => _open(
                    context,
                    AgreementForm(rental: rental, store: store),
                  ),
                  child: const Text('Editar acuerdo'),
                ),
              if ((rental.terms['note'] as String).isNotEmpty)
                Text(rental.terms['note'] as String),
            ],
          ),
        ),
      if (rental.section('entry').isNotEmpty)
        _recordSection(
          context,
          'Inspección de ingreso',
          'entry',
          checklist: true,
        ),
      if (rental.both('entry'))
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionTitle(
                'Contrato',
                subtitle:
                    '${rental.section('contract').length} de 2 confirmaciones',
              ),
              OutlinedButton.icon(
                onPressed: () => _open(context, ContractPage(rental: rental)),
                icon: const Icon(Icons.description_outlined),
                label: const Text('Ver contrato generado'),
              ),
              if (rental.phase == RentalPhase.contract && !recorded('contract'))
                AsyncAction(
                  label: 'Aceptar contrato',
                  run: () async {
                    if (await _confirm(
                      context,
                      'Aceptar contrato',
                      'Confirma que leíste el contrato generado y aceptas los términos del alquiler.',
                    )) {
                      await store.acceptContract(rental, uid);
                      if (context.mounted) {
                        notice(context, 'Aceptación del contrato registrada.');
                      }
                    }
                  },
                ),
            ],
          ),
        ),
      if (rental.section('deposit').isNotEmpty)
        _recordSection(context, 'Entrega de garantía', 'deposit'),
      if (rental.phase.index >= RentalPhase.active.index) _payments(context),
      if (rental.section('exit').isNotEmpty)
        _recordSection(
          context,
          'Inspección de salida',
          'exit',
          checklist: true,
        ),
      if (rental.settlement.isNotEmpty)
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionTitle('Liquidación acordada'),
              Text('Saldo pendiente: ${soles(rental.balance)}'),
              Text(
                'Descuento de garantía: ${soles(rental.guarantee - rental.refund)}',
              ),
              Text('Devolución de garantía: ${soles(rental.refund)}'),
              if (owner && rental.section('close').isEmpty)
                TextButton(
                  onPressed: () => _open(
                    context,
                    AgreementForm(
                      rental: rental,
                      store: store,
                      settlement: true,
                    ),
                  ),
                  child: const Text('Editar liquidación'),
                ),
              if ((rental.settlement['note'] as String).isNotEmpty)
                Text(rental.settlement['note'] as String),
              const SizedBox(height: 8),
              Text(
                '${rental.section('close').length} de 2 confirmaciones de cierre',
              ),
            ],
          ),
        ),
      if (rental.section('close').isNotEmpty)
        _recordSection(context, 'Registros de cierre', 'close'),
    ],
  );

  List<Widget> _next(BuildContext context) {
    switch (rental.phase) {
      case RentalPhase.requested:
        return [
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SectionTitle(
                  'Solicitud pendiente',
                  subtitle: listingRemoved
                      ? 'La publicación fue retirada. Puedes conservar el chat o rechazar la solicitud.'
                      : owner
                      ? 'Conversa con esta persona y decide cuándo avanzar.'
                      : 'El arrendador revisará tu solicitud. Puedes escribirle para coordinar una visita.',
                ),
                if (owner && !listingRemoved) ...[
                  AsyncAction(
                    label: 'Elegir esta solicitud',
                    run: () async {
                      if (await _confirm(
                        context,
                        'Elegir esta solicitud',
                        'La persona podrá continuar con el acuerdo y la inspección de ingreso. Las demás solicitudes siguen en tu bandeja.',
                      )) {
                        await store.decide(rental, true);
                        if (context.mounted) {
                          showOutcome(
                            context,
                            AppMotion.booking,
                            'Reserva confirmada. Ya pueden acordar el ingreso.',
                          );
                        }
                      }
                    },
                  ),
                  const SizedBox(height: 7),
                ],
                if (owner)
                  AsyncAction(
                    secondary: true,
                    label: 'Rechazar solicitud',
                    run: () async {
                      if (await _confirm(
                        context,
                        'Rechazar solicitud',
                        'Se informará a la otra parte desde su panel.',
                      )) {
                        await store.decide(rental, false);
                      }
                    },
                  ),
              ],
            ),
          ),
        ];
      case RentalPhase.declined:
        return [
          const EmptyState(
            'Solicitud rechazada',
            'La conversación queda disponible en el historial.',
          ),
        ];
      case RentalPhase.cancelled:
        return [
          const EmptyState(
            'Acuerdo cancelado',
            'El chat y los registros previos quedan disponibles en el historial.',
          ),
        ];
      case RentalPhase.inspection:
        if (rental.terms.isEmpty) {
          return [
            _step(
              context,
              'Acordar condiciones',
              owner
                  ? 'Coordina por chat el período del alquiler y la garantía. Registra el acuerdo para abrir la inspección.'
                  : 'Coordina el período y la garantía por chat. El arrendador registrará sus condiciones.',
              owner ? 'Registrar acuerdo' : null,
              () => _open(context, AgreementForm(rental: rental, store: store)),
            ),
          ];
        }
        return [
          _inspectionStep(
            context,
            'entry',
            'Checklist de ingreso',
            'Revisa paredes, servicios y mobiliario. Adjunta una foto del estado de la habitación.',
          ),
        ];
      case RentalPhase.contract:
        return [
          _step(
            context,
            'Formalizar el alquiler',
            'Las dos partes deben leer y aceptar el contrato para continuar.',
            null,
            () {},
          ),
        ];
      case RentalPhase.deposit:
        final canRecord =
            !recorded('deposit') &&
            (!owner || rental.section('deposit').containsKey(rental.tenant));
        return [
          _step(
            context,
            'Garantía de ${soles(rental.guarantee)}',
            recorded('deposit')
                ? 'Tu confirmación está registrada. Se activará el alquiler cuando ambas partes confirmen.'
                : owner && !canRecord
                ? 'La otra parte debe registrar primero la entrega.'
                : 'Coordinen la entrega por chat. Registra aquí lo que ocurrió y adjunta el comprobante si corresponde.',
            canRecord
                ? (owner ? 'Confirmar recepción' : 'Registrar entrega')
                : null,
            () => _open(
              context,
              RecordForm(
                title: owner ? 'Confirmar recepción' : 'Registrar entrega',
                outcome: owner ? AppMotion.payment : null,
                successMessage: owner
                    ? 'Recepción de la garantía confirmada.'
                    : 'Entrega de garantía registrada.',
                detail: 'Garantía acordada: ${soles(rental.guarantee)}',
                save: (_, note, photo) =>
                    store.confirmDeposit(rental, uid, note, photo),
              ),
            ),
          ),
        ];
      case RentalPhase.active:
        return [
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SectionTitle(
                  'Gestiona tu alquiler',
                  subtitle: 'Consulta el contrato, registra pagos o coordina el check-out cuando termine el alquiler.',
                ),
                AsyncAction(
                  secondary: true,
                  label: 'Iniciar check-out',
                  run: () async {
                    if (await _confirm(
                      context,
                      'Iniciar check-out',
                      'Las dos partes completarán la inspección final.',
                    )) {
                      await store.startCheckout(rental);
                      if (context.mounted) {
                        notice(context, 'Inspección de salida iniciada.');
                      }
                    }
                  },
                ),
              ],
            ),
          ),
        ];
      case RentalPhase.checkout:
        return [
          _inspectionStep(
            context,
            'exit',
            'Checklist de salida',
            'Compara la habitación con las fotos y observaciones del ingreso.',
          ),
        ];
      case RentalPhase.settlement:
        if (rental.settlement.isEmpty) {
          return [
            _step(
              context,
              'Acordar la liquidación',
              'Coordinen el saldo, los descuentos y la devolución por chat. El arrendador registra el acuerdo.',
              owner ? 'Registrar liquidación' : null,
              () => _open(
                context,
                AgreementForm(rental: rental, store: store, settlement: true),
              ),
            ),
          ];
        }
        return [
          _step(
            context,
            'Confirmar cierre',
            recorded('close')
                ? 'Tu confirmación está registrada. Falta la confirmación de la otra parte.'
                : 'Confirma cuando se hayan completado, según corresponda, el pago final y la devolución de garantía.',
            recorded('close') ? null : 'Registrar y confirmar cierre',
            () => _open(
              context,
              RecordForm(
                title: 'Confirmar cierre',
                outcome: AppMotion.checkout,
                successMessage: 'Confirmación de cierre registrada.',
                detail:
                    'Saldo: ${soles(rental.balance)} · Devolución: ${soles(rental.refund)}',
                save: (_, note, photo) => store.close(rental, uid, note, photo),
              ),
            ),
          ),
        ];
      case RentalPhase.closed:
        return [
          RentalRatingPanel(
            key: ValueKey('${rental.id}/$uid'),
            rental: rental,
            store: store,
            uid: uid,
          ),
          const EmptyState(
            'Alquiler cerrado',
            'Ambas partes confirmaron el cierre. Aquí queda el contrato y el historial completo.',
            icon: Icons.task_alt,
          ),
        ];
    }
  }

  Widget _inspectionStep(
    BuildContext context,
    String key,
    String label,
    String help,
  ) => _step(
    context,
    label,
    recorded(key)
        ? 'Tu checklist está registrado. Falta la revisión de la otra parte.'
        : help,
    recorded(key) ? null : 'Completar checklist',
    () => _open(
      context,
      ChecklistForm(
        rental: rental,
        profile: profile,
        store: store,
        section: key,
      ),
    ),
  );

  Widget _step(
    BuildContext context,
    String title,
    String detail,
    String? action,
    VoidCallback run,
  ) => Panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle(title, subtitle: detail),
        if (action != null) FilledButton(onPressed: run, child: Text(action)),
      ],
    ),
  );

  Widget _recordSection(
    BuildContext context,
    String title,
    String section, {
    bool checklist = false,
  }) => Panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(title),
        for (final entry in rental.section(section).entries)
          EvidenceRecord(
            key: ValueKey('$section/${entry.key}'),
            title: entry.key == rental.owner
                ? rental.room.ownerName
                : rental.tenantName,
            details: fields(entry.value),
            checklist: checklist,
            store: store,
            rentalId: rental.id,
          ),
      ],
    ),
  );

  Widget _payments(BuildContext context) => Panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle(
          'Historial de pagos',
          subtitle: 'Registros de pagos realizados por fuera de GoKawsay.',
        ),
        if (rental.payments.isEmpty)
          const Text('Todavía no hay pagos registrados.'),
        for (final payment in rental.payments.entries)
          _payment(payment, context),
        if (!owner && rental.phase != RentalPhase.closed) ...[
          const SizedBox(height: 10),
          OutlinedButton.icon(
            icon: const Icon(Icons.receipt_long_outlined),
            onPressed: () => _open(
              context,
              RecordForm(
                title: 'Registrar pago',
                successMessage: 'Pago registrado. El arrendador podrá confirmar la recepción.',
                detail: 'Indica a qué mes o concepto corresponde el pago.',
                withAmount: true,
                save: (amount, note, photo) => store.recordPayment(rental, {
                  'amount': amount,
                  'note': note,
                }, photo),
              ),
            ),
            label: const Text('Registrar pago'),
          ),
        ],
      ],
    ),
  );

  Widget _payment(MapEntry<String, Object?> entry, BuildContext context) {
    final payment = fields(entry.value);
    final record = fields(payment['record']);
    final confirmed = payment.containsKey('confirmed');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        EvidenceRecord(
          key: ValueKey(entry.key),
          title:
              '${soles((record['amount'] as num).toInt())} · ${confirmed ? 'Confirmado' : 'Pendiente de confirmar'}',
          details: record,
          store: store,
          rentalId: rental.id,
        ),
        if (!confirmed && owner && rental.phase != RentalPhase.closed)
          AsyncAction(
            secondary: true,
            label: 'Confirmar recepción del pago',
            run: () async {
              if (await _confirm(
                context,
                'Confirmar pago',
                'Confirma que recibiste este pago.',
              )) {
                await store.confirmPayment(rental, entry.key);
                if (context.mounted) {
                  showOutcome(
                    context,
                    AppMotion.payment,
                    'Recepción del pago confirmada.',
                  );
                }
              }
            },
          ),
      ],
    );
  }
}

class RentalHeader extends StatelessWidget {
  const RentalHeader({super.key, required this.rental});

  final Rental rental;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final step = switch (rental.phase) {
      RentalPhase.requested => 0,
      RentalPhase.inspection ||
      RentalPhase.contract ||
      RentalPhase.deposit => 1,
      RentalPhase.active => 2,
      RentalPhase.checkout || RentalPhase.settlement || RentalPhase.closed => 3,
      RentalPhase.cancelled || RentalPhase.declined => null,
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceContainer,
        borderRadius: BorderRadius.circular(designRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.all(19),
        child: Column(
          spacing: 10,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StatusLabel(rental.phase.label, emphasis: true),
            Text(
              rental.room.title,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            Text(
              rental.room.location,
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
            if (step != null)
              Semantics(
                label: 'Etapa ${step + 1} de 4',
                child: ExcludeSemantics(
                  child: Row(
                    spacing: 6,
                    children: [
                      for (var index = 0; index < 4; index++)
                        Expanded(
                          child: Container(
                            height: 4,
                            decoration: BoxDecoration(
                              color: index <= step
                                  ? colors.primary
                                  : colors.outlineVariant,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

void _open(BuildContext context, Widget page) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

Future<bool> _confirm(
  BuildContext context,
  String title,
  String detail,
) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(detail),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    ) ??
    false;

const _checklistItems = {
  'walls': 'Paredes y acabados',
  'services': 'Servicios (agua y luz)',
  'furniture': 'Mobiliario',
};

class EvidenceRecord extends StatefulWidget {
  const EvidenceRecord({
    super.key,
    required this.title,
    required this.details,
    required this.store,
    required this.rentalId,
    this.checklist = false,
  });
  final String title;
  final Fields details;
  final RentalStore store;
  final String rentalId;
  final bool checklist;
  @override
  State<EvidenceRecord> createState() => _EvidenceRecordState();
}

class _EvidenceRecordState extends State<EvidenceRecord> {
  late final _photo = widget.store.rentalPhoto(
    widget.rentalId,
    widget.details['photo'] as String,
  );

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.title, style: Theme.of(context).textTheme.titleSmall),
        if (widget.details['at'] case final num at) Text(time(at.toInt())),
        if (widget.checklist)
          for (final item in _checklistItems.entries)
            Text(
              '${item.value}: ${widget.details[item.key] == 'ok' ? 'Conforme' : 'Con observaciones'}',
            ),
        if (widget.details['note'] case final String note when note.isNotEmpty)
          Text(note),
        if (widget.details['photo'] != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                height: 150,
                width: double.infinity,
                child: RemotePhoto(
                  photo: _photo,
                  label: 'Evidencia de ${widget.title}',
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

class ChecklistForm extends StatefulWidget {
  const ChecklistForm({
    super.key,
    required this.rental,
    required this.profile,
    required this.store,
    required this.section,
  });
  final Rental rental;
  final Profile profile;
  final RentalStore store;
  final String section;
  @override
  State<ChecklistForm> createState() => _ChecklistFormState();
}

class _ChecklistFormState extends State<ChecklistForm> {
  final _form = GlobalKey<FormState>();
  final _answers = <String, String>{};
  final _notes = TextEditingController();
  Uint8List? _photo;

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        widget.section == 'entry'
            ? 'Checklist de ingreso'
            : 'Checklist de salida',
      ),
    ),
    body: SafeArea(
      child: Form(
        key: _form,
        child: PageList(
          children: [
            for (final item in _checklistItems.entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  decoration: InputDecoration(labelText: item.value),
                  items: const [
                    DropdownMenuItem(value: 'ok', child: Text('Conforme')),
                    DropdownMenuItem(
                      value: 'observed',
                      child: Text('Con observaciones'),
                    ),
                  ],
                  onChanged: (value) => _answers[item.key] = value!,
                  validator: (value) =>
                      value == null ? 'Selecciona un estado.' : null,
                ),
              ),
            TextFormField(
              controller: _notes,
              maxLength: 350,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Observaciones'),
              validator: (value) =>
                  _answers.containsValue('observed') &&
                      (value ?? '').trim().isEmpty
                  ? 'Describe qué observaste.'
                  : null,
            ),
            EvidencePicker(
              label: 'Adjuntar foto de la inspección',
              onChange: (photo) => _photo = photo,
            ),
            const SizedBox(height: 12),
            AsyncAction(
              label: 'Guardar checklist',
              run: () async {
                if (!_form.currentState!.validate()) return;
                final photo = _photo;
                if (photo == null) {
                  notice(
                    context,
                    'Adjunta una foto para guardar el checklist.',
                  );
                  return;
                }
                await widget.store.inspect(
                  widget.rental,
                  widget.profile.uid,
                  widget.section,
                  {..._answers, 'note': _notes.text.trim()},
                  photo,
                );
                if (context.mounted) {
                  if (widget.section == 'exit') {
                    showOutcome(
                      context,
                      AppMotion.checkout,
                      'Inspección de salida guardada.',
                    );
                  } else {
                    notice(context, 'Inspección de ingreso guardada.');
                  }
                  Navigator.pop(context);
                }
              },
            ),
          ],
        ),
      ),
    ),
  );
}

class AgreementForm extends StatefulWidget {
  const AgreementForm({
    super.key,
    required this.rental,
    required this.store,
    this.settlement = false,
  });
  final Rental rental;
  final RentalStore store;
  final bool settlement;
  @override
  State<AgreementForm> createState() => _AgreementFormState();
}

class _AgreementFormState extends State<AgreementForm> {
  final _form = GlobalKey<FormState>();
  late final _mainAmount = TextEditingController(
    text: _amountText(
      widget.settlement
          ? widget.rental.settlement.isEmpty
                ? widget.rental.guarantee
                : widget.rental.refund
          : widget.rental.guarantee,
    ),
  );
  late final _balance = TextEditingController(
    text: _amountText(widget.rental.balance),
  );
  late final _note = TextEditingController(
    text:
        (widget.settlement
                ? widget.rental.settlement
                : widget.rental.terms)['note']
            as String? ??
        '',
  );
  late DateTimeRange? _period = widget.rental.terms.isEmpty
      ? null
      : DateTimeRange(
          start: _localDate(widget.rental.terms['start'] as int),
          end: _localDate(widget.rental.terms['end'] as int),
        );

  String _amountText(int amount) => (amount / 100).toStringAsFixed(2);

  DateTime _localDate(int epoch) {
    final utc = DateTime.fromMillisecondsSinceEpoch(epoch, isUtc: true);
    return DateTime(utc.year, utc.month, utc.day);
  }

  @override
  void dispose() {
    _mainAmount.dispose();
    _balance.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        widget.settlement ? 'Registrar liquidación' : 'Registrar acuerdo',
      ),
    ),
    body: SafeArea(
      child: Form(
        key: _form,
        child: PageList(
          children: [
            if (widget.settlement)
              SectionTitle(
                'Garantía entregada',
                subtitle: soles(widget.rental.guarantee),
              )
            else
              OutlinedButton.icon(
                icon: const Icon(Icons.date_range_outlined),
                label: Text(
                  _period == null
                      ? 'Seleccionar período'
                      : '${day(_date(_period!.start))} – ${day(_date(_period!.end))}',
                ),
                onPressed: () async {
                  final now = DateTime.now();
                  final selected = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(now.year - 1),
                    lastDate: DateTime(now.year + 10),
                    initialDateRange: _period,
                  );
                  if (mounted && selected != null) {
                    setState(() => _period = selected);
                  }
                },
              ),
            const SizedBox(height: 12),
            if (widget.settlement || widget.rental.room.deposit)
              AmountField(
                controller: _mainAmount,
                label: widget.settlement
                    ? 'Devolución de garantía'
                    : 'Garantía acordada',
                maximum: widget.settlement ? widget.rental.guarantee : null,
              ),
            if (widget.settlement) ...[
              const SizedBox(height: 12),
              AmountField(
                controller: _balance,
                label: 'Saldo pendiente del arrendatario',
              ),
            ],
            const SizedBox(height: 12),
            TextFormField(
              controller: _note,
              maxLength: 350,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: widget.settlement
                    ? 'Motivo del descuento u observaciones'
                    : 'Condiciones adicionales',
              ),
              validator: (value) =>
                  widget.settlement &&
                      (cents(_mainAmount.text) ?? 0) <
                          widget.rental.guarantee &&
                      (value ?? '').trim().isEmpty
                  ? 'Indica el motivo del descuento.'
                  : null,
            ),
            AsyncAction(
              label: 'Guardar acuerdo',
              run: () async {
                if (!_form.currentState!.validate()) return;
                final amount = cents(_mainAmount.text)!;
                final note = _note.text.trim();
                if (widget.settlement) {
                  await widget.store.saveSettlement(widget.rental, {
                    'refund': amount,
                    'balance': cents(_balance.text)!,
                    'note': note,
                  });
                } else {
                  final period = _period;
                  if (period == null || !period.end.isAfter(period.start)) {
                    notice(
                      context,
                      'Selecciona fechas de inicio y fin distintas.',
                    );
                    return;
                  }
                  await widget.store.saveTerms(widget.rental, {
                    'start': _date(period.start),
                    'end': _date(period.end),
                    'guarantee': amount,
                    'note': note,
                  });
                }
                if (context.mounted) Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    ),
  );

  int _date(DateTime date) =>
      DateTime.utc(date.year, date.month, date.day).millisecondsSinceEpoch;
}

class AmountField extends StatelessWidget {
  const AmountField({
    super.key,
    required this.controller,
    required this.label,
    this.maximum,
    this.positive = false,
  });
  final TextEditingController controller;
  final String label;
  final int? maximum;
  final bool positive;
  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    decoration: InputDecoration(labelText: label, prefixText: 'S/ '),
    validator: (value) {
      final amount = cents(value ?? '');
      if (amount == null || (positive && amount == 0)) {
        return 'Ingresa un monto válido.';
      }
      if (maximum case final limit? when amount > limit) {
        return 'El máximo es ${soles(limit)}.';
      }
      return null;
    },
  );
}

class RecordForm extends StatefulWidget {
  const RecordForm({
    super.key,
    required this.title,
    required this.detail,
    required this.save,
    this.withAmount = false,
    this.outcome,
    this.successMessage = 'Registro guardado.',
  });
  final String title;
  final String detail;
  final Future<void> Function(int?, String, Uint8List?) save;
  final bool withAmount;
  final AppMotion? outcome;
  final String successMessage;
  @override
  State<RecordForm> createState() => _RecordFormState();
}

class _RecordFormState extends State<RecordForm> {
  final _form = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _note = TextEditingController();
  Uint8List? _photo;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.title)),
    body: SafeArea(
      child: Form(
        key: _form,
        child: PageList(
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(widget.detail),
            ),
            if (widget.withAmount) ...[
              AmountField(controller: _amount, label: 'Monto', positive: true),
              const SizedBox(height: 12),
            ],
            TextFormField(
              controller: _note,
              maxLength: 350,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: widget.withAmount
                    ? 'Concepto'
                    : 'Observaciones (opcional)',
              ),
              validator: (value) =>
                  widget.withAmount && (value ?? '').trim().isEmpty
                  ? 'Indica el concepto.'
                  : null,
            ),
            EvidencePicker(
              label: 'Adjuntar comprobante (opcional)',
              onChange: (photo) => _photo = photo,
            ),
            const SizedBox(height: 12),
            AsyncAction(
              label: 'Confirmar registro',
              run: () async {
                if (!_form.currentState!.validate()) return;
                await widget.save(
                  cents(_amount.text),
                  _note.text.trim(),
                  _photo,
                );
                if (context.mounted) {
                  if (widget.outcome case final outcome?) {
                    showOutcome(context, outcome, widget.successMessage);
                  } else {
                    notice(context, widget.successMessage);
                  }
                  Navigator.pop(context);
                }
              },
            ),
          ],
        ),
      ),
    ),
  );
}

class ContractPage extends StatelessWidget {
  const ContractPage({super.key, required this.rental});
  final Rental rental;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Contrato generado')),
    body: SafeArea(
      child: PageList(
        children: [
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionTitle('Acuerdo de alquiler'),
                SelectableText(
                  [
                    'Arrendador: ${rental.room.ownerName}',
                    'Arrendatario: ${rental.tenantName}',
                    '',
                    'Habitación: ${rental.room.title}, ${rental.room.location}.',
                    'Período: del ${day((rental.terms['start'] as num).toInt())} al ${day((rental.terms['end'] as num).toInt())}.',
                    'Renta: ${soles(rental.room.monthly)} mensuales.',
                    'Garantía acordada: ${soles(rental.guarantee)}.',
                    '',
                    'Las partes registran el estado de la habitación al ingreso y al finalizar el alquiler. Los pagos se coordinan directamente entre las partes. Al finalizar, las partes revisan el estado de la habitación y acuerdan los saldos y la devolución de la garantía.',
                    if ((rental.terms['note'] as String).isNotEmpty) ...[
                      '',
                      'Condiciones adicionales: ${rental.terms['note']}.',
                    ],
                  ].join('\n'),
                ),
                const SectionTitle('Aceptación de las partes'),
                _acceptance(rental.room.ownerName, rental.owner),
                _acceptance(rental.tenantName, rental.tenant),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _acceptance(String name, String user) {
    final accepted = rental.section('contract')[user] as num?;
    return Text(
      '$name · ${accepted == null ? 'Pendiente' : 'Aceptado el ${time(accepted.toInt())}'}',
    );
  }
}

class ChatPage extends StatefulWidget {
  const ChatPage({
    super.key,
    required this.rental,
    required this.store,
    required this.profile,
  });
  final Rental rental;
  final RentalStore store;
  final Profile profile;
  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  late final _messages = widget.store.messages(widget.rental.id);
  final _message = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _message.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await widget.store.send(widget.rental, widget.profile, text);
      if (mounted && _message.text.trim() == text) _message.clear();
    } catch (error) {
      if (mounted) notice(context, friendlyError(error));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.rental.counterpart(widget.profile.uid),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Text(
            widget.rental.room.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    ),
    body: SafeArea(
      child: Column(
        children: [
          Expanded(
            child: DataView(
              stream: _messages,
              loadingLabel: 'Cargando conversación…',
              buildData: (messages) => messages.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Escribe un mensaje para coordinar la visita o el alquiler.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : ListView.builder(
                      reverse: true,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final message = messages[messages.length - 1 - index];
                        return _bubble(context, message);
                      },
                    ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: _message,
                    minLines: 1,
                    maxLines: 4,
                    maxLength: 1000,
                    decoration: const InputDecoration(
                      labelText: 'Mensaje',
                      counterText: '',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  tooltip: _sending ? 'Enviando mensaje…' : 'Enviar mensaje',
                  onPressed: _sending ? null : _send,
                  icon: _sending
                      ? const MotionArtwork(AppMotion.internal, size: 24)
                      : const Icon(Icons.send_outlined),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _bubble(BuildContext context, ChatMessage message) {
    final mine = message.sender == widget.profile.uid;
    final colors = Theme.of(context).colorScheme;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        margin: EdgeInsets.only(
          top: 7,
          left: mine ? 36 : 0,
          right: mine ? 0 : 36,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: mine
              ? colors.primaryContainer
              : colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.text,
              style: TextStyle(
                color: mine ? colors.onPrimaryContainer : colors.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              time(message.sent),
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
      ),
    );
  }
}
