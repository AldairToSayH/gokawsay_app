import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import 'components.dart';

Future<void> openExternal(BuildContext context, Uri link) async {
  try {
    if (await launchUrl(link, mode: LaunchMode.externalApplication)) return;
  } catch (_) {
    // El sistema puede no tener una aplicación disponible para este enlace.
  }
  if (context.mounted) notice(context, 'No pudimos abrir el enlace.');
}
