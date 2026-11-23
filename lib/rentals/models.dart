import '../locations/cusco.dart';
import '../locations/precise_location.dart';

typedef Fields = Map<String, Object?>;

Fields fields(Object? value) => value is Map
    ? value.map((key, value) => MapEntry(key.toString(), value))
    : const {};

enum RentalPhase {
  requested('Solicitud pendiente'),
  declined('Solicitud rechazada'),
  cancelled('Acuerdo cancelado'),
  inspection('Acuerdo e ingreso'),
  contract('Contrato'),
  deposit('Entrega de garantía'),
  active('Alquiler activo'),
  checkout('Inspección de salida'),
  settlement('Liquidación'),
  closed('Alquiler cerrado');

  const RentalPhase(this.label);
  final String label;
}

enum ProfileRole {
  landlord('Arrendador', 'Quiero publicar habitaciones'),
  tenant('Arrendatario', 'Quiero buscar una habitación');

  const ProfileRole(this.label, this.description);
  final String label;
  final String description;
}

class Profile {
  const Profile(this.uid, this.data);

  final String uid;
  final Fields data;

  String get name => data['name'] as String;
  String get bio => data['bio'] as String? ?? '';
  ProfileRole? get role =>
      ProfileRole.values.where((role) => role.name == data['role']).firstOrNull;
}

class Room {
  const Room(this.id, this.data);

  final String id;
  final Fields data;

  String get owner => data['owner'] as String;
  String get ownerName => data['ownerName'] as String;
  String get title => data['title'] as String;
  String get location => data['location'] as String;
  String get description => data['description'] as String;
  int get monthly => (data['monthly'] as num).toInt();
  bool get deposit => data['deposit'] == true;
  bool get available => data['available'] == true;
  bool get archived => data['archived'] == true;
  bool get visible => available && !archived;
  bool get photo => data['photo'] == true;
  String? get photoRevision => data['photoRevision'] as String?;
  bool get example => data['example'] == true;
  String get neighborhood => data['neighborhood'] as String? ?? '';
  PreciseLocation? get preciseLocation =>
      PreciseLocation.fromData(data['coordinates']);
  CuscoDistrict? get district =>
      cuscoDistrictsByCode[data['ubigeo']] ??
      districtForLegacyLocation(location);

  bool matches(
    String query, {
    CuscoZone? zone,
    String? province,
    String? districtCode,
  }) {
    final place = district;
    if (zone != null && place?.zone != zone) return false;
    if (province != null && place?.provinceCode != province) return false;
    if (districtCode != null && place?.code != districtCode) return false;
    if (query.isEmpty) return true;
    return normalizePlace(
      '$title $location $neighborhood ${place?.label ?? ''} '
      '${place?.province ?? ''} ${place?.zone?.label ?? ''}',
    ).contains(query);
  }
}

class Rental {
  const Rental(this.id, this.data);

  final String id;
  final Fields data;

  Room get room => Room(data['roomId'] as String, fields(data['room']));
  String get tenant => data['tenant'] as String;
  String get owner => data['owner'] as String;
  String get tenantName => data['tenantName'] as String;
  String get decision => data['decision'] as String? ?? '';
  int get created => (data['created'] as num).toInt();
  Fields get terms => fields(data['terms']);
  int get guarantee => (terms['guarantee'] as num?)?.toInt() ?? 0;
  Fields get settlement => fields(data['settlement']);
  int get refund => (settlement['refund'] as num?)?.toInt() ?? 0;
  int get balance => (settlement['balance'] as num?)?.toInt() ?? 0;
  Fields get payments => fields(data['payments']);

  bool isOwner(String uid) => uid == owner;
  String counterpart(String uid) => isOwner(uid) ? tenantName : room.ownerName;
  Fields section(String key) => fields(data[key]);
  bool both(String key) =>
      section(key).containsKey(owner) && section(key).containsKey(tenant);

  RentalPhase get phase {
    if (decision == 'declined') return RentalPhase.declined;
    if (data['cancelled'] == true) return RentalPhase.cancelled;
    if (decision != 'selected') return RentalPhase.requested;
    if (terms.isEmpty || !both('entry')) return RentalPhase.inspection;
    if (!both('contract')) return RentalPhase.contract;
    if (guarantee > 0 && !both('deposit')) return RentalPhase.deposit;
    if (data['checkoutStarted'] != true) return RentalPhase.active;
    if (!both('exit')) return RentalPhase.checkout;
    if (!both('close')) return RentalPhase.settlement;
    return RentalPhase.closed;
  }
}

class ChatMessage {
  const ChatMessage(this.data);

  final Fields data;

  String get sender => data['sender'] as String;
  String get text => data['text'] as String;
  int get sent => (data['sent'] as num).toInt();
}
