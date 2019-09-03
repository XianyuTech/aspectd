import 'package:aspectd/aspectd.dart';

@Aspect()
@pragma("vm:entry-point")
class CallDemo {
  @pragma("vm:entry-point")
  CallDemo();

  @Call("package:example/main.dart", "", "+appInit")
  @pragma("vm:entry-point")
  static void appInit(PointCut pointcut) {
    pointcut.proceed();
    print('[KWLM1] called!');
  }
}

@Aspect()
@pragma("vm:entry-point")
class ExecuteDemo {
  @pragma("vm:entry-point")
  ExecuteDemo();

  @Execute("package:example/main.dart", "_MyHomePageState", "-_incrementCounter")
  @pragma("vm:entry-point")
  void _onPluginDemo(PointCut pointcut) {
    pointcut.proceed();
    print('[KWLM2] called!');
  }
}