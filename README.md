# architectural_components

Classi base dell'architettura MVVM per le app Flutter mobile: una Screen è servita da un solo ViewModel; tutta la logica sta nel ViewModel, la Screen costruisce widget.

> Stato: **non compilato né testato** al momento della scrittura. Prima di taggare `v1.0.0` esegui `flutter pub get`, `flutter analyze` e `flutter test` nella cartella del package.

## Requisiti

- Dart `^3.6.0`, Flutter `>=3.27.0` (usa `Color.withValues` e `PopScope.onPopInvokedWithResult`).
- `provider` `^6.1.2`.

## Installazione (dipendenza da git)

```yaml
dependencies:
  architectural_components:
    git:
      url: <url-del-repository>/architectural_components.git
      ref: v1.0.0          # tag semantico: non puntare mai a un branch
```

In sviluppo locale: `path: ../architectural_components`.

## Setup nell'app

```dart
import 'package:architectural_components/architectural_components.dart';

void main() {
  // opzionale: manda gli avvisi del package al logger di progetto
  ArchitecturalComponents.onWarning = (m) => MobileLoggerManager().log.w(m);
  runApp(const MyApp());
}
```

Nel router, l'observer delle pagine è obbligatorio:

```dart
GoRouter(
  observers: [BaseScreenState.routeObserver /* , altri observer */],
  routes: [ /* ... */ ],
);
```

## API pubblica

| Simbolo | Ruolo |
|---|---|
| `BaseViewModel` | Stato e logica; loader (`runWithProgress`), `emitUiRequest`, hook `initViewModel`, `onScreenReturned`, `onScreenCovered`, `onAppResumed`, `isInitialized`, `isScreenVisible`, `mounted` |
| `BaseScreenState<VM, W>` | Collegamento VM↔Screen; implementa `buildBody`, opzionale `buildScaffold`, `handleUiRequest`, `onSystemBack` |
| `UiRequest<T>` / `UiVoidRequest` | Richieste del VM verso la UI (dialog, sheet) |
| `ArchitecturalLayers` | Layer di loader e blocco input |
| `EdgeSwipeBackGuard` | Swipe-back iOS quando il pop è bloccato |
| `ArchitecturalComponents.onWarning` | Hook per le anomalie non fatali |

Regole d'uso, template e migrazione: nei documenti/skill dell'architettura (non in questo package).

## Versionamento

Semver. Ogni rottura dell'API pubblica (rinomine, firme, comportamenti) alza la major e va annotata in `CHANGELOG.md` con le istruzioni di migrazione. I progetti aggiornano il tag in modo esplicito.
