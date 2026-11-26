part of '../architectural_components.dart';

/// Richiesta che un [BaseViewModel] emette verso il proprio [BaseScreenState]
/// per delegare la costruzione di un'interazione (dialog, bottom sheet, ...).
///
/// Il ViewModel costruisce una sottoclasse con soli dati di dominio e la emette
/// con [BaseViewModel.emitUiRequest]; lo screen la intercetta in
/// [BaseScreenState.handleUiRequest] in base al tipo runtime.
///
/// - Fire-and-forget (nessuna risposta): estendere [UiVoidRequest].
/// - Richiesta/risposta: estendere `UiRequest<T>`, definire [defaultResult]
///   e fare `await request.result` nel ViewModel subito dopo l'emissione.
///
/// Contratto per lo screen: se esiste un `await` sul risultato, chiamare
/// [complete] da OGNI percorso di chiusura (pulsanti, tap sul barrier, back di
/// sistema). [complete] è idempotente. Se una richiesta non viene gestita, o il
/// ViewModel viene disposto, la base la chiude con [defaultResult]: un `await`
/// non resta mai appeso. Il codice dopo l'`await` deve comunque controllare
/// `mounted`.
abstract class UiRequest<TResult> {
  final Completer<TResult> _completer = Completer<TResult>();

  /// Valore sicuro con cui la richiesta viene chiusa quando nessuno la gestisce.
  /// Di norma "l'utente ha rifiutato" (es. `false`).
  TResult get defaultResult;

  /// Si risolve quando lo screen chiama [complete] (o [completeWithDefault]).
  Future<TResult> get result => _completer.future;

  bool get isCompleted => _completer.isCompleted;

  /// Idempotente: le chiamate successive alla prima sono ignorate.
  void complete(TResult value) {
    if (!_completer.isCompleted) _completer.complete(value);
  }

  /// Chiude la richiesta con [defaultResult]. Idempotente.
  void completeWithDefault() => complete(defaultResult);
}

/// Richiesta fire-and-forget: nessuno attende l'esito.
abstract class UiVoidRequest extends UiRequest<void> {
  @override
  void get defaultResult {}
}
