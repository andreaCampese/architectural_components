part of '../architectural_components.dart';

/// Classe base per la logica e lo stato di una screen (1 ViewModel : 1 Screen).
///
/// Non conosce la UI: nessun BuildContext, nessun widget. Per chiedere
/// qualcosa alla UI usa [emitUiRequest].
class BaseViewModel extends ChangeNotifier {
  // ---------------------------------------------------------------------------
  // UiRequest
  // ---------------------------------------------------------------------------

  final StreamController<UiRequest> _uiRequestController = StreamController<UiRequest>.broadcast();
  final Set<UiRequest> _pendingRequests = <UiRequest>{};

  /// Ascoltato da [BaseScreenState]. Esposto per i test del ViewModel;
  /// il codice applicativo non deve ascoltarlo.
  @visibleForTesting
  Stream<UiRequest> get uiRequests => _uiRequestController.stream;

  /// Delega allo screen un'interazione UI. Se il ViewModel è disposto o nessuno
  /// è in ascolto, la richiesta viene chiusa subito con il suo
  /// [UiRequest.defaultResult].
  ///
  /// Non chiamarlo nel costruttore: lo screen non è ancora in ascolto.
  @protected
  void emitUiRequest(UiRequest request) {
    if (!_mounted || !_uiRequestController.hasListener) {
      request.completeWithDefault();
      ArchitecturalComponents.onWarning(
        '[$runtimeType] UiRequest ${request.runtimeType} scartata: ViewModel disposto o nessuno screen in ascolto.',
      );
      return;
    }
    if (request is! UiVoidRequest) {
      _pendingRequests.add(request);
      unawaited(request.result.whenComplete(() => _pendingRequests.remove(request)));
    }
    _uiRequestController.add(request);
  }

  // ---------------------------------------------------------------------------
  // Loader e blocco input
  // ---------------------------------------------------------------------------

  final ValueNotifier<bool> _progress = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _interactionBlocked = ValueNotifier<bool>(false);

  /// True se il layer di caricamento è visibile (sola lettura).
  ValueListenable<bool> get progress => _progress;

  /// True se i tocchi sono bloccati (sola lettura).
  ValueListenable<bool> get interactionBlocked => _interactionBlocked;

  int _progressCount = 0;
  int _blockingCount = 0;
  bool _manualBlock = false;

  /// Esegue [action] con il loader attivo e lo spegne sempre (anche su errore).
  /// È il modo normale di usare il loader.
  Future<T> runWithProgress<T>(
    Future<T> Function() action, {
    bool blockInteraction = true,
  }) async {
    showProgress(blockInteraction: blockInteraction);
    try {
      return await action();
    } finally {
      dismissProgress(blockInteraction: blockInteraction);
    }
  }

  /// Mostra il loader. Ha un contatore: più operazioni concorrenti non si
  /// spengono a vicenda. Se l'operazione attraversa più metodi, ogni
  /// `showProgress` va chiuso da un `dismissProgress` (con gli stessi argomenti)
  /// in un `finally`.
  void showProgress({bool blockInteraction = true}) {
    if (!_mounted) return;
    _progressCount++;
    if (blockInteraction) _blockingCount++;
    _syncLayers();
  }

  /// Gemella di [showProgress]. NON chiama notifyListeners(): se lo stato è
  /// cambiato, chiamarlo esplicitamente.
  void dismissProgress({bool blockInteraction = true}) {
    if (!_mounted) return;
    if (_progressCount > 0) _progressCount--;
    if (blockInteraction && _blockingCount > 0) _blockingCount--;
    _syncLayers();
  }

  /// Blocca i tocchi senza mostrare il loader.
  void blockInteraction() {
    if (!_mounted) return;
    _manualBlock = true;
    _syncLayers();
  }

  /// Rimuove il blocco manuale dei tocchi.
  void unblockInteraction() {
    if (!_mounted) return;
    _manualBlock = false;
    _syncLayers();
  }

  void _syncLayers() {
    _progress.value = _progressCount > 0;
    _interactionBlocked.value = _blockingCount > 0 || _manualBlock;
  }

  // ---------------------------------------------------------------------------
  // Consumo di Result
  // ---------------------------------------------------------------------------

  /// Consuma un [Result] trattando tutti e tre gli stati.
  ///
  /// - [Success]: chiama [onSuccess].
  /// - [Warning]: chiama [onWarning]; se manca, segnala l'anomalia a
  ///   [ArchitecturalComponents.onWarning] e prosegue con [onSuccess].
  /// - [Failure]: l'errore passa PRIMA da `FailureHandler.handleGlobal`
  ///   (sessione scaduta, aggiornamento forzato, manutenzione: gestiti in un
  ///   punto solo). Se è gestito, si ferma. Altrimenti chiama [onFailure];
  ///   se manca, usa [presentFailure].
  ///
  /// Non fa nulla se il ViewModel è già stato disposto.
  @protected
  Future<void> consume<T>(
    Result<T> result, {
    required FutureOr<void> Function(T data) onSuccess,
    FutureOr<void> Function(T data, AppWarning anomaly)? onWarning,
    FutureOr<void> Function(AppError error)? onFailure,
  }) async {
    if (!_mounted) return;
    switch (result) {
      case Success(:final data):
        await onSuccess(data);
      case Warning(:final data, :final anomaly):
        if (onWarning != null) {
          await onWarning(data, anomaly);
        } else {
          ArchitecturalComponents.onWarning('[$runtimeType] anomalia non gestita: $anomaly');
          await onSuccess(data);
        }
      case Failure(:final error):
        final handler = ArchitecturalComponents.failureHandler;
        if (handler != null && await handler.handleGlobal(error)) return;
        if (!_mounted) return;
        if (onFailure != null) {
          await onFailure(error);
        } else {
          presentFailure(error);
        }
    }
  }

  /// Presenta un errore in modo generico tramite `FailureHandler.presentError`.
  /// Da usare come ramo di default in un `onFailure` che gestisce solo alcuni
  /// errori specifici. Senza un `FailureHandler` registrato segnala l'anomalia.
  @protected
  void presentFailure(AppError error) {
    final handler = ArchitecturalComponents.failureHandler;
    if (handler == null) {
      ArchitecturalComponents.onWarning('[$runtimeType] nessun FailureHandler registrato: errore $error non presentato');
      return;
    }
    handler.presentError(error);
  }

  // ---------------------------------------------------------------------------
  // Ciclo di vita
  // ---------------------------------------------------------------------------

  bool _mounted = true;

  /// False dopo il dispose. Controllarlo dopo ogni `await`.
  bool get mounted => _mounted;

  bool _initialized = false;

  /// True quando [initViewModel] è terminato (con successo o con errore).
  /// Serve a distinguere "non ho ancora caricato" da "caricato e vuoto".
  /// Vale solo con `autoInitViewModel` attivo nello screen.
  bool get isInitialized => _initialized;

  void _markInitialized() {
    if (_initialized || !_mounted) return;
    _initialized = true;
    notifyListeners();
  }

  bool _isScreenVisible = true;

  /// True se la screen è la pagina in primo piano. Aggiornato dallo screen.
  /// Non cambia quando sopra si aprono dialog o bottom sheet, solo quando
  /// un'altra pagina la copre.
  bool get isScreenVisible => _isScreenVisible;

  void _setScreenVisible(bool visible) => _isScreenVisible = visible;

  /// Chiamato dallo screen dopo il primo frame. Qui vanno i caricamenti
  /// iniziali, le sottoscrizioni agli stream, ecc.
  Future<void> initViewModel() async {}

  /// La screen torna in primo piano perché un'altra PAGINA sopra di essa è
  /// stata chiusa (non scatta per dialog e bottom sheet).
  @protected
  void onScreenReturned() {}

  /// Un'altra pagina è stata aperta sopra la screen.
  @protected
  void onScreenCovered() {}

  /// L'app torna in foreground mentre la screen è in primo piano.
  @protected
  void onAppResumed() {}

  @override
  void notifyListeners() {
    if (!_mounted) return;
    super.notifyListeners();
  }

  @override
  void dispose() {
    _mounted = false;
    // Chiude le richieste in attesa: gli `await request.result` riprendono e
    // trovano `mounted == false`.
    for (final request in _pendingRequests.toList()) {
      request.completeWithDefault();
    }
    _pendingRequests.clear();
    _progress.dispose();
    _interactionBlocked.dispose();
    _uiRequestController.close();
    super.dispose();
  }
}
