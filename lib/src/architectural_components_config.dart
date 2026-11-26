part of '../architectural_components.dart';

/// Configurazione globale del package. Da impostare una volta sola in `main()`,
/// prima di `runApp`.
abstract final class ArchitecturalComponents {
  /// Chiamato per le anomalie non fatali (es. `UiRequest` non gestita o scartata).
  /// Default: `debugPrint`. Nel progetto, collegalo al logger:
  /// `ArchitecturalComponents.onWarning = (m) => MobileLoggerManager().log.w(m);`
  static void Function(String message) onWarning = debugPrint;
}
