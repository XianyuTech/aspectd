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

  @Execute("package:example/main.dart", "_MyHomePageState", "-_incrementCounter_execute_2")
  @pragma("vm:entry-point")
  void _incrementCounter_execute_2(PointCut pointcut) {
    pointcut.proceed();
    print('KWLM called-execute-2!');
  }

  @Call("package:example/main.dart", "_MyHomePageState", "-_incrementCounter_call")
  @pragma("vm:entry-point")
  void _incrementCounter_call(PointCut pointcut) {
    pointcut.proceed();
    print('KWLM called-call!');
  }

  @Inject("package:example/main.dart", "_MyHomePageState", "-_incrementCounter_inject", lineNum: 88)
  @pragma("vm:entry-point")
  static void _incrementCounter_Inject(PointCut pointcut) {
    print('KWLM called-inject!');
  }
}