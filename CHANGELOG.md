# Changelog

## 1.1.0

Additiva, nessuna rottura rispetto alla 1.0.0.

- Nuova dipendenza: `app_result` (package Dart puro con `Result<T>`). **Sostituisci l'URL git nel `pubspec.yaml`.**
- `BaseViewModel.consume`: consuma un `Result` trattando Success/Warning/Failure; gli errori passano prima dal gestore globale.
- `BaseViewModel.presentFailure`: presentazione generica di un errore, ramo di default per un `onFailure` specifico.
- `FailureHandler` (interfaccia) e `ArchitecturalComponents.failureHandler`: gestione centralizzata degli errori trasversali.

## 1.0.0

- Prima versione: `BaseScreenState`, `BaseViewModel`, `UiRequest` / `UiVoidRequest`, `ArchitecturalLayers`, `EdgeSwipeBackGuard`, `ArchitecturalComponents.onWarning`.
