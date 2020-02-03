import 'package:aspectd/aspectd.dart';

@Aspect()
@pragma("vm:entry-point")
class RegularCallDemo {
  @pragma("vm:entry-point")
  RegularCallDemo();

//  @Call("package:example/main.dart", "", "+appInit")
//  @pragma("vm:entry-point")
//  static dynamic appInit(PointCut pointcut) {
//    print('[KWLM1]: Before appInit!');
//    dynamic object = pointcut.proceed();
//    print('[KWLM1]: After appInit!');
//    return object;
//  }
//
  @Call("package:example/main.dart", "MyApp", "+MyApp")
  @pragma("vm:entry-point")
  static dynamic myAppDefine(PointCut pointcut) {
    print('[KWLM2]: MyApp default constructor!');
    return pointcut.proceed();
  }
}

//@Aspect()
//@pragma("vm:entry-point")
//class RegexCallDemo {
//  @pragma("vm:entry-point")
//  RegexCallDemo();
//
//  @Call("package:example\\/.+\\.dart", ".*", "-.+", isRegex: true)
//  @pragma("vm:entry-point")
//  dynamic instanceUniversalHook(PointCut pointcut) {
//    print('[KWLM4]Before:${pointcut.target}-${pointcut.function}-${pointcut.namedParams}-${pointcut.positionalParams}');
//    dynamic obj = pointcut.proceed();
//    return obj;
//  }

//  @Call("package:example\\/.+\\.dart", ".*", "+app.*", isRegex: true)
//  @pragma("vm:entry-point")
//  static dynamic staticUniversalHook(PointCut pointcut) {
//    print('[KWLM5]Before:${pointcut.target}-${pointcut.function}-${pointcut.namedParams}-${pointcut.positionalParams}');
//    dynamic obj = pointcut.proceed();
//    return obj;
//  }
//
//  @Call('package:example\\/.+\\.dart', '.*A', '-fa', isRegex: true)
//  @pragma("vm:entry-point")
//  dynamic instanceUniversalHookCustomMixin(PointCut pointcut) {
//    print('[KWLM6]Before:${pointcut.target}-${pointcut.function}-${pointcut.namedParams}-${pointcut.positionalParams}');
//    dynamic obj = pointcut.proceed();
//    return obj;
//  }
//
//  @Call('package:flutter\\/.+\\.dart', '.*', '-^dispatchEvent\$', isRegex: true)
//  @pragma('vm:entry-point')
//  dynamic instanceUniversalHookFlutterMixin(PointCut pointcut) {
//    print(
//        '[KWLM7]Before:${pointcut.target}-${pointcut.function}-${pointcut.namedParams}-${pointcut.positionalParams}');
//    final dynamic obj = pointcut.proceed();
//    return obj;
//  }
//}

@Aspect()
@pragma("vm:entry-point")
class RegularExecuteDemo {
  @pragma("vm:entry-point")
  RegularExecuteDemo();

//  @Execute("package:example/main.dart", "_MyHomePageState", "-_incrementCounter")
//  @pragma("vm:entry-point")
//  dynamic _incrementCounter(PointCut pointcut) {
//    dynamic obj = pointcut.proceed();
//    print('[KWLM8]:${pointcut.sourceInfos}:${pointcut.target}:${pointcut.function}!');
//    return obj;
//  }
//
//  @Execute("package:flutter/src/gestures/recognizer.dart",
//      "GestureRecognizer", "-invokeCallback")
//  @pragma("vm:entry-point")
//  dynamic hookinvokeCallback(PointCut pointcut) {
//    print("[KWLM9]: invokeCallback");
//    return pointcut.proceed();
//  }
//

  //Valid only in flutter release mode
  @Execute("dart:math", "Random", "-^next.*\$", isRegex: true)
  @pragma("vm:entry-point")
  static dynamic randomHook(PointCut pointcut) {
    print('[KWLM11]:randomHook!');
    return 10;
  }
}

//@Aspect()
//@pragma('vm:entry-point')
//class RegexExecuteDemo {
//  @pragma('vm:entry-point')
//  RegexExecuteDemo();
//
//  @Execute("package:example/main.dart", "", "+^appInit.*\\\$", isRegex: true)
//  @pragma("vm:entry-point")
//  static dynamic appInitDemo(PointCut pointcut) {
//    print('[KWLM11]:\${pointcut.function}');
//  }

//  @Execute('package:example\\/.+\\.dart', '.*', '-.+', isRegex: true)
//  @pragma('vm:entry-point')
//  dynamic instanceUniversalHook(PointCut pointcut) {
//    print(
//        '[KWLM12]Before:${pointcut.target}-${pointcut.function}-${pointcut.namedParams}-${pointcut.positionalParams}');
//    final dynamic obj = pointcut.proceed();
//    return obj;
//  }
//
//  @Execute('package:example\\/.+\\.dart', '.*', '+.+', isRegex: true)
//  @pragma('vm:entry-point')
//  static dynamic staticUniversalHook(PointCut pointcut) {
//    print(
//        '[KWLM13]Before:${pointcut.target}-${pointcut.function}-${pointcut.namedParams}-${pointcut.positionalParams}');
//    final dynamic obj = pointcut.proceed();
//    return obj;
//  }
//
//  @Execute('package:example\\/.+\\.dart', '.*A', '-fa', isRegex: true)
//  @pragma('vm:entry-point')
//  dynamic instanceUniversalHookCustomMixin(PointCut pointcut) {
//    print(
//        '[KWLM14]Before:${pointcut.target}-${pointcut.function}-${pointcut.namedParams}-${pointcut.positionalParams}');
//    final dynamic obj = pointcut.proceed();
//    return obj;
//  }
//
//  @Execute('package:flutter\\/.+\\.dart', '_([^&]*&)*GestureBinding([^&]*&)*', '-^dispatchEvent\$', isRegex: true)
//  @pragma('vm:entry-point')
//  dynamic instanceUniversalHookFlutterMixin(PointCut pointcut) {
//    print(
//        '[KWLM15]Before:${pointcut.target}-${pointcut.function}-${pointcut.namedParams}-${pointcut.positionalParams}');
//    final dynamic obj = pointcut.proceed();
//    return obj;
//  }
//}

//@Aspect()
//@pragma("vm:entry-point")
//class InjectDemo{
//  @Inject("package:flutter/src/widgets/gesture_detector.dart","GestureDetector","-build", lineNum:452)
//  @pragma("vm:entry-point")
//  static void onTapBuild() {
//    Object instance; //Aspectd Ignore
//    Object context; //Aspectd Ignore
//    print(instance);
//    print(context);
//    print('Aspectd:KWLM16');
//  }
//  @Inject("package:example/main.dart","","+injectDemo", lineNum:15)
//  @pragma("vm:entry-point")
//  static void onInjectDemoHook1() {
//    print('Aspectd:KWLM17');
//  }
//
//  @Inject("package:example/main.dart","","+injectDemo", lineNum:16)
//  @pragma("vm:entry-point")
//  static void onInjectDemoHook2() {
//    print('Aspectd:KWLM18');
//  }
//
//  @Inject("package:example/main.dart","","+injectDemo", lineNum:26)
//  @pragma("vm:entry-point")
//  static void onInjectDemoHook3() {
//    print('Aspectd:KWLM19');
//  }
//  @Inject("package:example/main.dart","","+injectDemo", lineNum:28)
//  @pragma("vm:entry-point")
//  static void onInjectDemoHook3() {
//    print('Aspectd:KWLM20');
//  }
//}
