import 'package:aspectd/aspectd.dart';

// @Aspect()
// @pragma("vm:entry-point")
// class RegularCallDemo {
//   @pragma("vm:entry-point")
//   RegularCallDemo();
//
//   @Call("package:example/main.dart", "", "+appInit")
//   @pragma("vm:entry-point")
//   static dynamic appInit(PointCut pointcut) {
//     print('[KWLM1]: Before appInit!');
//     dynamic object = pointcut.proceed();
//     print('[KWLM1]: After appInit!');
//     return object;
//   }
//
//   @Call("package:example/main.dart", "MyApp", "+MyApp")
//   @pragma("vm:entry-point")
//   static dynamic myAppDefine(PointCut pointcut) {
//     print('[KWLM2]: MyApp default constructor!');
//     return pointcut.proceed();
//   }
//
//   @Call("package:example/main.dart", "MyHomePage", "+MyHomePage")
//   @pragma("vm:entry-point")
//   static dynamic myHomePage(PointCut pointcut) {
//     dynamic obj = pointcut.proceed();
//     print('[KWLM3]: MyHomePage named constructor!');
//     return obj;
//   }
// }
//

// @Aspect()
// @pragma("vm:entry-point")
// class RegexCallDemo {
//   @pragma("vm:entry-point")
//   RegexCallDemo();
//
//  @Call("package:example\\/.+\\.dart", ".*", "-.+", isRegex: true)
//  @pragma("vm:entry-point")
//  dynamic instanceUniversalHook(PointCut pointcut) {
//    print('[KWLM11]Before:${pointcut.target}-${pointcut.function}-${pointcut.namedParams}-${pointcut.positionalParams}');
//    dynamic obj = pointcut.proceed();
//    return obj;
//  }
//
//  @Call('package:example\\/.+\\.dart', '.*A', '-fa', isRegex: true)
//  @pragma("vm:entry-point")
//  dynamic instanceUniversalHookCustomMixin(PointCut pointcut) {
//    print('[KWLM12]Before:${pointcut.target}-${pointcut.function}-${pointcut.namedParams}-${pointcut.positionalParams}');
//    dynamic obj = pointcut.proceed();
//    return obj;
//  }
// }

// @Aspect()
// @pragma("vm:entry-point")
// class RegularExecuteDemo {
//   @pragma("vm:entry-point")
//   RegularExecuteDemo();
//
//   @Execute("package:example/main.dart", "_MyHomePageState", "-_incrementCounter")
//   @pragma("vm:entry-point")
//   dynamic _incrementCounter(PointCut pointcut) {
//     dynamic obj = pointcut.proceed();
//     print('[KWLM21]:${pointcut.sourceInfos}:${pointcut.target}:${pointcut.function}!');
//     return obj;
//   }
//
//   @Execute("dart:math", "Random", "-next.*", isRegex: true)
//   @pragma("vm:entry-point")
//   static dynamic randomNext(PointCut pointcut) {
//     print('[KWLM22]:randomNext!');
//     return 10;
//   }
// }
//
// @Aspect()
// @pragma('vm:entry-point')
// class RegexExecuteDemo {
//   @pragma('vm:entry-point')
//   RegexExecuteDemo();
//
//  @Execute('package:example\\/.+\\.dart', '.*A', '-fa', isRegex: true)
//  @pragma('vm:entry-point')
//  dynamic instanceUniversalHookCustomMixin(PointCut pointcut) {
//    print(
//        '[KWLM31]Before:${pointcut.target}-${pointcut.function}-${pointcut.namedParams}-${pointcut.positionalParams}');
//    final dynamic obj = pointcut.proceed();
//    return obj;
//  }
// }

@Aspect()
@pragma("vm:entry-point")
class InjectDemo{
 @Inject("package:example/main.dart","","+injectDemo", lineNum:27)
 @pragma("vm:entry-point")
 static void onInjectDemoHook1() {
   print('Aspectd:KWLM41');
 }

 @Inject("package:example/main.dart","C","+C", lineNum:195)
 @pragma("vm:entry-point")
 static void onInjectDemoHook3() {
   print('Aspectd:KWLM42');
 }
}