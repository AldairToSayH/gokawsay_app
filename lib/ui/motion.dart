import 'package:lottie/lottie.dart';
import 'package:material_ui/material_ui.dart';

enum AppMotion {
  opening('opening', Icons.roofing_rounded),
  internal('inter', Icons.hourglass_top_rounded),
  search('cargadebusqueda', Icons.search_rounded),
  landlord('arrendador_carga_perfiles', Icons.home_work_outlined),
  tenant('carga_perfil_arrendatario', Icons.person_outline_rounded),
  booking('reserva_confirmada', Icons.check_circle_outline_rounded),
  change('reserva_confirmada', Icons.check_rounded),
  payment('pago_confirmado', Icons.receipt_long_outlined),
  checkout('checking_final', Icons.task_alt_rounded);

  const AppMotion(this.asset, this.icon);
  final String asset;
  final IconData icon;
}

class MotionArtwork extends StatelessWidget {
  const MotionArtwork(
    this.motion, {
    super.key,
    this.size = 96,
    this.loop = true,
  });

  final AppMotion motion;
  final double size;
  final bool loop;

  @override
  Widget build(BuildContext context) {
    final fallback = Icon(
      motion.icon,
      size: size * .55,
      color: Theme.of(context).colorScheme.primary,
    );
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: MediaQuery.disableAnimationsOf(context)
            ? fallback
            : _LottiePlayback(
                key: ValueKey((motion, loop)),
                motion: motion,
                loop: loop,
                fallback: fallback,
              ),
      ),
    );
  }
}

class _LottiePlayback extends StatefulWidget {
  const _LottiePlayback({
    super.key,
    required this.motion,
    required this.loop,
    required this.fallback,
  });

  final AppMotion motion;
  final bool loop;
  final Widget fallback;

  @override
  State<_LottiePlayback> createState() => _LottiePlaybackState();
}

class _LottiePlaybackState extends State<_LottiePlayback>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(vsync: this);
  static final _burstOnly = LottieDelegates(
    values: [
      for (final layer in ['check', 'circle - stroke', 'circle - bg'])
        ValueDelegate.transformOpacity([layer], value: 0),
    ],
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Lottie.asset(
    'assets/animations/${widget.motion.asset}.json',
    controller: _controller,
    delegates: widget.motion == AppMotion.change ? _burstOnly : null,
    fit: BoxFit.contain,
    frameRate: const FrameRate(30),
    errorBuilder: (_, _, _) => widget.fallback,
    onLoaded: (composition) {
      if (!mounted) return;
      _controller.duration = composition.duration * 1.32;
      if (widget.loop) {
        _controller.repeat();
      } else {
        _controller.forward(from: 0);
      }
    },
  );
}

class LoadingState extends StatelessWidget {
  const LoadingState({
    super.key,
    this.motion = AppMotion.internal,
    this.label = 'Cargando…',
  });

  final AppMotion motion;
  final String label;

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surface,
    child: Center(
      child: Semantics(
        liveRegion: true,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              MotionArtwork(
                motion,
                size: motion == AppMotion.opening ? 160 : 112,
              ),
              const SizedBox(height: 10),
              Text(
                label,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

void showOutcome(BuildContext context, AppMotion motion, String message) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 6),
        content: Row(
          children: [
            if (MediaQuery.disableAnimationsOf(context))
              Icon(
                motion.icon,
                color: Theme.of(context).colorScheme.onInverseSurface,
              )
            else if (motion == AppMotion.change)
              SizedBox.square(
                dimension: 46,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    MotionArtwork(motion, size: 46, loop: false),
                    Icon(
                      motion.icon,
                      size: 20,
                      color: Theme.of(context).colorScheme.onInverseSurface,
                    ),
                  ],
                ),
              )
            else
              MotionArtwork(motion, size: 46, loop: false),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
}
