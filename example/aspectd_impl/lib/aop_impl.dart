import 'package:aspectd/aspectd.dart';

@Aspect()
@pragma("vm:entry-point")
class CallDemo {
  @pragma("vm:entry-point")
  CallDemo();

  @Call("package:example/main.dart", "", "+appInit")
  @pragma("vm:entry-point")
  static dynamic appInit(PointCut pointcut) {
    print('[KWLM]1: Before appInit!');
    dynamic object = pointcut.proceed();
    print('[KWLM]1: After appInit!');
    return object;
  }

  @Call("package:example/main.dart", "MyApp", "+MyApp")
  @pragma("vm:entry-point")
  static dynamic myAppDefine(PointCut pointcut) {
    print('[KWLM]2: MyApp default constructor!');
    return pointcut.proceed();
  }

  @Call("package:example/main.dart", "MyHomePage", "+MyHomePage")
  @pragma("vm:entry-point")
  static dynamic myHomePage(PointCut pointcut) {
    dynamic obj = pointcut.proceed();
    print('[KWLM]3: MyHomePage named constructor!');
    return obj;
  }
}

@Aspect()
@pragma("vm:entry-point")
class ExecuteDemo {
  @pragma("vm:entry-point")
  ExecuteDemo();

  @Execute("package:example/main.dart", "_MyHomePageState", "-_incrementCounter")
  @pragma("vm:entry-point")
  dynamic _incrementCounter(PointCut pointcut) {
    dynamic obj = pointcut.proceed();
    print('[KWLM]4: Around _incrementCounter!');
    return obj;
  }

  @Execute("package:flutter/src/gestures/recognizer.dart",
      "GestureRecognizer", "-invokeCallback")
  @pragma("vm:entry-point")
  dynamic hookinvokeCallback(PointCut pointcut) {
    print("[KWLM]5: invokeCallback");
    return pointcut.proceed();
  }

//  @Execute("package:example/main.dart", "MyApp", "+MyApp")
//  @pragma("vm:entry-point")
//  static dynamic MyAppDefine(PointCut pointcut) {
//    print('[KWLM]6: MyApp default constructor!');
//    return pointcut.proceed();
//  }
}