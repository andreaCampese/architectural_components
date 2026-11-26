import 'package:architectural_components/architectural_components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _Vm extends BaseViewModel {
  int initCalls = 0;
  int taps = 0;

  @override
  Future<void> initViewModel() async {
    initCalls++;
  }
}

class _Screen extends StatefulWidget {
  const _Screen();

  @override
  State<_Screen> createState() => _ScreenState();
}

class _ScreenState extends BaseScreenState<_Vm, _Screen> {
  @override
  Widget buildBody(BuildContext context) {
    return Column(
      children: [
        Text(viewModel.isInitialized ? 'pronto' : 'carico'),
        ElevatedButton(onPressed: () => viewModel.taps++, child: const Text('tap')),
      ],
    );
  }
}

Widget _app(_Vm vm) => MaterialApp(
  home: ChangeNotifierProvider<_Vm>.value(value: vm, child: const _Screen()),
);

void main() {
  testWidgets('initViewModel parte dopo il primo frame e isInitialized diventa true', (tester) async {
    final vm = _Vm();
    addTearDown(vm.dispose);

    await tester.pumpWidget(_app(vm));
    expect(find.text('carico'), findsOneWidget);

    await tester.pumpAndSettle();
    expect(vm.initCalls, 1);
    expect(find.text('pronto'), findsOneWidget);
  });

  testWidgets('il loader che blocca assorbe i tocchi, quello senza blocco no', (tester) async {
    final vm = _Vm();
    addTearDown(vm.dispose);

    await tester.pumpWidget(_app(vm));
    await tester.pumpAndSettle();

    vm.showProgress();
    await tester.pump();
    await tester.tap(find.text('tap'), warnIfMissed: false);
    await tester.pump();
    expect(vm.taps, 0);

    vm.dismissProgress();
    await tester.pump();

    vm.showProgress(blockInteraction: false);
    await tester.pump();
    await tester.tap(find.text('tap'));
    await tester.pump();
    expect(vm.taps, 1);
  });
}
