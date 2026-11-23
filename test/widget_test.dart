import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gokawsay/rentals/models.dart';
import 'package:gokawsay/rentals/rental_store.dart';
import 'package:gokawsay/ui/app.dart';
import 'package:gokawsay/ui/rental_page.dart';
import 'package:gokawsay/ui/ratings.dart';
import 'package:material_ui/material_ui.dart';

class UnusedDatabase implements FirebaseDatabase {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class RecordingProfileStore extends RentalStore {
  RecordingProfileStore() : super(UnusedDatabase());

  ProfileRole? savedRole;

  @override
  Stream<RatingSummary> ratingSummary(String uid) =>
      Stream.value(const RatingSummary());

  @override
  Future<void> saveProfile(
    String uid,
    String name,
    String bio,
    ProfileRole role,
  ) async {
    savedRole = role;
  }
}

class RecordingRatingStore extends RecordingProfileStore {
  RecordingRatingStore() {
    _rating.add(null);
  }

  final _rating = StreamController<int?>();
  int submissions = 0;
  int? submittedScore;
  String? submittedUid;

  @override
  Stream<int?> rentalRating(String uid, String rentalId) => _rating.stream;

  @override
  Future<void> rateRental(Rental rental, String uid, int score) async {
    submissions++;
    submittedScore = score;
    submittedUid = uid;
    _rating.add(score);
  }

  Future<void> dispose() => _rating.close();
}

const room = {
  'owner': 'mateo',
  'ownerName': 'Mateo',
  'title': 'Habitación en San Blas',
  'location': 'Cusco',
  'description': 'Entrada independiente',
  'monthly': 52000,
  'deposit': true,
};
const header = {
  'roomId': 'room',
  'owner': 'mateo',
  'tenant': 'lucia',
  'tenantName': 'Lucía',
  'room': room,
  'created': 1,
};
const terms = {
  'start': 1794873600000,
  'end': 1797465600000,
  'guarantee': 50000,
  'note': '',
};
const approved = {'mateo': 1000, 'lucia': 1000};

void main() {
  testWidgets('Profile setup requires and saves the selected role', (
    tester,
  ) async {
    final store = RecordingProfileStore();
    await tester.pumpWidget(
      MaterialApp(
        home: ProfileEditor(
          store: store,
          uid: 'mateo',
          name: 'Mateo',
          initial: true,
        ),
      ),
    );
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    expect(find.text('Selecciona un rol.'), findsOneWidget);
    expect(store.savedRole, isNull);
    await tester.tap(find.text('Arrendador'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widgetList<RoleChoice>(find.byType(RoleChoice))
          .singleWhere((choice) => choice.selected)
          .role,
      ProfileRole.landlord,
    );
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    expect(store.savedRole, ProfileRole.landlord);
  });
  testWidgets('The manual selection is offered only to the landlord', (
    tester,
  ) async {
    final store = RecordingProfileStore();
    Widget screen(String uid) => MaterialApp(
      home: Scaffold(
        body: RentalDetails(
          rental: const Rental('room_lucia', header),
          store: store,
          profile: Profile(uid, const {'name': 'Nombre'}),
        ),
      ),
    );
    await tester.pumpWidget(screen('mateo'));
    expect(find.text('Elegir esta solicitud'), findsOneWidget);
    expect(find.text('Conversar con Lucía'), findsOneWidget);
    await tester.pumpWidget(screen('lucia'));
    expect(find.text('Elegir esta solicitud'), findsNothing);
    expect(find.text('Conversar con Mateo'), findsOneWidget);
  });

  test('The second acceptance is required to close the rental', () {
    final data = <String, Object?>{
      ...header,
      'decision': 'selected',
      'terms': terms,
      'entry': approved,
      'contract': approved,
      'deposit': approved,
      'checkoutStarted': true,
      'exit': approved,
      'settlement': {'refund': 45000, 'balance': 3000, 'note': ''},
      'close': {
        'mateo': {'at': 1, 'note': ''},
      },
    };
    expect(Rental('room_lucia', data).phase, RentalPhase.settlement);
    data['close'] = {
      'mateo': {'at': 1, 'note': ''},
      'lucia': {'at': 2, 'note': ''},
    };
    expect(Rental('room_lucia', data).phase, RentalPhase.closed);
  });

  test('Ratings average verified scores and handle a new account', () {
    final summary = RatingSummary.fromData({
      'first': {'score': 5},
      'second': {'score': 4},
    });
    expect(summary.count, 2);
    expect(summary.average, 4.5);
    expect(RatingSummary.fromData({}).count, 0);
    expect(RatingSummary.fromData({}).average, 0);
  });

  for (final uid in ['mateo', 'lucia']) {
    testWidgets('A closed rental accepts and shows a single rating from $uid', (
      tester,
    ) async {
      final store = RecordingRatingStore();
      addTearDown(store.dispose);
      const rental = Rental('room_lucia', {
        ...header,
        'decision': 'selected',
        'terms': terms,
        'entry': approved,
        'contract': approved,
        'deposit': approved,
        'checkoutStarted': true,
        'exit': approved,
        'close': approved,
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(
              children: [
                RentalRatingPanel(rental: rental, store: store, uid: uid),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Enviar calificación'),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.byKey(const ValueKey('rating-star-5')));
      await tester.pump();
      await tester.tap(find.text('Enviar calificación'));
      await tester.pumpAndSettle();
      expect(store.submissions, 1);
      expect(store.submittedScore, 5);
      expect(store.submittedUid, uid);
      expect(find.text('Tu calificación fue enviada'), findsOneWidget);
      expect(find.text('Enviar calificación'), findsNothing);
      expect(
        tester
            .widget<IconButton>(find.byKey(const ValueKey('rating-star-1')))
            .onPressed,
        isNull,
      );
    });
  }

  testWidgets('The contract shows agreed amounts and both names', (
    tester,
  ) async {
    const rental = Rental('room_lucia', {
      ...header,
      'terms': terms,
      'contract': approved,
    });
    await tester.pumpWidget(
      const MaterialApp(home: ContractPage(rental: rental)),
    );
    expect(find.textContaining('Garantía acordada: S/ 500'), findsOneWidget);
    expect(find.textContaining('Arrendador: Mateo'), findsOneWidget);
    expect(find.textContaining('Arrendatario: Lucía'), findsOneWidget);
    expect(find.textContaining('Aceptado el'), findsNWidgets(2));
  });
}
