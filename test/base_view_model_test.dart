import 'package:architectural_components/architectural_components.dart';
import 'package:flutter_test/flutter_test.dart';

class _BoolRequest extends UiRequest<bool> {
  @override
  bool get defaultResult => false;
}

class _Vm extends BaseViewModel {
  void emit(UiRequest request) => emitUiRequest(request);
}

void main() {
  setUp(() {
    // Silenzia gli avvisi nei test.
    ArchitecturalComponents.onWarning = (_) {};
  });

  test('senza ascoltatori la richiesta si chiude con il default', () async {
    final vm = _Vm();
    addTearDown(vm.dispose);
    final request = _BoolRequest();
    vm.emit(request);
    expect(await request.result, isFalse);
  });

  test('il dispose chiude con il default le richieste in attesa', () async {
    final vm = _Vm();
    final sub = vm.uiRequests.listen((_) {});
    final request = _BoolRequest();
    vm.emit(request);
    vm.dispose();
    expect(await request.result, isFalse);
    await sub.cancel();
  });

  test('il loader ha un contatore: la prima fine non spegne la seconda operazione', () {
    final vm = _Vm();
    addTearDown(vm.dispose);
    vm.showProgress();
    vm.showProgress();
    vm.dismissProgress();
    expect(vm.progress.value, isTrue);
    vm.dismissProgress();
    expect(vm.progress.value, isFalse);
  });

  test('blockInteraction: false mostra il loader senza bloccare i tocchi', () {
    final vm = _Vm();
    addTearDown(vm.dispose);
    vm.showProgress(blockInteraction: false);
    expect(vm.progress.value, isTrue);
    expect(vm.interactionBlocked.value, isFalse);
  });

  test('runWithProgress spegne il loader anche se l\'azione lancia', () async {
    final vm = _Vm();
    addTearDown(vm.dispose);
    await expectLater(
      vm.runWithProgress<void>(() async => throw StateError('boom')),
      throwsStateError,
    );
    expect(vm.progress.value, isFalse);
  });
}
