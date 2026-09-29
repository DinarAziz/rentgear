import 'package:flutter/material.dart';

/// Shared motion vocabulary so every animation in the app uses the same
/// durations and curves instead of inventing its own on the spot.
class AppMotion {
  const AppMotion._();

  /// Press feedback, tiny state flips.
  static const fast = Duration(milliseconds: 160);

  /// Status changes, crossfades — the default for "something changed".
  static const standard = Duration(milliseconds: 220);

  /// First-appearance entrances (list items, cards).
  static const entrance = Duration(milliseconds: 260);

  /// Rare, high-emotion moments (a transaction reaching "Selesai").
  static const delight = Duration(milliseconds: 500);

  static const easeOut = Curves.easeOutCubic;
  static const easeInOut = Curves.easeInOutCubic;
}

/// Fades and slides [child] up into place once, when it first appears.
///
/// Meant for list items that pop in together when a screen is opened
/// (catalog, rentals, equipment) — an occasional, decorative entrance that
/// never blocks interaction. Skips the motion entirely when the system
/// asks for reduced motion.
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
  });

  final Widget child;
  final Duration delay;

  /// Delay for item [index] in a list, capped so long lists don't make the
  /// last visible item wait an unreasonable amount of time.
  static Duration stagger(
    int index, {
    int cap = 8,
    Duration step = const Duration(milliseconds: 35),
  }) {
    return step * index.clamp(0, cap);
  }

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: AppMotion.entrance,
  );
  late final _curve = CurvedAnimation(
    parent: _controller,
    curve: AppMotion.easeOut,
  );

  bool _scheduled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // MediaQuery isn't available yet in initState, so the reduced-motion
    // check (and the one-time scheduling it gates) happens here instead.
    if (_scheduled) return;
    _scheduled = true;
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      _controller.value = 1;
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _curve,
      child: widget.child,
      builder: (context, child) => Opacity(
        opacity: _curve.value,
        child: Transform.translate(
          offset: Offset(0, (1 - _curve.value) * 14),
          child: child,
        ),
      ),
    );
  }
}

/// Wraps a value that changes over time (a status label, a badge) so the
/// swap crossfades instead of teleporting. Keep durations to [AppMotion.standard].
class StatusCrossfade extends StatelessWidget {
  const StatusCrossfade({super.key, required this.value, required this.child});

  /// Anything that identifies "this changed" — usually an enum or id.
  final Object value;
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: AppMotion.standard,
    switchInCurve: AppMotion.easeOut,
    switchOutCurve: AppMotion.easeOut,
    transitionBuilder: (child, animation) => FadeTransition(
      opacity: animation,
      child: ScaleTransition(
        scale: Tween(begin: 0.92, end: 1.0).animate(animation),
        child: child,
      ),
    ),
    child: KeyedSubtree(key: ValueKey(value), child: child),
  );
}

/// A status dot that pops in with a spring-like bounce the moment it first
/// renders "completed" — the one delight beat in an otherwise calm list.
/// Every other state stays a plain, unanimated dot (rare vs. frequent).
class CompletionDot extends StatelessWidget {
  const CompletionDot({
    super.key,
    required this.color,
    required this.celebrate,
  });

  final Color color;
  final bool celebrate;

  @override
  Widget build(BuildContext context) {
    if (!celebrate) return Icon(Icons.circle, size: 12, color: color);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: AppMotion.delight,
      curve: Curves.elasticOut,
      builder: (context, value, child) =>
          Transform.scale(scale: value, child: child),
      child: Icon(Icons.check_circle, size: 16, color: color),
    );
  }
}
