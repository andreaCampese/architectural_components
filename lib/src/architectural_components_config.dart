part of '../architectural_components.dart';

/// Configurazione globale del package. Da impostare una volta sola in `main()`,
/// prima di `runApp`.
abstract final class ArchitecturalComponents {
  /// Chiamato per le anomalie non fatali (es. `UiRequest` non gestita o scartata).
  /// Default: `debugPrint`. Nel progetto, collegalo al logger:
  /// `ArchitecturalComponents.onWarning = (m) => MobileLoggerManager().log.w(m);`
  static void Function(String message) onWarning = debugPrint;

  /// Gestore globale degli errori. Imposta in `main()` un'implementazione di
  /// [FailureHandler] se i ViewModel usano `consume` con `Result`.
  static FailureHandler? failureHandler;
}
