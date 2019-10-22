import 'package:aspectd/aspectd.dart';

//@Aspect()
//@pragma("vm:entry-point")
//class CallDemo {
//  @pragma("vm:entry-point")
//  CallDemo();
//
//  @Call("package:example/main.dart", "", "+appInit")
//  @pragma("vm:entry-point")
//  static dynamic appInit(PointCut pointcut) {
//    print('[KWLM]1: Before appInit!');
//    dynamic object = pointcut.proceed();
//    print('[KWLM]1: After appInit!');
//    return object;
//  }
//
//  @Call("package:example/main.dart", "MyApp", "+MyApp")
//  @pragma("vm:entry-point")
//  static dynamic myAppDefine(PointCut pointcut) {
//    print('[KWLM]2: MyApp default constructor!');
//    return pointcut.proceed();
//  }
//
//  @Call("package:example/main.dart", "MyHomePage", "+MyHomePage")
//  @pragma("vm:entry-point")
//  static dynamic myHomePage(PointCut pointcut) {
//    dynamic obj = pointcut.proceed();
//    print('[KWLM]3: MyHomePage named constructor!');
//    return obj;
//  }
//}
//
//@Aspect()
//@pragma("vm:entry-point")
//class RegularExecuteDemo {
//  @pragma("vm:entry-point")
//  RegularExecuteDemo();
//
//  @Execute("package:example/main.dart", "_MyHomePageState", "-_incrementCounter")
//  @pragma("vm:entry-point")
//  dynamic _incrementCounter(PointCut pointcut) {
//    dynamic obj = pointcut.proceed();
//    print('[KWLM]4:${pointcut.sourceInfos}:${pointcut.target}:${pointcut.function}!');
//    return obj;
//  }
//
//  @Execute("package:flutter/src/gestures/recognizer.dart",
//      "GestureRecognizer", "-invokeCallback")
//  @pragma("vm:entry-point")
//  dynamic hookinvokeCallback(PointCut pointcut) {
//    print("[KWLM]5: invokeCallback");
//    return pointcut.proceed();
//  }
//
//  @Execute("dart:math", "Random", "-next.*", isRegex: true)
//  @pragma("vm:entry-point")
//  static dynamic randomNext(PointCut pointcut) {
//    print('[KWLM]6:randomNext!');
//    return 10;
//  }
//}

@Aspect()
@pragma("vm:entry-point")
class RegexExecuteDemo {
  @pragma("vm:entry-point")
  RegexExecuteDemo();

  @Execute("package:example\\/.+\\.dart", ".*", "-.+", isRegex: true)
  @pragma("vm:entry-point")
  dynamic instanceUniversalHook(PointCut pointcut) {
    print('[KWLM7]Before:${pointcut.target}-${pointcut.function}-${pointcut.namedParams}-${pointcut.positionalParams}');
    dynamic obj = pointcut.proceed();
    return obj;
  }

  @Execute("package:example\\/.+\\.dart", ".*", "+.+", isRegex: true)
  @pragma("vm:entry-point")
  dynamic staticUniversalHook(PointCut pointcut) {
    print('[KWLM8]Before:${pointcut.target}-${pointcut.function}-${pointcut.namedParams}-${pointcut.positionalParams}');
    dynamic obj = pointcut.proceed();
    return obj;
  }
}