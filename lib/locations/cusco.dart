// UBIGEO INEI. Cobertura contrastada con el Gobierno Regional del Cusco.
// https://www.inei.gob.pe/media/MenuRecursivo/publicaciones_digitales/Est/CompDptal2025/Cusco2025.pdf
// https://transparencia.regioncusco.gob.pe/transparencia/ProyectosInversion/Proyectos_Inversion/DB_GRC_PMI_2026_2028.pdf

enum CuscoZone {
  city('Ciudad de Cusco'),
  valley('Valle Sagrado');

  const CuscoZone(this.label);
  final String label;
}

class CuscoDistrict {
  const CuscoDistrict(this.code, this.name, [this.town]);

  final String code;
  final String name;
  final String? town;

  String get provinceCode => code.substring(0, 4);
  String get province => cuscoProvinces[provinceCode]!;
  String get label => town == null ? name : '$name · $town';

  CuscoZone? get zone {
    if (_cityDistricts.contains(code)) return CuscoZone.city;
    if (_valleyDistricts.contains(code)) return CuscoZone.valley;
    return null;
  }

  String location(String neighborhood) => {
    if (neighborhood.isNotEmpty) neighborhood,
    name,
    province,
    'Cusco',
  }.join(', ');
}

const _cityDistricts = {'080101', '080104', '080105', '080106', '080108'};

// Destinos del corredor turístico del Valle Sagrado y distritos cercanos.
// https://consultasenlinea.mincetur.gob.pe/safeTravels/destinos/DESTINOS_CUSCO_22DIc.pdf
const _valleyDistricts = {
  '080401',
  '080402',
  '080403',
  '080405',
  '080406',
  '080407',
  '081301',
  '081302',
  '081303',
  '081305',
  '081306',
  '081307',
};

String normalizePlace(String value) {
  const accents = {'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u', 'ü': 'u'};
  return value.trim().toLowerCase().replaceAllMapped(
    RegExp('[áéíóúü]'),
    (match) => accents[match[0]]!,
  );
}

final cuscoDistrictsByCode = Map.unmodifiable({
  for (final district in cuscoDistricts) district.code: district,
});

CuscoDistrict? districtForLegacyLocation(String location) {
  final parts = normalizePlace(location)
      .split(RegExp(r'[,·/]+'))
      .map((part) => part.trim())
      .toSet();
  if (parts.contains('san blas') ||
      parts.length == 1 && parts.contains('cusco')) {
    return cuscoDistrictsByCode['080101'];
  }
  if (parts.contains('aguas calientes') || parts.contains('machu picchu')) {
    return cuscoDistrictsByCode['081304'];
  }

  final matches = cuscoDistricts
      .where(
        (district) =>
            district.code != '080101' &&
            (parts.contains(normalizePlace(district.name)) ||
                district.town != null &&
                    parts.contains(normalizePlace(district.town!))),
      )
      .toList();
  if (matches.length == 1) return matches.single;
  if (matches.isNotEmpty) {
    final distinctDistrict = matches
        .where(
          (district) =>
              parts.contains(normalizePlace(district.province)) &&
              normalizePlace(district.name) !=
                  normalizePlace(district.province),
        )
        .toList();
    if (distinctDistrict.length == 1) return distinctDistrict.single;
  }
  return null;
}

const cuscoProvinces = {
  '0801': 'Cusco',
  '0813': 'Urubamba',
  '0804': 'Calca',
  '0802': 'Acomayo',
  '0803': 'Anta',
  '0805': 'Canas',
  '0806': 'Canchis',
  '0807': 'Chumbivilcas',
  '0808': 'Espinar',
  '0809': 'La Convención',
  '0810': 'Paruro',
  '0811': 'Paucartambo',
  '0812': 'Quispicanchi',
};

const cuscoDistricts = [
  CuscoDistrict('080101', 'Cusco'),
  CuscoDistrict('080102', 'Ccorca'),
  CuscoDistrict('080103', 'Poroy'),
  CuscoDistrict('080104', 'San Jerónimo'),
  CuscoDistrict('080105', 'San Sebastián'),
  CuscoDistrict('080106', 'Santiago'),
  CuscoDistrict('080107', 'Saylla'),
  CuscoDistrict('080108', 'Wánchaq'),
  CuscoDistrict('080201', 'Acomayo'),
  CuscoDistrict('080202', 'Acopia'),
  CuscoDistrict('080203', 'Acos'),
  CuscoDistrict('080204', 'Mosoc Llacta'),
  CuscoDistrict('080205', 'Pomacanchi'),
  CuscoDistrict('080206', 'Rondocán'),
  CuscoDistrict('080207', 'Sangarara'),
  CuscoDistrict('080301', 'Anta'),
  CuscoDistrict('080302', 'Ancahuasi'),
  CuscoDistrict('080303', 'Cachimayo'),
  CuscoDistrict('080304', 'Chinchaypujio'),
  CuscoDistrict('080305', 'Huarocondo'),
  CuscoDistrict('080306', 'Limatambo'),
  CuscoDistrict('080307', 'Mollepata'),
  CuscoDistrict('080308', 'Pucyura'),
  CuscoDistrict('080309', 'Zurite'),
  CuscoDistrict('080401', 'Calca'),
  CuscoDistrict('080402', 'Coya'),
  CuscoDistrict('080403', 'Lamay'),
  CuscoDistrict('080404', 'Lares'),
  CuscoDistrict('080405', 'Písac'),
  CuscoDistrict('080406', 'San Salvador'),
  CuscoDistrict('080407', 'Taray'),
  CuscoDistrict('080408', 'Yanatile', 'Quebrada Honda'),
  CuscoDistrict('080501', 'Yanaoca'),
  CuscoDistrict('080502', 'Checca'),
  CuscoDistrict('080503', 'Kunturkanki', 'El Descanso'),
  CuscoDistrict('080504', 'Langui'),
  CuscoDistrict('080505', 'Layo'),
  CuscoDistrict('080506', 'Pampamarca'),
  CuscoDistrict('080507', 'Quehue'),
  CuscoDistrict('080508', 'Túpac Amaru', 'Tungasuca'),
  CuscoDistrict('080601', 'Sicuani'),
  CuscoDistrict('080602', 'Checacupe'),
  CuscoDistrict('080603', 'Combapata'),
  CuscoDistrict('080604', 'Marangani'),
  CuscoDistrict('080605', 'Pitumarca'),
  CuscoDistrict('080606', 'San Pablo'),
  CuscoDistrict('080607', 'San Pedro'),
  CuscoDistrict('080608', 'Tinta'),
  CuscoDistrict('080701', 'Santo Tomás'),
  CuscoDistrict('080702', 'Capacmarca'),
  CuscoDistrict('080703', 'Chamaca'),
  CuscoDistrict('080704', 'Colquemarca'),
  CuscoDistrict('080705', 'Livitaca'),
  CuscoDistrict('080706', 'Llusco'),
  CuscoDistrict('080707', 'Quiñota'),
  CuscoDistrict('080708', 'Velille'),
  CuscoDistrict('080801', 'Espinar', 'Yauri'),
  CuscoDistrict('080802', 'Condoroma'),
  CuscoDistrict('080803', 'Coporaque'),
  CuscoDistrict('080804', 'Ocoruro'),
  CuscoDistrict('080805', 'Pallpata', 'Hector Tejada'),
  CuscoDistrict('080806', 'Pichigua'),
  CuscoDistrict('080807', 'Suyckutambo'),
  CuscoDistrict('080808', 'Alto Pichigua', 'Accocunca'),
  CuscoDistrict('080901', 'Santa Ana', 'Quillabamba'),
  CuscoDistrict('080902', 'Echarate'),
  CuscoDistrict('080903', 'Huayopata', 'Ipal'),
  CuscoDistrict('080904', 'Maranura'),
  CuscoDistrict('080905', 'Ocobamba'),
  CuscoDistrict('080906', 'Quellouno'),
  CuscoDistrict('080907', 'Kimbiri'),
  CuscoDistrict('080908', 'Santa Teresa'),
  CuscoDistrict('080909', 'Vilcabamba', 'Lucma'),
  CuscoDistrict('080910', 'Pichari'),
  CuscoDistrict('080911', 'Inkawasi', 'Amaybamba'),
  CuscoDistrict('080912', 'Villa Virgen'),
  CuscoDistrict('080913', 'Villa Kintiarina'),
  CuscoDistrict('080914', 'Megantoni', 'Camisea'),
  CuscoDistrict('080915', 'Kumpirushiato', 'Kepashiato'),
  CuscoDistrict('080916', 'Cielo Punco', 'Chirumpiari'),
  CuscoDistrict('080917', 'Manitea', 'Tawantinsuyo'),
  CuscoDistrict('080918', 'Unión Ashaninka', 'Mantaro'),
  CuscoDistrict('081001', 'Paruro'),
  CuscoDistrict('081002', 'Accha'),
  CuscoDistrict('081003', 'Ccapi'),
  CuscoDistrict('081004', 'Colcha'),
  CuscoDistrict('081005', 'Huanoquite'),
  CuscoDistrict('081006', 'Omacha'),
  CuscoDistrict('081007', 'Paccaritambo'),
  CuscoDistrict('081008', 'Pillpinto'),
  CuscoDistrict('081009', 'Yaurisque'),
  CuscoDistrict('081101', 'Paucartambo'),
  CuscoDistrict('081102', 'Caicay'),
  CuscoDistrict('081103', 'Challabamba'),
  CuscoDistrict('081104', 'Colquepata'),
  CuscoDistrict('081105', 'Huancarani'),
  CuscoDistrict('081106', 'Kosñipata', 'Pillcopata'),
  CuscoDistrict('081201', 'Urcos'),
  CuscoDistrict('081202', 'Andahuaylillas'),
  CuscoDistrict('081203', 'Camanti', 'Quince Mil'),
  CuscoDistrict('081204', 'Ccarhuayo'),
  CuscoDistrict('081205', 'Ccatca'),
  CuscoDistrict('081206', 'Cusipata'),
  CuscoDistrict('081207', 'Huaro'),
  CuscoDistrict('081208', 'Lucre'),
  CuscoDistrict('081209', 'Marcapata'),
  CuscoDistrict('081210', 'Ocongate'),
  CuscoDistrict('081211', 'Oropesa'),
  CuscoDistrict('081212', 'Quiquijana'),
  CuscoDistrict('081301', 'Urubamba'),
  CuscoDistrict('081302', 'Chinchero'),
  CuscoDistrict('081303', 'Huayllabamba'),
  CuscoDistrict('081304', 'Machupicchu', 'Aguas Calientes'),
  CuscoDistrict('081305', 'Maras'),
  CuscoDistrict('081306', 'Ollantaytambo'),
  CuscoDistrict('081307', 'Yucay'),
];
