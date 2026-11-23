import 'package:material_ui/material_ui.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'components.dart';
import 'external_links.dart';
import 'motion.dart';

final _package = PackageInfo.fromPlatform();
final _googlePrivacy = Uri.https('policies.google.com', '/privacy', {
  'hl': 'es',
});
final _dataRights = Uri.https('www.gob.pe', '/9270-que-son-los-derechos-arco');

class ProfileInformation extends StatelessWidget {
  const ProfileInformation({super.key});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SectionTitle('Información y permisos'),
      Panel(
        child: Column(
          children: [
            _entry(
              context,
              Icons.description_outlined,
              'Términos y condiciones',
              const _TermsPage(),
            ),
            const Divider(height: 1),
            _entry(
              context,
              Icons.privacy_tip_outlined,
              'Privacidad y permisos',
              const _PrivacyPage(),
            ),
            const Divider(height: 1),
            _entry(
              context,
              Icons.info_outline_rounded,
              'Acerca de GoKawsay',
              const _AboutPage(),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _entry(
    BuildContext context,
    IconData icon,
    String label,
    Widget page,
  ) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(icon),
    title: Text(label),
    trailing: const Icon(Icons.chevron_right),
    onTap: () =>
        Navigator.of(context)
            .push(MaterialPageRoute<void>(builder: (_) => page)),
  );
}

class _TermsPage extends StatelessWidget {
  const _TermsPage();

  @override
  Widget build(BuildContext context) => _InformationPage(
    title: 'Términos y condiciones',
    children: [
      const SectionTitle(
        'Uso de GoKawsay',
        subtitle: 'GoKawsay facilita la publicación de habitaciones y la coordinación de alquileres en Cusco, Perú. El arrendador decide con qué solicitud avanzar.',
      ),
      const SectionTitle(
        'Publicaciones y acuerdos',
        subtitle: 'Publica habitaciones que puedas ofrecer, con información y fotos que tengas autorización para compartir. Antes de aceptar un acuerdo, revisa las condiciones, el precio, la ubicación y la garantía.',
      ),
      const SectionTitle(
        'Pagos y comprobantes',
        subtitle: 'Las partes acuerdan y realizan los pagos y las devoluciones directamente. GoKawsay registra la información y las confirmaciones que cada parte ingresa.',
      ),
      const SectionTitle(
        'Chat y evidencias',
        subtitle: 'Usa el chat para coordinar el alquiler. Adjunta únicamente las fotos y los comprobantes pertinentes para el acuerdo y la inspección.',
      ),
    ],
  );
}

class _PrivacyPage extends StatelessWidget {
  const _PrivacyPage();

  @override
  Widget build(BuildContext context) => _InformationPage(
    title: 'Privacidad y permisos',
    children: [
      const SectionTitle(
        'Cuenta de Google',
        subtitle: 'El inicio de sesión permite mostrar el nombre, el correo y la foto que Google comparte con GoKawsay.',
      ),
      const SectionTitle(
        'Fotos y archivos',
        subtitle: 'El selector del teléfono te permite elegir fotos para publicaciones, inspecciones y comprobantes. GoKawsay utiliza el archivo que selecciones.',
      ),
      const SectionTitle(
        'Ubicación de las habitaciones',
        subtitle: 'El arrendador elige el pin de su anuncio. La ubicación exacta se muestra en la ficha de la publicación. Para marcarla basta con seleccionar el punto manualmente, sin usar el GPS del teléfono.',
      ),
      const SectionTitle(
        'Internet y datos del alquiler',
        subtitle: 'La conexión permite sincronizar publicaciones, solicitudes y mensajes. El historial del alquiler y su conversación están disponibles para las partes correspondientes.',
      ),
      const SectionTitle(
        'Calificaciones',
        subtitle: 'Al cerrar un alquiler, cada participante puede calificar a la otra persona de una a cinco estrellas. Las puntuaciones y su promedio son visibles para las personas que iniciaron sesión en GoKawsay.',
      ),
      const SectionTitle(
        'Permisos del dispositivo',
        subtitle: 'Consulta los permisos concedidos desde los ajustes del teléfono, en la ficha de GoKawsay.',
      ),
      _ExternalEntry('Privacidad de Google', _googlePrivacy),
      _ExternalEntry(
        'Derechos sobre tus datos personales en Perú',
        _dataRights,
      ),
    ],
  );
}

class _AboutPage extends StatelessWidget {
  const _AboutPage();

  @override
  Widget build(BuildContext context) => _InformationPage(
    title: 'Acerca de GoKawsay',
    children: [
      const Panel(
        child: SectionTitle(
          'GoKawsay',
          subtitle: 'Alquiler de habitaciones en Cusco, Perú.',
        ),
      ),
      FutureBuilder<PackageInfo>(
        future: _package,
        builder: (context, snapshot) {
          final info = snapshot.data;
          if (info == null && !snapshot.hasError) {
            return const LoadingState(label: 'Cargando versión…');
          }
          return ListTile(
            leading: const Icon(Icons.system_update_alt_outlined),
            title: const Text('Versión de la app'),
            subtitle: Text(
              info == null
                  ? 'No disponible'
                  : '${info.version} · Compilación ${info.buildNumber}',
            ),
          );
        },
      ),
      const SizedBox(height: 24),
      const _DeveloperCredit(),
    ],
  );
}

class _DeveloperCredit extends StatelessWidget {
  const _DeveloperCredit();

  @override
  Widget build(BuildContext context) {
    const github = 'AldairToSayH';
    final theme = Theme.of(context);
    final caption = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Column(
      children: [
        Text('© 2026 GoKawsay', style: caption, textAlign: TextAlign.center),
        const SizedBox(height: 6),
        Text(
          'Desarrollado por dairaldev',
          style: caption,
          textAlign: TextAlign.center,
        ),
        Center(
          child: TextButton(
            style: TextButton.styleFrom(textStyle: theme.textTheme.labelMedium),
            onPressed: () =>
                openExternal(context, Uri.https('github.com', '/$github')),
            child: const Text('GitHub · $github', textAlign: TextAlign.center),
          ),
        ),
      ],
    );
  }
}

class _InformationPage extends StatelessWidget {
  const _InformationPage({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: SafeArea(child: PageList(children: children)),
  );
}

class _ExternalEntry extends StatelessWidget {
  const _ExternalEntry(this.label, this.url);

  final String label;
  final Uri url;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: const Icon(Icons.open_in_new),
    title: Text(label),
    onTap: () => openExternal(context, url),
  );
}
