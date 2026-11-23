import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gokawsay/rentals/models.dart';
import 'package:gokawsay/rentals/rental_store.dart';
import 'package:gokawsay/ui/app.dart';
import 'package:gokawsay/ui/rental_page.dart';
import 'package:material_ui/material_ui.dart';

class UnusedDatabase implements FirebaseDatabase {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class RecordingProfileStore extends RentalStore {
  RecordingProfileStore() : super(UnusedDatabase());

  ProfileRole? savedRole;

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
    final store = RentalStore(UnusedDatabase());
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
