import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';

import 'motion.dart';

class AccountIdentity {
  AccountIdentity(User user) {
    final google = user.providerData
        .where((data) => data.providerId == 'google.com')
        .firstOrNull;
    name = google?.displayName ?? user.displayName;
    email = google?.email ?? user.email;
    photoUrl = google?.photoURL ?? user.photoURL;
    verified = user.emailVerified;
  }

  late final String? name;
  late final String? email;
  late final String? photoUrl;
  late final bool verified;
}

class AccountAvatar extends StatelessWidget {
  const AccountAvatar({super.key, this.photoUrl, this.size = 54});

  final String? photoUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final fallback = Center(
      child: Icon(Icons.person_outline, color: colors.onPrimaryContainer),
    );
    final uri = Uri.tryParse(photoUrl ?? '');
    return ClipOval(
      child: SizedBox.square(
        dimension: size,
        child: ColoredBox(
          color: colors.primaryContainer,
          child: uri == null || uri.scheme != 'https' || uri.host.isEmpty
              ? fallback
              : Image.network(
                  uri.toString(),
                  fit: BoxFit.cover,
                  semanticLabel: 'Tu foto de perfil',
                  errorBuilder: (_, _, _) => fallback,
                  loadingBuilder: (context, child, loading) => loading == null
                      ? child
                      : const Center(
                          child: MotionArtwork(AppMotion.internal, size: 27),
                        ),
                ),
        ),
      ),
    );
  }
}
