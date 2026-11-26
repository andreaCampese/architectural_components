part of '../architectural_components.dart';

/// Base per le screen: collega il ViewModel (via Provider), gestisce il ciclo
/// di vita, applica la SafeArea al body e i layer di loader/blocco input.
///
/// Una screen implementa [buildBody] e, se serve uno Scaffold con AppBar,
/// barra inferiore, ecc., sovrascrive [buildScaffold]. Non si sovrascrive `build`.
///
/// [T]: ViewModel della screen. [W]: StatefulWidget associato.
abstract class BaseScreenState<T extends BaseViewModel, W extends StatefulWidget> extends State<W>
    with RouteAware, WidgetsBindingObserver {
  /// Observer delle pagine, da registrare in `GoRouter(observers: [...])`.
  /// Alimenta `isScreenVisible`, `onScreenReturned` e `onScreenCovered` del
  /// ViewModel. Tipizzato su [PageRoute]: dialog e bottom sheet non contano.
  static final RouteObserver<PageRoute<void>> routeObserver = RouteObserver<PageRoute<void>>();

  /// ViewModel recuperato da Provider in [didChangeDependencies].
  late T viewModel;

  bool _viewModelAttached = false;
  StreamSubscription<UiRequest>? _uiRequestSubscription;
  PageRoute<void>? _route;

  // ---------------------------------------------------------------------------
  // Configurazione (override opzionale)
  // ---------------------------------------------------------------------------

  /// Se true, chiama [BaseViewModel.initViewModel] dopo il primo frame.
  bool get autoInitViewModel => true;

  bool get safeAreaTop => true;
  bool get safeAreaBottom => false;
  bool get safeAreaLeft => false;
  bool get safeAreaRight => false;
  EdgeInsets get safeAreaMinimum => EdgeInsets.zero;
  bool get safeAreaMaintainBottomViewPadding => false;

  /// Colore di sfondo del layer di caricamento.
  Color get progressBackgroundColor => Colors.transparent;

  /// Widget mostrato durante il caricamento.
  Widget get progressWidget => const CircularProgressIndicator();

  /// Stile delle barre di sistema (sfondo chiaro). Le barre restano
  /// trasparenti. AppBar e barre inferiori possono sovrascriverlo per sé.
  SystemUiOverlayStyle get systemOverlayStyle => const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.dark,
    systemNavigationBarContrastEnforced: false,
  );

  /// Azione al posto del pop quando l'utente usa il back di sistema.
  /// Null (default) = comportamento nativo. Su iOS, con il pop bloccato, lo
  /// swipe-back viene ricostruito da [EdgeSwipeBackGuard].
  VoidCallback? get onSystemBack => null;

  // ---------------------------------------------------------------------------
  // Costruzione della UI
  // ---------------------------------------------------------------------------

  /// Contenuto della screen. Obbligatorio. La SafeArea è applicata dalla base.
  Widget buildBody(BuildContext context);

  /// Costruisce lo Scaffold attorno a [body] (già dentro la SafeArea).
  ///
  /// Default: `Scaffold(body: body)`. Le screen con AppBar, barra inferiore,
  /// FAB, drawer, ecc. lo sovrascrivono e restituiscono il proprio Scaffold
  /// passando `body: body`: l'API di Scaffold è disponibile per intero, senza
  /// che la base ne copi i parametri.
  Widget buildScaffold(BuildContext context, Widget body) => Scaffold(body: body);

  /// NON sovrascrivere: l'architettura (SafeArea, loader, blocco input, back)
  /// vive qui.
  @override
  @mustCallSuper
  Widget build(BuildContext context) {
    final safeBody = SafeArea(
      top: safeAreaTop,
      bottom: safeAreaBottom,
      left: safeAreaLeft,
      right: safeAreaRight,
      minimum: safeAreaMinimum,
      maintainBottomViewPadding: safeAreaMaintainBottomViewPadding,
      child: buildBody(context),
    );

    // I layer coprono l'intero schermo, AppBar inclusa.
    final layeredUI = ArchitecturalLayers(
      progress: viewModel.progress,
      interactionBlocked: viewModel.interactionBlocked,
      progressBackgroundColor: progressBackgroundColor,
      progressWidget: progressWidget,
      child: buildScaffold(context, safeBody),
    );

    final onBack = onSystemBack;

    final Widget content = (defaultTargetPlatform == TargetPlatform.iOS && onBack != null)
        ? EdgeSwipeBackGuard(onTriggered: onBack, child: layeredUI)
        : layeredUI;

    // Durante un loader che blocca l'input il back di sistema è ignorato.
    return ValueListenableBuilder<bool>(
      valueListenable: viewModel.interactionBlocked,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: systemOverlayStyle,
        child: content,
      ),
      builder: (context, blocked, child) {
        return PopScope(
          canPop: onBack == null && !blocked,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop || blocked) return;
            onBack?.call();
          },
          child: child!,
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Ciclo di vita
  // ---------------------------------------------------------------------------

  @override
  @mustCallSuper
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (autoInitViewModel) {
      // Dopo il primo frame: il context è pronto e non si interrompe il build.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _runInitViewModel();
      });
    }
  }

  Future<void> _runInitViewModel() async {
    try {
      await viewModel.initViewModel();
    } catch (error, stack) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'architectural_components',
          context: ErrorDescription('durante initViewModel() di ${viewModel.runtimeType}'),
        ),
      );
    } finally {
      if (mounted) viewModel._markInitialized();
    }
  }

  /// Recupera il ViewModel e, alla prima associazione (o al cambio di istanza),
  /// si iscrive a `uiRequests`. Con `Provider.of` in modalità listen questo
  /// metodo scatta a ogni notifyListeners: il controllo `identical` evita
  /// sottoscrizioni duplicate. Iscrive inoltre lo screen all'observer delle pagine.
  @override
  @mustCallSuper
  void didChangeDependencies() {
    super.didChangeDependencies();

    final resolved = Provider.of<T>(context);
    if (!_viewModelAttached || !identical(resolved, viewModel)) {
      _uiRequestSubscription?.cancel();
      viewModel = resolved;
      _viewModelAttached = true;
      _uiRequestSubscription = viewModel.uiRequests.listen(handleUiRequest);
    }

    final route = ModalRoute.of<void>(context);
    if (route is PageRoute<void> && !identical(route, _route)) {
      routeObserver.unsubscribe(this);
      _route = route;
      routeObserver.subscribe(this, route);
    }
  }

  /// Un'altra pagina sopra questa è stata chiusa: la screen è di nuovo in primo piano.
  @override
  void didPopNext() {
    viewModel._setScreenVisible(true);
    viewModel.onScreenReturned();
  }

  /// Un'altra pagina è stata aperta sopra questa.
  @override
  void didPushNext() {
    viewModel._setScreenVisible(false);
    viewModel.onScreenCovered();
  }

  /// Questa pagina sta uscendo.
  @override
  void didPop() => viewModel._setScreenVisible(false);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed && viewModel.isScreenVisible) {
      viewModel.onAppResumed();
    }
  }

  /// Gestisce le [UiRequest] emesse dal ViewModel. Gli screen la sovrascrivono
  /// con uno `switch` sui propri tipi e delegano a `super.handleUiRequest(request)`
  /// il caso `default`. Qui è il fallback di sicurezza: chiude la richiesta con
  /// il suo default (nessun `await` appeso), segnala l'anomalia tramite
  /// [ArchitecturalComponents.onWarning] e, in debug, fa fallire un assert.
  @protected
  @mustCallSuper
  void handleUiRequest(UiRequest request) {
    request.completeWithDefault();
    final message =
        'UiRequest ${request.runtimeType} non gestita in $runtimeType: override handleUiRequest e aggiungi un case per questo tipo.';
    ArchitecturalComponents.onWarning(message);
    assert(false, message);
  }

  @override
  @mustCallSuper
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    routeObserver.unsubscribe(this);
    _uiRequestSubscription?.cancel();
    super.dispose();
  }
}
