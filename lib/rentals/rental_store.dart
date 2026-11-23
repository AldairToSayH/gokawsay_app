import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_database/firebase_database.dart';

import 'models.dart';

class RentalStore {
  RentalStore(this.database);

  final FirebaseDatabase database;

  DatabaseReference get _root => database.ref();
  DatabaseReference _case(String id) => _root.child('rentals/$id');

  Stream<Fields> _watch(Query ref) =>
      ref.onValue.map((event) => fields(event.snapshot.value));

  Stream<Profile?> profile(String uid) =>
      _watch(_root.child('profiles/$uid'))
          .map((data) => data.isEmpty ? null : Profile(uid, data));

  Future<void> saveProfile(
    String uid,
    String name,
    String bio,
    ProfileRole role,
  ) => _root.child('profiles/$uid').set({
    'name': name,
    'bio': bio,
    'role': role.name,
  });

  Stream<List<Room>> rooms() => _watch(_root.child('rooms')).map(
    (data) =>
        [for (final item in data.entries) Room(item.key, fields(item.value))]
            .reversed
            .toList(),
  );

  Stream<Room?> room(String id) =>
      _watch(_root.child('rooms/$id'))
          .map((data) => data.isEmpty ? null : Room(id, data));

  Stream<List<Rental>> rentals(String uid, {required bool asOwner}) =>
      _watch(
        _root
            .child('rentals')
            .orderByChild(asOwner ? 'owner' : 'tenant')
            .equalTo(uid),
      ).map((data) {
        final result = [
          for (final item in data.entries) Rental(item.key, fields(item.value)),
        ];
        return result..sort((a, b) => b.created.compareTo(a.created));
      });

  Stream<Rental?> rental(String id) =>
      _watch(_case(id)).map((data) => data.isEmpty ? null : Rental(id, data));

  Stream<RatingSummary> ratingSummary(String uid) =>
      _watch(_root.child('ratings/$uid')).map(RatingSummary.fromData);

  Stream<int?> rentalRating(String uid, String rentalId) =>
      _watch(_root.child('ratings/$uid/$rentalId'))
          .map((data) => (data['score'] as num?)?.toInt());

  Future<void> rateRental(Rental rental, String uid, int score) async {
    if (rental.phase != RentalPhase.closed ||
        (uid != rental.owner && uid != rental.tenant)) {
      throw StateError('El alquiler debe estar cerrado por ambas partes.');
    }
    RangeError.checkValueInInterval(score, 1, 5, 'score');
    final target = rental.counterpartUid(uid);
    await _root
        .child('ratings/$target/${rental.id}')
        .runTransaction(
          (current) => current == null
              ? Transaction.success({
                  'score': score,
                  'at': ServerValue.timestamp,
                })
              : Transaction.abort(),
          applyLocally: false,
        );
  }

  Stream<List<ChatMessage>> messages(String id) =>
      _watch(_root.child('messages/$id').orderByChild('sent').limitToLast(200))
          .map((data) {
            final result = [
              for (final entry in data.values) ChatMessage(fields(entry)),
            ];
            return result..sort((a, b) => a.sent.compareTo(b.sent));
          });

  Future<void> publish(Profile profile, Fields details, Uint8List? photo) {
    final id = _root.child('rooms').push().key!;
    return _root.update({
      'rooms/$id': {
        ...details,
        'owner': profile.uid,
        'ownerName': profile.name,
        'available': true,
        'photo': photo != null,
      },
      if (photo != null) 'roomPhotos/$id': base64Encode(photo),
    });
  }

  Future<void> setAvailability(Room room, bool available) =>
      _root.child('rooms/${room.id}/available').set(available);

  Future<void> updateRoom(
    Room room,
    Fields details, {
    Uint8List? photo,
    bool removePhoto = false,
  }) {
    final changePhoto = photo != null || removePhoto;
    final path = 'rooms/${room.id}';
    return _root.update({
      for (final entry in details.entries) '$path/${entry.key}': entry.value,
      if (changePhoto) ...{
        '$path/photo': photo != null,
        '$path/photoRevision': photo == null ? null : _root.push().key!,
        'roomPhotos/${room.id}': photo == null ? null : base64Encode(photo),
      },
    });
  }

  Future<void> archiveRoom(Room room) => _root.update({
    'rooms/${room.id}/available': false,
    'rooms/${room.id}/archived': true,
    'rooms/${room.id}/photo': false,
    'rooms/${room.id}/photoRevision': null,
    'roomPhotos/${room.id}': null,
  });

  String requestId(Room room, Profile profile) => '${room.id}_${profile.uid}';

  Future<void> request(Room room, Profile profile) =>
      _case(requestId(room, profile)).set({
        'roomId': room.id,
        'room': room.data,
        'owner': room.owner,
        'tenant': profile.uid,
        'tenantName': profile.name,
        'created': ServerValue.timestamp,
      });

  Future<void> send(Rental rental, Profile profile, String text) =>
      _root.child('messages/${rental.id}').push().set({
        'sender': profile.uid,
        'text': text,
        'sent': ServerValue.timestamp,
      });

  Future<void> decide(Rental rental, bool selected) => selected
      ? _root.update({
          'rentals/${rental.id}/decision': 'selected',
          'roomSelections/${rental.room.id}': rental.id,
        })
      : _case(rental.id).child('decision').set('declined');

  Future<void> cancel(Rental rental) =>
      _case(rental.id).child('cancelled').set(true);

  Future<void> saveTerms(Rental rental, Fields terms) =>
      _case(rental.id).child('terms').set(terms);

  Future<void> acceptContract(Rental rental, String uid) =>
      _case(rental.id).child('contract/$uid').set(ServerValue.timestamp);

  Future<void> inspect(
    Rental rental,
    String uid,
    String section,
    Fields checklist,
    Uint8List photo,
  ) => _writeWithPhoto(rental, '$section/$uid', checklist, photo);

  Future<void> confirmDeposit(
    Rental rental,
    String uid,
    String note,
    Uint8List? photo,
  ) => _writeWithPhoto(rental, 'deposit/$uid', {'note': note}, photo);

  Future<void> startCheckout(Rental rental) =>
      _case(rental.id).child('checkoutStarted').set(true);

  Future<void> saveSettlement(Rental rental, Fields settlement) =>
      _case(rental.id).child('settlement').set(settlement);

  Future<void> close(
    Rental rental,
    String uid,
    String note,
    Uint8List? photo,
  ) => _writeWithPhoto(rental, 'close/$uid', {'note': note}, photo);

  Future<void> recordPayment(Rental rental, Fields payment, Uint8List? photo) {
    final id = _case(rental.id).child('payments').push().key!;
    return _writeWithPhoto(rental, 'payments/$id/record', payment, photo);
  }

  Future<void> confirmPayment(Rental rental, String paymentId) =>
      _case(rental.id)
          .child('payments/$paymentId/confirmed')
          .set(ServerValue.timestamp);

  Future<void> _writeWithPhoto(
    Rental rental,
    String path,
    Fields details,
    Uint8List? photo,
  ) {
    final media = _root.child('rentalPhotos/${rental.id}').push().key!;
    return _root.update({
      'rentals/${rental.id}/$path': {
        ...details,
        'at': ServerValue.timestamp,
        if (photo != null) 'photo': media,
      },
      if (photo != null)
        'rentalPhotos/${rental.id}/$media': base64Encode(photo),
    });
  }

  Future<Uint8List?> roomPhoto(String id) => _photo('roomPhotos/$id');
  Future<Uint8List?> rentalPhoto(String id, String key) =>
      _photo('rentalPhotos/$id/$key');

  Future<Uint8List?> _photo(String path) async {
    final value = (await _root.child(path).get()).value;
    return value is String ? base64Decode(value) : null;
  }
}
