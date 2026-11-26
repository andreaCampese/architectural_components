part of '../architectural_components.dart';

/// Su iOS, con il pop bloccato, Flutter disabilita lo swipe-back nativo.
/// Questo widget lo ricostruisce: un [GestureDetector] sul bordo sinistro anima
/// la pagina seguendo il dito e la fa SEMPRE tornare alla posizione originale;
/// se la soglia è superata, al rilascio invoca [onTriggered].
/// Non è un vero interactive-pop: dietro compare un placeholder neutro.
class EdgeSwipeBackGuard extends StatefulWidget {
  const EdgeSwipeBackGuard({
    super.key,
    required this.onTriggered,
    required this.child,
  });

  final VoidCallback onTriggered;
  final Widget child;

  @override
  State<EdgeSwipeBackGuard> createState() => _EdgeSwipeBackGuardState();
}

class _EdgeSwipeBackGuardState extends State<EdgeSwipeBackGuard> with SingleTickerProviderStateMixin {
  /// Larghezza dell'area sensibile al bordo sinistro.
  static const double _edgeWidth = 24.0;

  /// Trascinamento minimo per considerare valido lo swipe.
  static const double _threshold = 60.0;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );

  double _startX = 0;
  double _deltaX = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _snapBack() => _controller.animateTo(0.0, curve: Curves.easeOut);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxDrag = constraints.maxWidth;
        return Stack(
          children: [
            Positioned.fill(
              child: ColoredBox(
                color: Color.alphaBlend(
                  Colors.black.withValues(alpha: 0.08),
                  Theme.of(context).scaffoldBackgroundColor,
                ),
              ),
            ),
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(_controller.value * maxDrag, 0),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      boxShadow: _controller.value > 0
                          ? [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.25),
                                blurRadius: 12,
                                offset: const Offset(-4, 0),
                              ),
                            ]
                          : null,
                    ),
                    child: child,
                  ),
                );
              },
              child: widget.child,
            ),
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: _edgeWidth,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onHorizontalDragStart: (details) {
                  _startX = details.globalPosition.dx;
                  _deltaX = 0;
                },
                onHorizontalDragUpdate: (details) {
                  _deltaX = (details.globalPosition.dx - _startX).clamp(0.0, maxDrag);
                  _controller.value = _deltaX / maxDrag; // segue il dito 1:1
                },
                onHorizontalDragEnd: (details) async {
                  final triggered = _deltaX >= _threshold;
                  await _snapBack();
                  _deltaX = 0;
                  if (triggered && mounted) widget.onTriggered();
                },
                onHorizontalDragCancel: () async {
                  _deltaX = 0;
                  await _snapBack();
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
