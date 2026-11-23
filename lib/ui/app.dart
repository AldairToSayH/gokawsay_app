import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:material_ui/material_ui.dart';

import '../locations/cusco.dart';
import '../rentals/models.dart';
import '../rentals/rental_store.dart';
import 'components.dart';
import 'google_account.dart';
import 'location_fields.dart';
import 'profile_information.dart';
import 'ratings.dart';
import 'room_editor.dart';
import 'room_map.dart';
import 'motion.dart';
import 'theme.dart';
import 'rental_page.dart';

class GoKawsay extends StatelessWidget {
  const GoKawsay({
    super.key,
    required this.auth,
    required this.store,
    required this.demo,
  });

  final FirebaseAuth auth;
  final RentalStore store;
  final bool demo;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'GoKawsay',
    debugShowCheckedModeBanner: false,
    theme: goKawsayTheme(Brightness.light),
    darkTheme: goKawsayTheme(Brightness.dark),
    supportedLocales: const [Locale('es', 'PE')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    home: AuthGate(auth: auth, store: store, demo: demo),
  );
}

class AuthGate extends StatefulWidget {
  const AuthGate({
    super.key,
    required this.auth,
    required this.store,
    required this.demo,
  });

  final FirebaseAuth auth;
  final RentalStore store;
  final bool demo;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final _authChanges = widget.auth.authStateChanges();
  late final _googleReady = GoogleSignIn.instance.initialize(
    clientId: const String.fromEnvironment('GOOGLE_IOS_CLIENT_ID').isEmpty
        ? null
        : const String.fromEnvironment('GOOGLE_IOS_CLIENT_ID'),
    serverClientId:
        const String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID').isEmpty
        ? null
        : const String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID'),
  );
  bool _opening = false;

  Future<void> _openGoogle() async {
    try {
      await _googleReady;
      final account = await GoogleSignIn.instance.authenticate();
      final token = account.authentication.idToken;
      if (token == null) throw StateError('Google no devolvió un token.');
      await widget.auth.signInWithCredential(
        GoogleAuthProvider.credential(idToken: token),
      );
    } on GoogleSignInException catch (error) {
      if (error.code != GoogleSignInExceptionCode.canceled) rethrow;
    }
  }

  Future<void> _openDemo(String key, String name) async {
    if (_opening) return;
    setState(() => _opening = true);
    final email = '$key@gokawsay.test';
    const password = 'local-demo-gokawsay';
    try {
      try {
        await widget.auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      } on FirebaseAuthException catch (error) {
        if (![
          'user-not-found',
          'invalid-credential',
          'invalid-login-credentials',
        ].contains(error.code)) {
          rethrow;
        }
        final newCredentials = await widget.auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
        await newCredentials.user!.updateDisplayName(name);
      }
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) => DataView(
    stream: _authChanges,
    loadingLabel: 'Recuperando tu sesión…',
    buildData: (user) {
      if (_opening && user != null) {
        return const Scaffold(body: LoadingState(label: 'Iniciando sesión…'));
      }
      if (user != null) {
        return SignedIn(
          key: ValueKey(user.uid),
          auth: widget.auth,
          user: user,
          store: widget.store,
          demo: widget.demo,
        );
      }
      return Scaffold(
        body: SafeArea(
          child: PageList(
            children: [
              const WelcomeCover(),
              const SizedBox(height: 26),
              Text('Encuentra tu habitación', style: editorialHeading(context)),
              const SizedBox(height: 8),
              Text(
                'Busca un lugar en Cusco o publica una habitación para alquilar.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              if (widget.demo) ...[
                const SectionTitle('Entra a la demostración'),
                AsyncAction(
                  label: 'Mateo · Arrendador',
                  icon: Icons.home_work_outlined,
                  run: () => _openDemo('mateo', 'Mateo Quispe'),
                ),
                const SizedBox(height: 8),
                AsyncAction(
                  label: 'Lucía · Arrendataria',
                  icon: Icons.person_outline,
                  secondary: true,
                  run: () => _openDemo('lucia', 'Lucía Ramos'),
                ),
                const SizedBox(height: 8),
                AsyncAction(
                  label: 'Diego · Arrendatario',
                  icon: Icons.person_outline,
                  secondary: true,
                  run: () => _openDemo('diego', 'Diego Huamán'),
                ),
              ] else ...[
                AsyncAction(
                  label: 'Continuar con Google',
                  icon: Icons.login,
                  busyLabel: 'Conectando con Google…',
                  run: _openGoogle,
                ),
                const SizedBox(height: 8),
                const _SocialSignInPreview(),
              ],
            ],
          ),
        ),
      );
    },
  );
}

class _SocialSignInPreview extends StatelessWidget {
  const _SocialSignInPreview();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final primaryButton = theme.filledButtonTheme.style;
    final buttonStyle =
        OutlinedButton.styleFrom(
          disabledForegroundColor: muted,
          side: BorderSide(color: theme.colorScheme.outlineVariant),
        ).copyWith(
          minimumSize: primaryButton?.minimumSize,
          padding: primaryButton?.padding,
          shape: primaryButton?.shape,
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 6,
      children: [
        Text(
          'Vista previa',
          textAlign: TextAlign.center,
          style: theme.textTheme.labelMedium?.copyWith(color: muted),
        ),
        for (final (name, icon) in const [
          ('Facebook', Icon(Icons.facebook, size: 18)),
          ('Apple', Icon(Icons.apple, size: 18)),
          ('TikTok', Icon(Icons.tiktok, size: 18)),
          ('X', ImageIcon(AssetImage('assets/icons/twitter.png'), size: 18)),
        ])
          OutlinedButton.icon(
            style: buttonStyle,
            onPressed: null,
            icon: icon,
            label: Text('Continuar con $name', textAlign: TextAlign.center),
          ),
      ],
    );
  }
}

class WelcomeCover extends StatelessWidget {
  const WelcomeCover({super.key});

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(designRadius + 6),
    child: Stack(
      children: [
        AspectRatio(
          aspectRatio: MediaQuery.sizeOf(context).width < 600 ? 1.12 : 2,
          child: Image.asset(
            roomEditorialPhoto,
            fit: BoxFit.cover,
            excludeFromSemantics: true,
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.center,
                colors: [
                  Colors.black.withValues(alpha: .72),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        Positioned(
          top: 18,
          left: 20,
          right: 20,
          child: Text(
            'GoKawsay',
            style: editorialHeading(context)
                .copyWith(fontSize: 38, color: Colors.white),
          ),
        ),
      ],
    ),
  );
}

class SignedIn extends StatefulWidget {
  const SignedIn({
    super.key,
    required this.auth,
    required this.user,
    required this.store,
    required this.demo,
  });

  final FirebaseAuth auth;
  final User user;
  final RentalStore store;
  final bool demo;

  @override
  State<SignedIn> createState() => _SignedInState();
}

class _SignedInState extends State<SignedIn> {
  late final _profile = widget.store.profile(widget.user.uid);
  late final _rooms = widget.store.rooms();
  late final _incoming = widget.store.rentals(widget.user.uid, asOwner: true);
  late final _mine = widget.store.rentals(widget.user.uid, asOwner: false);
  int _tab = 0;
  String _search = '';
  String _ownedSearch = '';
  RoomArea _catalogArea = const RoomArea();
  RoomArea _ownedArea = const RoomArea();
  AccountIdentity get _identity => AccountIdentity(widget.user);
  bool _lowestPriceFirst = false;

  @override
  Widget build(BuildContext context) => DataView(
    stream: _profile,
    motion: widget.user.email == 'mateo@gokawsay.test'
        ? AppMotion.landlord
        : AppMotion.internal,
    loadingLabel: 'Cargando tu perfil…',
    buildData: (profile) {
      if (profile?.role == null) {
        final suggestedRole = widget.demo
            ? widget.user.email == 'mateo@gokawsay.test'
                  ? ProfileRole.landlord
                  : ProfileRole.tenant
            : null;
        final demoName = widget.demo
            ? switch (widget.user.email) {
                'mateo@gokawsay.test' => 'Mateo Quispe',
                'lucia@gokawsay.test' => 'Lucía Ramos',
                'diego@gokawsay.test' => 'Diego Huamán',
                _ => '',
              }
            : '';
        return ProfileEditor(
          store: widget.store,
          uid: widget.user.uid,
          name: profile?.name ?? _identity.name ?? demoName,
          identity: widget.demo ? null : _identity,
          bio: profile?.bio ?? '',
          role: suggestedRole,
          initial: true,
          signOut: widget.auth.signOut,
        );
      }
      return DataView(
        stream: _rooms,
        motion: profile!.role == ProfileRole.landlord
            ? AppMotion.landlord
            : AppMotion.search,
        loadingLabel: profile.role == ProfileRole.landlord
            ? 'Cargando publicaciones…'
            : 'Buscando habitaciones…',
        buildData: (rooms) => DataView(
          stream: _incoming,
          motion: profile.role == ProfileRole.landlord
              ? AppMotion.landlord
              : AppMotion.internal,
          loadingLabel: 'Cargando solicitudes…',
          buildData: (incoming) => DataView(
            stream: _mine,
            motion: profile.role == ProfileRole.tenant
                ? AppMotion.tenant
                : AppMotion.internal,
            loadingLabel: 'Cargando alquileres…',
            buildData: (mine) =>
                _shell(context, profile, rooms, incoming, mine),
          ),
        ),
      );
    },
  );

  Widget _shell(
    BuildContext context,
    Profile profile,
    List<Room> rooms,
    List<Rental> incoming,
    List<Rental> mine,
  ) {
    final pending = incoming
        .where((rental) => rental.phase == RentalPhase.requested)
        .length;
    final landlord = profile.role == ProfileRole.landlord;
    final pages = ['GoKawsay', 'Mis solicitudes', 'Mi perfil'];
    return Scaffold(
      appBar: AppBar(
        title: Text(
          pages[_tab],
          style: _tab == 0
              ? editorialHeading(context).copyWith(
                  fontSize: 34,
                  color: Theme.of(context).colorScheme.primary,
                )
              : Theme.of(context).textTheme.titleLarge,
        ),
        actions: [
          if (widget.demo)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Chip(label: Text('Demostración')),
            ),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: AnimatedSwitcher(
          duration: Duration(
            milliseconds: MediaQuery.disableAnimationsOf(context) ? 0 : 340,
          ),
          child: KeyedSubtree(
            key: ValueKey(_tab),
            child: switch (_tab) {
              0 =>
                landlord
                    ? PageList(children: _listings(profile, rooms))
                    : _catalog(profile, rooms, mine),
              1 => _requests(profile, incoming, mine),
              _ => _account(profile, rooms),
            },
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (value) => setState(() => _tab = value),
        destinations: [
          NavigationDestination(
            icon: Icon(landlord ? Icons.home_work_outlined : Icons.search),
            label: landlord ? 'Habitaciones' : 'Explorar',
          ),
          NavigationDestination(
            icon: Badge.count(
              isLabelVisible: pending > 0,
              count: pending,
              child: const Icon(Icons.forum_outlined),
            ),
            label: 'Solicitudes',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }

  Widget _catalog(Profile profile, List<Room> rooms, List<Rental> mine) {
    final query = normalizePlace(_search);
    final available = rooms
        .where((room) => room.visible && _catalogArea.includes(room, query))
        .toList();
    if (_lowestPriceFirst) {
      available.sort((a, b) => a.monthly.compareTo(b.monthly));
    }
    final header = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Encuentra tu habitación', style: editorialHeading(context)),
        const SizedBox(height: 17),
        TextFormField(
          initialValue: _search,
          onChanged: (value) => setState(() => _search = value),
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(
            labelText: 'Habitación, barrio o ciudad',
            prefixIcon: Icon(Icons.search_rounded),
          ),
        ),
        const SizedBox(height: 12),
        AreaFilterBar(
          area: _catalogArea,
          onChange: (area) => setState(() => _catalogArea = area),
        ),
        const SizedBox(height: 16),
        if (available.isNotEmpty) ...[
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            children: [
              Text(
                available.length == 1
                    ? '1 habitación disponible'
                    : '${available.length} habitaciones disponibles',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              PopupMenuButton<bool>(
                tooltip: 'Ordenar habitaciones',
                initialValue: _lowestPriceFirst,
                onSelected: (value) =>
                    setState(() => _lowestPriceFirst = value),
                itemBuilder: (context) => const [
                  PopupMenuItem(value: false, child: Text('Más recientes')),
                  PopupMenuItem(
                    value: true,
                    child: Text('Menor precio primero'),
                  ),
                ],
                icon: const Icon(Icons.swap_vert_rounded),
              ),
            ],
          ),
          const SizedBox(height: 10),
        ],
        if (available.isEmpty)
          EmptyState(
            _search.trim().isEmpty && _catalogArea.isEmpty
                ? 'Aún no hay habitaciones publicadas'
                : 'No encontramos coincidencias',
            _search.trim().isEmpty && _catalogArea.isEmpty
                ? 'Las nuevas publicaciones aparecerán aquí.'
                : 'Prueba con otra zona o quita el filtro de ubicación.',
            icon: Icons.search_rounded,
          ),
      ],
    );
    return LayoutBuilder(
      builder: (context, bounds) {
        final side = ((bounds.maxWidth - 1040) / 2).clamp(
          20.0,
          double.infinity,
        );
        final columns = bounds.maxWidth - 2 * side >= 700 ? 2 : 1;
        final rows = (available.length / columns).ceil();
        return ListView.builder(
          padding: EdgeInsets.fromLTRB(side, 16, side, 28),
          itemCount: rows + 1,
          itemBuilder: (context, index) {
            if (index == 0) return header;
            final row = available.skip((index - 1) * columns).take(columns);
            return Row(
              spacing: 18,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final room in row)
                  Expanded(
                    key: ValueKey(room.id),
                    child: RoomCard(
                      room: room,
                      store: widget.store,
                      open: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => RoomPage(
                            room: room,
                            profile: profile,
                            store: widget.store,
                            existing: mine
                                .where((rent) => rent.room.id == room.id)
                                .firstOrNull,
                          ),
                        ),
                      ),
                    ),
                  ),
                if (row.length < columns) const Spacer(),
              ],
            );
          },
        );
      },
    );
  }

  Widget _requests(Profile profile, List<Rental> incoming, List<Rental> mine) {
    final grouped = <String, List<Rental>>{};
    for (final item in incoming) {
      grouped.putIfAbsent(item.room.id, () => []).add(item);
    }
    return PageList(
      children: [
        Panel(
          child: Row(
            spacing: 12,
            children: [
              Expanded(
                child: Text(
                  profile.role == ProfileRole.landlord
                      ? 'Interesados y alquileres'
                      : 'Tus solicitudes y alquileres',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              MotionArtwork(
                profile.role == ProfileRole.landlord
                    ? AppMotion.landlord
                    : AppMotion.tenant,
                size: 74,
                loop: false,
              ),
            ],
          ),
        ),
        if (profile.role == ProfileRole.landlord || grouped.isNotEmpty)
          const SectionTitle('Solicitudes recibidas'),
        if (profile.role == ProfileRole.landlord && grouped.isEmpty)
          const EmptyState(
            'Aún no recibiste solicitudes',
            'Las solicitudes para tus habitaciones aparecerán aquí.',
          ),
        for (final group in grouped.values) ...[
          SectionTitle(group.first.room.title, subtitle: _interestCount(group)),
          for (final item in group) _rentalTile(item, profile),
        ],
        if (profile.role == ProfileRole.tenant || mine.isNotEmpty)
          const SectionTitle('Mis solicitudes y alquileres'),
        if (profile.role == ProfileRole.tenant && mine.isEmpty)
          const EmptyState(
            'Aún no tienes solicitudes',
            'Explora el catálogo y envía una solicitud para iniciar una conversación.',
          ),
        for (final item in mine) _rentalTile(item, profile),
      ],
    );
  }

  String _interestCount(List<Rental> group) {
    final count = group
        .where((item) => item.phase == RentalPhase.requested)
        .length;
    return count == 1 ? '1 persona interesada' : '$count personas interesadas';
  }

  Widget _rentalTile(Rental rental, Profile profile) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      leading: const CircleAvatar(child: Icon(Icons.chat_bubble_outline)),
      title: Text(
        rental.isOwner(profile.uid) ? rental.tenantName : rental.room.title,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 4,
        children: [
          Text(rental.phase.label),
          UserRating(
            store: widget.store,
            uid: rental.counterpartUid(profile.uid),
          ),
        ],
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) =>
              RentalPage(id: rental.id, store: widget.store, profile: profile),
        ),
      ),
    ),
  );

  Widget _account(Profile profile, List<Room> rooms) {
    return PageList(
      children: [
        Panel(
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: AccountAvatar(photoUrl: _identity.photoUrl),
            title: Text(profile.name),
            subtitle: Text(
              [
                profile.role!.label,
                ?(widget.demo ? null : _identity.email),
                if (profile.bio.isNotEmpty) profile.bio,
              ].join('\n'),
            ),
            trailing: IconButton(
              tooltip: 'Editar perfil',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ProfileEditor(
                    store: widget.store,
                    uid: profile.uid,
                    name: profile.name,
                    bio: profile.bio,
                    role: profile.role,
                    identity: widget.demo ? null : _identity,
                  ),
                ),
              ),
            ),
          ),
        ),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SectionTitle('Tu calificación'),
              UserRating(store: widget.store, uid: profile.uid),
            ],
          ),
        ),
        if (profile.role == ProfileRole.tenant &&
            rooms.any(
              (room) => room.owner == profile.uid && !room.archived,
            )) ...[
          const SectionTitle('Mis publicaciones anteriores'),
          ..._listings(profile, rooms),
        ],
        const ProfileInformation(),
        const SizedBox(height: 16),
        AsyncAction(
          secondary: true,
          label: 'Cerrar sesión',
          icon: Icons.logout,
          run: widget.auth.signOut,
        ),
      ],
    );
  }

  List<Widget> _listings(Profile profile, List<Room> rooms) {
    final owned = rooms
        .where((room) => room.owner == profile.uid && !room.archived)
        .toList();
    final query = normalizePlace(_ownedSearch);
    final visible = owned.where((room) => _ownedArea.includes(room, query));
    final canPublish = profile.role == ProfileRole.landlord;
    return [
      if (canPublish) ...[
        Text('Mis habitaciones', style: editorialHeading(context)),
        const SizedBox(height: 16),
      ],
      if (canPublish)
        FilledButton.icon(
          icon: const Icon(Icons.add),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => RoomEditor(store: widget.store, profile: profile),
            ),
          ),
          label: const Text('Publicar habitación'),
        ),
      if (canPublish &&
          widget.demo &&
          widget.user.email == 'mateo@gokawsay.test' &&
          !owned.any((room) => room.example))
        AsyncAction(
          secondary: true,
          label: 'Publicar habitación de ejemplo',
          run: () => widget.store.publish(profile, {
            'title': 'Habitación luminosa en San Blas',
            'location': 'San Blas, Cusco',
            'ubigeo': '080101',
            'neighborhood': 'San Blas',
            'description': 'Habitación privada amoblada con escritorio, luz natural y vista a los techos de Cusco. Cerca de comercios y rutas de transporte.',
            'monthly': 52000,
            'deposit': true,
            'example': true,
          }, null),
        ),
      const SizedBox(height: 14),
      if (owned.isNotEmpty) ...[
        TextFormField(
          initialValue: _ownedSearch,
          decoration: const InputDecoration(
            labelText: 'Buscar mis publicaciones',
            prefixIcon: Icon(Icons.search_rounded),
          ),
          onChanged: (value) => setState(() => _ownedSearch = value),
        ),
        const SizedBox(height: 10),
        AreaFilterBar(
          area: _ownedArea,
          onChange: (area) => setState(() => _ownedArea = area),
        ),
        const SizedBox(height: 14),
      ],
      if (canPublish && owned.isEmpty)
        const EmptyState(
          'Aún no tienes habitaciones',
          'Publica tu primera habitación para recibir solicitudes.',
        ),
      if (owned.isNotEmpty && visible.isEmpty)
        const EmptyState(
          'No encontramos publicaciones',
          'Prueba con otro nombre o quita el filtro de ubicación.',
          icon: Icons.search_rounded,
        ),
      for (final room in visible)
        Card(
          margin: const EdgeInsets.only(bottom: 18),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              RoomPicture(
                key: ValueKey(room.id),
                room: room,
                store: widget.store,
                aspectRatio: 2.05,
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  spacing: 10,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      room.title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(room.location),
                    StatusLabel(
                      room.available ? 'En el catálogo' : 'Publicación pausada',
                      emphasis: room.available,
                    ),
                    Wrap(
                      spacing: 9,
                      runSpacing: 6,
                      children: [
                        OutlinedButton.icon(
                          icon: const Icon(Icons.edit_outlined),
                          label: const Text('Editar'),
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => RoomEditor(
                                store: widget.store,
                                profile: profile,
                                room: room,
                              ),
                            ),
                          ),
                        ),
                        AsyncAction(
                          secondary: true,
                          label: room.available ? 'Pausar' : 'Reactivar',
                          run: () => _toggleRoom(room),
                        ),
                        AsyncAction(
                          secondary: true,
                          icon: Icons.delete_outline,
                          label: 'Eliminar',
                          busyLabel: 'Eliminando…',
                          run: () => _deleteRoom(room),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
    ];
  }

  Future<void> _deleteRoom(Room room) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Eliminar publicación'),
        content: Text(
          '«${room.title}» desaparecerá del catálogo y de Mis habitaciones. El historial de solicitudes y alquileres seguirá disponible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Eliminar publicación'),
          ),
        ],
      ),
    );
    if (accepted != true || !mounted) return;
    await widget.store.archiveRoom(room);
    if (mounted) {
      showOutcome(context, AppMotion.change, 'Publicación eliminada.');
    }
  }

  Future<void> _toggleRoom(Room room) async {
    await widget.store.setAvailability(room, !room.available);
    if (mounted) {
      showOutcome(
        context,
        AppMotion.change,
        room.available ? 'Publicación pausada.' : 'Publicación reactivada.',
      );
    }
  }
}

class RoomCard extends StatelessWidget {
  const RoomCard({
    super.key,
    required this.room,
    required this.store,
    required this.open,
  });

  final Room room;
  final RentalStore store;
  final VoidCallback open;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 20),
      child: InkWell(
        onTap: open,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Stack(
              children: [
                RoomPicture(room: room, store: store),
                if (room.deposit)
                  const Positioned(
                    top: 12,
                    left: 12,
                    right: 12,
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: StatusLabel(
                        'Garantía a coordinar',
                        icon: Icons.shield_outlined,
                      ),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 17),
              child: Column(
                spacing: 5,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(room.title, style: theme.textTheme.titleLarge),
                  Text(
                    room.location,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: soles(room.monthly),
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const TextSpan(text: ' / mes'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RoomPicture extends StatefulWidget {
  const RoomPicture({
    super.key,
    required this.room,
    required this.store,
    this.aspectRatio = 1.38,
    this.fit = BoxFit.cover,
  });
  final double aspectRatio;
  final BoxFit fit;
  final Room room;
  final RentalStore store;
  @override
  State<RoomPicture> createState() => _RoomPictureState();
}

class _RoomPictureState extends State<RoomPicture> {
  late var _photo = _loadPhoto();

  Future<Uint8List?>? _loadPhoto() =>
      widget.room.photo ? widget.store.roomPhoto(widget.room.id) : null;

  @override
  void didUpdateWidget(covariant RoomPicture oldWidget) {
    super.didUpdateWidget(oldWidget);
    final previous = oldWidget.room;
    final current = widget.room;
    if (previous.id != current.id ||
        previous.photo != current.photo ||
        previous.photoRevision != current.photoRevision ||
        oldWidget.store != widget.store) {
      _photo = _loadPhoto();
    }
  }

  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: widget.aspectRatio,
    child: widget.room.photo
        ? RemotePhoto(photo: _photo!, label: widget.room.title, fit: widget.fit)
        : widget.room.example
        ? Image.asset(
            roomEditorialPhoto,
            fit: widget.fit,
            semanticLabel: 'Habitación de ejemplo en San Blas',
            errorBuilder: (_, _, _) => const PhotoPlaceholder(),
          )
        : const PhotoPlaceholder(),
  );
}

class RoomPage extends StatefulWidget {
  const RoomPage({
    super.key,
    required this.room,
    required this.profile,
    required this.store,
    this.existing,
  });
  final Room room;
  final Profile profile;
  final RentalStore store;
  final Rental? existing;

  @override
  State<RoomPage> createState() => _RoomPageState();
}

class _RoomPageState extends State<RoomPage> {
  late final _room = widget.store.room(widget.room.id);

  @override
  Widget build(BuildContext context) => StreamBuilder<Room?>(
    stream: _room,
    initialData: widget.room,
    builder: (context, snapshot) {
      final room = snapshot.data;
      if (snapshot.hasError || room == null) {
        return Scaffold(
          appBar: AppBar(title: const Text('Habitación')),
          body: const SafeArea(
            child: PageList(
              children: [
                EmptyState(
                  'Habitación no disponible',
                  'Vuelve al catálogo para ver las publicaciones actuales.',
                ),
              ],
            ),
          ),
        );
      }
      return _RoomDetails(
        room: room,
        profile: widget.profile,
        store: widget.store,
        existing: widget.existing,
      );
    },
  );
}

class _RoomDetails extends StatelessWidget {
  const _RoomDetails({
    required this.room,
    required this.profile,
    required this.store,
    this.existing,
  });

  final Room room;
  final Profile profile;
  final RentalStore store;
  final Rental? existing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Habitación')),
      body: SafeArea(
        bottom: false,
        child: PageList(
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(designRadius),
                  child: RoomPicture(
                    room: room,
                    store: store,
                    aspectRatio: 1.26,
                  ),
                ),
                if (room.photo || room.example)
                  Positioned(
                    bottom: 12,
                    right: 12,
                    child: IconButton.filledTonal(
                      tooltip: 'Ampliar foto',
                      icon: const Icon(Icons.open_in_full_rounded),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => Scaffold(
                            appBar: AppBar(
                              title: const Text('Foto de la habitación'),
                            ),
                            body: SafeArea(
                              child: InteractiveViewer(
                                maxScale: 4,
                                child: Center(
                                  child: RoomPicture(
                                    room: room,
                                    store: store,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              room.location,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 6),
            Text(room.title, style: editorialHeading(context)),
            if (room.deposit) ...[
              const SizedBox(height: 14),
              const Align(
                alignment: Alignment.centerLeft,
                child: StatusLabel(
                  'Garantía a coordinar',
                  icon: Icons.shield_outlined,
                ),
              ),
            ],
            const SizedBox(height: 16),
            const Divider(),
            SectionTitle('Arrendador', subtitle: room.ownerName),
            UserRating(store: store, uid: room.owner),
            const SizedBox(height: 12),
            const Divider(),
            SectionTitle('Sobre la habitación', subtitle: room.description),
            if (room.preciseLocation case final location?
                when room.visible || room.owner == profile.uid)
              PublishedLocation(location: location, area: room.location),
            const Divider(),
            if (!room.visible && room.owner != profile.uid)
              const EmptyState(
                'Esta publicación ya no está disponible',
                'Puedes consultar tu solicitud desde el historial.',
              ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const CircleAvatar(
                child: Icon(Icons.person_outline_rounded),
              ),
              title: Text(room.ownerName),
              subtitle: const Text('Arrendador'),
            ),
          ],
        ),
      ),
      bottomNavigationBar:
          room.owner == profile.uid || !room.visible && existing == null
          ? null
          : DecoratedBox(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                border: Border(
                  top: BorderSide(color: theme.colorScheme.outlineVariant),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Center(
                  heightFactor: 1,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 744),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 11, 20, 11),
                      child: Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        runSpacing: 8,
                        spacing: 14,
                        children: [
                          Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: soles(room.monthly),
                                  style: theme.textTheme.titleLarge,
                                ),
                                const TextSpan(text: ' / mes'),
                              ],
                            ),
                          ),
                          AsyncAction(
                            label: existing == null
                                ? 'Solicitar reserva'
                                : 'Ver mi solicitud',
                            busyLabel: 'Enviando solicitud…',
                            run: () async {
                              if (existing == null) {
                                await store.request(room, profile);
                                if (!context.mounted) return;
                                notice(
                                  context,
                                  'Solicitud enviada al arrendador.',
                                );
                              }
                              if (context.mounted) {
                                Navigator.of(context).pushReplacement(
                                  MaterialPageRoute<void>(
                                    builder: (_) => RentalPage(
                                      id: store.requestId(room, profile),
                                      store: store,
                                      profile: profile,
                                    ),
                                  ),
                                );
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}

class ProfileEditor extends StatefulWidget {
  const ProfileEditor({
    super.key,
    required this.store,
    required this.uid,
    required this.name,
    this.bio = '',
    this.role,
    this.initial = false,
    this.signOut,
    this.identity,
  });
  final RentalStore store;
  final String uid;
  final String name;
  final String bio;
  final ProfileRole? role;
  final bool initial;
  final Future<void> Function()? signOut;
  final AccountIdentity? identity;
  @override
  State<ProfileEditor> createState() => _ProfileEditorState();
}

class _ProfileEditorState extends State<ProfileEditor> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.name);
  late final _bio = TextEditingController(text: widget.bio);
  late ProfileRole? _role = widget.role;

  @override
  void dispose() {
    _name.dispose();
    _bio.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.initial ? 'Configura tu perfil' : 'Tu perfil'),
    ),
    body: SafeArea(
      child: Form(
        key: _form,
        child: PageList(
          children: [
            if (widget.initial) ...[
              Text('¿Cómo usarás GoKawsay?', style: editorialHeading(context)),
              const SizedBox(height: 18),
            ],
            if (widget.identity case final identity?)
              Panel(
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: AccountAvatar(photoUrl: identity.photoUrl),
                  title: Text(identity.email ?? 'Cuenta de Google'),
                  subtitle: Text(
                    identity.verified
                        ? 'Correo verificado por Google'
                        : 'Cuenta de Google',
                  ),
                ),
              ),
            TextFormField(
              controller: _name,
              maxLength: 80,
              decoration: const InputDecoration(labelText: 'Nombre'),
              validator: requiredText,
            ),
            const SizedBox(height: 12),
            if (widget.initial)
              FormField<ProfileRole>(
                initialValue: _role,
                validator: (role) => role == null ? 'Selecciona un rol.' : null,
                builder: (field) => Column(
                  spacing: 9,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final role in ProfileRole.values)
                      RoleChoice(
                        role: role,
                        selected: field.value == role,
                        onSelect: () {
                          setState(() => _role = role);
                          field.didChange(role);
                        },
                      ),
                    if (field.errorText case final error?)
                      Text(
                        error,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 14),
            if (!widget.initial)
              TextFormField(
                controller: _bio,
                maxLength: 350,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Sobre ti (opcional)',
                ),
              ),
            AsyncAction(
              label: widget.initial ? 'Continuar' : 'Guardar perfil',
              busyLabel: 'Guardando perfil…',
              motion: _role == ProfileRole.landlord
                  ? AppMotion.landlord
                  : AppMotion.tenant,
              run: () async {
                if (!_form.currentState!.validate()) return;
                await widget.store.saveProfile(
                  widget.uid,
                  _name.text.trim(),
                  _bio.text.trim(),
                  _role!,
                );
                if (context.mounted && !widget.initial) Navigator.pop(context);
              },
            ),
            if (widget.signOut case final signOut?)
              AsyncAction(
                secondary: true,
                label: 'Cerrar sesión',
                run: signOut,
              ),
          ],
        ),
      ),
    ),
  );
}

class RoleChoice extends StatelessWidget {
  const RoleChoice({
    super.key,
    required this.role,
    required this.selected,
    required this.onSelect,
  });

  final ProfileRole role;
  final bool selected;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      selected: selected,
      child: Card(
        margin: EdgeInsets.zero,
        color: selected ? colors.primaryContainer : colors.surface,
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          onTap: onSelect,
          leading: CircleAvatar(
            backgroundColor: selected
                ? colors.primary
                : colors.secondaryContainer,
            foregroundColor: selected
                ? colors.onPrimary
                : colors.onSecondaryContainer,
            child: Icon(
              role == ProfileRole.landlord
                  ? Icons.home_work_outlined
                  : Icons.search_rounded,
            ),
          ),
          title: Text(role.label),
          subtitle: Text(role.description),
          trailing: selected
              ? Icon(Icons.check_circle, color: colors.primary)
              : null,
        ),
      ),
    );
  }
}
