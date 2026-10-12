import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otp_guard/app/cubit_listenable.dart';

class _Counter extends Cubit<int> {
  _Counter() : super(0);
}

void main() {
  test('notifies at each state of the cubit', () async {
    final cubit = _Counter();
    final listenable = CubitListenable(cubit);
    var notified = 0;
    listenable.addListener(() => notified++);

    cubit
      ..emit(1)
      ..emit(2);
    await pumpEventQueue();

    expect(notified, 2);
    listenable.dispose();
    await cubit.close();
  });

  test('does not notify again for a state that is the same', () async {
    final cubit = _Counter();
    final listenable = CubitListenable(cubit);
    var notified = 0;
    listenable.addListener(() => notified++);

    cubit
      ..emit(1)
      ..emit(1);
    await pumpEventQueue();

    expect(notified, 1);
    listenable.dispose();
    await cubit.close();
  });

  test('stops after it is disposed', () async {
    final cubit = _Counter();
    final listenable = CubitListenable(cubit);
    var notified = 0;
    listenable
      ..addListener(() => notified++)
      ..dispose();

    cubit.emit(1);
    await pumpEventQueue();

    expect(notified, 0);
    await cubit.close();
  });
}
