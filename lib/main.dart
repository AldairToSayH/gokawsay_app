import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'firebase_options.dart';
import 'rentals/rental_store.dart';
import 'ui/app.dart';
import 'ui/motion.dart';
import 'ui/theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(const [
      'DM Sans',
    ], await rootBundle.loadString('assets/fonts/OFL-DM-Sans.txt'));
    yield LicenseEntryWithLineBreaks(const [
      'Instrument Serif',
    ], await rootBundle.loadString('assets/fonts/OFL-Instrument-Serif.txt'));
  });
  runApp(const StartupGate());
}

Future<GoKawsay> _initialize() async {
  const demo = kDebugMode && bool.fromEnvironment('GOKAWSAY_DEMO');
  const configuredHost = String.fromEnvironment('FIREBASE_EMULATOR_HOST');
  const databaseUrl = String.fromEnvironment('FIREBASE_DATABASE_URL');
  final app = await Firebase.initializeApp(
    options: demo ? null : DefaultFirebaseOptions.currentPlatform,
    demoProjectId: demo ? 'demo-gokawsay' : null,
  );
  final auth = FirebaseAuth.instanceFor(app: app);
  final database = FirebaseDatabase.instanceFor(
    app: app,
    databaseURL: demo
        ? 'https://demo-gokawsay-default-rtdb.firebaseio.com'
        : databaseUrl.isEmpty
        ? null
        : databaseUrl,
  );
  if (demo) {
    final host = configuredHost.isNotEmpty
        ? configuredHost
        : defaultTargetPlatform == TargetPlatform.android
        ? '10.0.2.2'
        : '127.0.0.1';
    await auth.useAuthEmulator(host, 9099, automaticHostMapping: false);
    database.useDatabaseEmulator(host, 9000, automaticHostMapping: false);
  }
  return GoKawsay(auth: auth, store: RentalStore(database), demo: demo);
}

class StartupGate extends StatefulWidget {
  const StartupGate({super.key});

  @override
  State<StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<StartupGate> {
  late Future<GoKawsay> _startup = _start();

  Future<GoKawsay> _start() async {
    final intro =
        WidgetsBinding
            .instance
            .platformDispatcher
            .accessibilityFeatures
            .disableAnimations
        ? Future<void>.value()
        : Future<void>.delayed(const Duration(milliseconds: 2300));
    final app = await _initialize();
    await intro;
    return app;
  }

  @override
  Widget build(BuildContext context) => FutureBuilder(
    future: _startup,
    builder: (context, snapshot) {
      if (snapshot.data case final app?) return app;
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: goKawsayTheme(Brightness.light),
        darkTheme: goKawsayTheme(Brightness.dark),
        home: Scaffold(
          body: SafeArea(
            child: snapshot.hasError
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'No se pudo iniciar GoKawsay.',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 14),
                          FilledButton(
                            onPressed: () =>
                                setState(() => _startup = _start()),
                            child: const Text('Volver a intentar'),
                          ),
                        ],
                      ),
                    ),
                  )
                : const LoadingState(
                    motion: AppMotion.opening,
                    label: 'Abriendo GoKawsay…',
                  ),
          ),
        ),
      );
    },
  );
}
