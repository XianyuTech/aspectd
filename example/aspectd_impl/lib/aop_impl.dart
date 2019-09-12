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
    print('[KWLM]1: appInit!');
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
    print('[KWLM]2: _incrementCounter!');
  }

  @Execute("package:flutter/src/gestures/recognizer.dart",
      "GestureRecognizer", "-invokeCallback")
  @pragma("vm:entry-point")
  dynamic hookinvokeCallback(PointCut pointcut) {
    var raw = pointcut.positionalParams[0];
    print("[KWLM]3: invokeCallback");
    return pointcut.proceed();
  }
}