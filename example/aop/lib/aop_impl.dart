import 'package:aspectd/aspectd.dart';

@Aspect()
@pragma("vm:entry-point")
class ExecuteDemo {
  @pragma("vm:entry-point")
  ExecuteDemo();

  @Execute("package:example/main.dart", "_MyHomePageState", "-_incrementCounter_execute")
  @pragma("vm:entry-point")
  void _incrementCounter(PointCut pointcut) {
    pointcut.proceed();
    print('KWLM called-execute!');
  }

  @Call("package:example/main.dart", "_MyHomePageState", "-_incrementCounter_call")
  @pragma("vm:entry-point")
  void _incrementCounter_call(PointCut pointcut) {
    pointcut.proceed();
    print('KWLM called-call!');
  }
}