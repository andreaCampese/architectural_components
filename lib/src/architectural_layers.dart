part of '../architectural_components.dart';

/// Sovrappone al [child] il layer di caricamento e il blocco dei tocchi.
class ArchitecturalLayers extends StatelessWidget {
  const ArchitecturalLayers({
    super.key,
    required this.child,
    required this.progress,
    required this.interactionBlocked,
    required this.progressBackgroundColor,
    required this.progressWidget,
  });

  final Widget child;
  final ValueListenable<bool> progress;
  final ValueListenable<bool> interactionBlocked;
  final Color progressBackgroundColor;
  final Widget progressWidget;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        child,
        AnimatedBuilder(
          animation: Listenable.merge(<Listenable>[progress, interactionBlocked]),
          builder: (context, _) {
            final showLoader = progress.value;
            final blocked = interactionBlocked.value;

            if (!showLoader && !blocked) return const SizedBox.shrink();

            final layer = SizedBox.expand(
              child: ColoredBox(
                color: showLoader ? progressBackgroundColor : Colors.transparent,
                child: showLoader ? Center(child: progressWidget) : null,
              ),
            );

            // I tocchi sono assorbiti SOLO se il blocco è attivo:
            // showProgress(blockInteraction: false) lascia passare i tocchi.
            return blocked ? AbsorbPointer(child: layer) : IgnorePointer(child: layer);
          },
        ),
      ],
    );
  }
}
