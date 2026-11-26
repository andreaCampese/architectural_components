part of '../architectural_components.dart';

/// Gestore globale degli errori, implementato dall'app e registrato in
/// [ArchitecturalComponents.failureHandler]. Riceve il solo [AppError] di
/// dominio: non costruisce widget e non riceve testo localizzato.
abstract interface class FailureHandler {
  /// Errori TRASVERSALI (sessione scaduta, aggiornamento forzato, manutenzione):
  /// li gestisce l'app in un punto solo (es. navigando al login).
  /// Restituisce `true` se l'errore è stato gestito: il ViewModel non fa altro.
  FutureOr<bool> handleGlobal(AppError error);

  /// Presentazione generica all'utente di un errore che nessuno ha gestito in
  /// modo specifico (es. snackbar con il messaggio mappato da errore a testo
  /// localizzato). Il mapper `errore -> messaggio` sta nell'app.
  void presentError(AppError error);
}
