// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'test_util.dart';

final String mainDartRelativePath = p.join('example', 'lib', 'main.dart');
final String aopImplDartRelativePath =
    p.join('example', 'aspectd_impl', 'lib', 'aop_impl.dart');

// Regular Call
const String regularCallDemoMainDartContent = '''
Future<void> appInit() async {}
void main() {
  appInit();
}
''';

const String regularCallDemoAopImplDartContent = '''
import 'package:aspectd/aspectd.dart';

@Aspect()
@pragma("vm:entry-point")
class RegularCallDemo {
  @pragma("vm:entry-point")
  RegularCallDemo();

  @Call("package:example/main.dart", "", "+appInit")
  @pragma("vm:entry-point")
  static dynamic appInit(PointCut pointcut) {
    print('[KWLM1]: Before appInit!');
    dynamic object = pointcut.proceed();
    print('[KWLM1]: After appInit!');
    return object;
  }
}
''';

const String regularCallDemoExpectResultContent = '''
[KWLM1]: Before appInit!
[KWLM1]: After appInit!
''';

// Regex Call(Instance Method)
const String regexCallDemoInstanceMethodMainDartContent = '''
Future<void> appInit() async {}
Future<void> appInit2() async {}
void main() {
  appInit();
  appInit2();
}
''';

const String regexCallDemoInstanceMethodAopImplDartContent = '''
import 'package:aspectd/aspectd.dart';

@Aspect()
@pragma("vm:entry-point")
class RegexCallDemo {
  @pragma("vm:entry-point")
  RegexCallDemo();

  @Call("package:example\\/.+\\.dart", ".*", "-.+", isRegex: true)
  @pragma("vm:entry-point")
  dynamic instanceUniversalHook(PointCut pointcut) {
    print('[KWLM4]Before:\${pointcut.target}-\${pointcut.function}-\${pointcut.namedParams}-\${pointcut.positionalParams}');
    dynamic obj = pointcut.proceed();
    return obj;
  }
}
''';

const String regexCallDemoInstanceMethodExpectResultContent = '''''';

// Regex Call(Static Method)
const String regexCallDemoStaticMethodMainDartContent = '''
Future<void> appInit() async {}
Future<void> appInit2() async {}
void main() {
  appInit();
  appInit2();
}
''';

const String regexCallDemoStaticMethodAopImplDartContent = '''
import 'package:aspectd/aspectd.dart';

@Aspect()
@pragma("vm:entry-point")
class RegexCallDemo {
  @pragma("vm:entry-point")
  RegexCallDemo();

  @Call("package:example\\/.+\\.dart", ".*", "+app.*", isRegex: true)
  @pragma("vm:entry-point")
  static dynamic staticUniversalHook(PointCut pointcut) {
    print('[KWLM5]Before:\${pointcut.target}-\${pointcut.function}-\${pointcut.namedParams}-\${pointcut.positionalParams}');
    dynamic obj = pointcut.proceed();
    return obj;
  }
}
''';

const String regexCallDemoStaticMethodExpectResultContent = '''
[KWLM5]Before:package:example/main.dart-appInit-{}-[]
[KWLM5]Before:package:example/main.dart-appInit2-{}-[]
''';

// Regex Call(Mixin)
const String regexCallDemoMixinMainDartContent = '''
void main() {
  C()..fa();
}

class A {
  void fa() {}
}

class B {
  void fb() {}
}

class C with A, B {
  void fc() {}
}
''';

const String regexCallDemoMixinAopImplDartContent = '''
import 'package:aspectd/aspectd.dart';

@Aspect()
@pragma("vm:entry-point")
class RegexCallDemo {
  @pragma("vm:entry-point")
  RegexCallDemo();

  @Call('package:example\\/.+\\.dart', '.*A', '-fa', isRegex: true)
  @pragma("vm:entry-point")
  dynamic instanceUniversalHookCustomMixin(PointCut pointcut) {
    print('[KWLM6]Before:\${pointcut.target}-\${pointcut.function}-\${pointcut.namedParams}-\${pointcut.positionalParams}');
    dynamic obj = pointcut.proceed();
    return obj;
  }
}
''';

const String regexCallDemoMixinExpectResultContent = '''
[KWLM6]Before:Instance of \'C\'-fa-{}-[]
''';

// Regular Execute
const String regularExecuteDemoMainDartContent = '''
Future<void> appInit() async {}
void main() {
  appInit();
}
''';

const String regularExecuteDemoAopImplDartContent = '''
import 'package:aspectd/aspectd.dart';

@Aspect()
@pragma("vm:entry-point")
class RegularExecuteDemo {
  @pragma("vm:entry-point")
  RegularExecuteDemo();

  @Execute("package:example/main.dart", "", "+appInit", isRegex: true)
  @pragma("vm:entry-point")
  static dynamic appInitHook(PointCut pointcut) {
    print('[KWLM10]:appInitHook!');
  }
}
''';

const String regularExecuteDemoExpectResultContent = '''
[KWLM10]:appInitHook!
''';

// Regex Execute
const String regexExecuteDemoMainDartContent = '''
Future<void> appInit() async {}
Future<void> appInit2() async {}
void main() {
  appInit();
  appInit2();
}
''';

const String regexExecuteDemoAopImplDartContent = '''
import 'package:aspectd/aspectd.dart';

@Aspect()
@pragma('vm:entry-point')
class RegexExecuteDemo {
  @pragma('vm:entry-point')
  RegexExecuteDemo();

  @Execute("package:example/main.dart", "", "+^appInit.*\\\$", isRegex: true)
  @pragma("vm:entry-point")
  static dynamic appInitDemo(PointCut pointcut) {
    print('[KWLM11]:\${pointcut.function}');
  }
}
''';

const String regexExecuteDemoExpectResultContent = '''
[KWLM11]:appInit
[KWLM11]:appInit2
''';

// Regular Inject
const String regularInjectDemoMainDartContent = '''
Future<void> appInit() async {}
Future<void> appInit2() async {}

class Observer {
  void onChanged() {}
}

void injectDemo(List<Observer> observers) {
  int a = 10;
  if (a > 5) {
    print('[KWLM]:if1');
  }
  print('[KWLM]:a');
  for (Observer o in observers) {
    print('[KWLM]:Observer1');
    o.onChanged();
    print('[KWLM]:Observer2');
  }
  print('[KWLM]:b');
  for (int i = 0; i < 2; i++) {
    print('[KWLM]:for i \$i');
    print('[KWLM]:for i \$i');
  }
  print('[KWLM]:c');
}

void main() {
  injectDemo([]);
}
''';

const String regularInjectDemoAopImplDartContent = '''
import 'package:aspectd/aspectd.dart';

@Aspect()
@pragma("vm:entry-point")
class InjectDemo{
  @Inject("package:example/main.dart","","+injectDemo", lineNum:13)
  @pragma("vm:entry-point")
  static void onInjectDemoHook1() {
    print('Aspectd:KWLM17');
  }
}
''';

const String regularInjectDemoExpectResultContent = '''
[KWLM]:if1
Aspectd:KWLM17
[KWLM]:a
[KWLM]:b\
[KWLM]:for i 0
[KWLM]:for i 0
[KWLM]:for i 1
[KWLM]:for i 1
[KWLM]:c
''';

ProcessResult runAspectdForDart(
    String flutterRootDir, String dartSdkBinDir, String aspectdRoot) {
  File dillFile = File(p.join(aspectdRoot,'example','aspectd_impl.dill'));
  if (dillFile.existsSync()) {
    dillFile.deleteSync();
  }
  dillFile = File(p.join(aspectdRoot,'example','app.dill.aspectd.dill'));
  if (dillFile.existsSync()) {
    dillFile.deleteSync();
  }

  final Map<String, String> env =
      Map<String, String>.from(Platform.environment);
  env['PATH'] = '$dartSdkBinDir:${env['PATH']}';
  ProcessResult result = Process.runSync(
      'dart',
      <String>[
        '--snapshot=example/aspectd_impl.dill',
        'example/aspectd_impl/lib/aspectd_impl.dart'
      ],
      workingDirectory: aspectdRoot,
      environment: env);
  if (result.exitCode != 0) {
    return result;
  }
  final List<String> transformCommands = <String>[
    'snapshot/aspectd.dart.snapshot',
    '--input',
    'example/aspectd_impl.dill',
    '--mode',
    'dart',
    '--sdk-root',
    p.join(flutterRootDir, 'bin', 'cache', 'artifacts', 'engine', 'common',
        'flutter_patched_sdk'),
    '--output',
    'example/app.dill.aspectd.dill'
  ];
  result = Process.runSync('dart', transformCommands,
      workingDirectory: aspectdRoot, environment: env);
  if (result.exitCode != 0) {
    return result;
  }
  result = Process.runSync('dart', <String>['example/app.dill.aspectd.dill'],
      workingDirectory: aspectdRoot, environment: env);
  if (result.exitCode != 0) {
    return result;
  }
  return result;
}

void main() {
  String flutterRootDir;
  String aspectdRootDir;
  Directory tempBaseDir;
  String dartSdkBinDir;

  setUpAll(() {
    final Directory systemTemp = Directory.systemTemp;
    final String aspectdTestDirName =
        'aspectd_test_${DateTime.now().toUtc().millisecondsSinceEpoch}';
    tempBaseDir = Directory(
        p.join(systemTemp.absolute.path, aspectdTestDirName, 'AspectdTest'))
      ..createSync(recursive: true);
  });

  tearDownAll(() {
    tempBaseDir.deleteSync(recursive: true);
  });

  group('Prepare flutter&aspectd related environment', () {
    test('Make sure git command is available from path', () {
      aspectdRootDir = Directory.current.absolute.path;
      final ProcessResult processResult =
          Process.runSync('which', <String>['git']);
      expect(processResult.exitCode, equals(0));
    });
    test('Make sure flutter command is available from path', () {
      final ProcessResult processResult =
          Process.runSync('which', <String>['flutter']);
      expect(processResult.exitCode, equals(0));
      flutterRootDir = File(processResult.stdout).parent.parent.absolute.path;
    });
    test('Make sure pub command is available from flutter directory', () {
      dartSdkBinDir = p.join(flutterRootDir, 'bin', 'cache', 'dart-sdk', 'bin');
      expect(File(p.join(dartSdkBinDir, 'pub')).existsSync(), equals(true));
    });
  });

  group('Check if aspectd patch can be applied successfully', () {
    test('Make sure there are no unstaged changes for flutter git repo', () {
      final ProcessResult processResult = Process.runSync('git',<String>['status','-s'], workingDirectory: flutterRootDir);
      final String stdout = processResult.stdout??'';
      expect(stdout.length, equals(0));
    });
    test('Make sure the aspectd patch has not been applied', () {
      final String aspectdDartFile = p.join(flutterRootDir, 'packages','flutter_tools','lib','src','aspectd.dart');
      expect(File(aspectdDartFile).existsSync(), equals(false));
    });
    test('Make sure the aspectd patch has been applied successfully', () {
      final ProcessResult processResult = Process.runSync('git',<String>['apply','--3way',p.join(aspectdRootDir, '0001-aspectd.patch')], workingDirectory: flutterRootDir);
      expect(processResult.exitCode, equals(0));
    });
    test('Make sure aspectd patched flutter_tools can generate snapshot successfully', () {
      final String flutterToolsSnapshot = p.join(flutterRootDir,'bin','cache','flutter_tools.snapshot');
      Process.runSync('rm',<String>[flutterToolsSnapshot]);
      Process.runSync('flutter',<String>['devices']);
      expect(File(flutterToolsSnapshot).existsSync(), equals(true));
    });
    test('Make sure aspectd snapshot can be generated successfully', () {
      final String aspectdDartSnapshot = p.join(aspectdRootDir,'snapshot','aspectd.dart.snapshot');
      Process.runSync('rm',<String>[aspectdDartSnapshot]);
      Process.runSync('flutter',<String>['clean'], workingDirectory: p.join(aspectdRootDir,'example'));
      Process.runSync('flutter',<String>['build','apk', '--target-platform=android-arm64'], workingDirectory: p.join(aspectdRootDir,'example'));
      expect(File(aspectdDartSnapshot).existsSync(), equals(true));
    });
  });

  group(
      'Check if aspectd transformer is working expectedly(Dart instead of Flutter)',
      () {
    test('Prepare temp directory for aspectd testing', () {
      copyDirectory(Directory(p.join(aspectdRootDir)),
          tempBaseDir..createSync(recursive: true));
      final String aspectdImplPubspecLock = p.join(
          tempBaseDir.absolute.path, 'example', 'aspectd_impl', 'pubspec.lock');
      Process.runSync('rm', <String>[aspectdImplPubspecLock]);
      final Map<String, String> env =
          Map<String, String>.from(Platform.environment);
      env['PATH'] = '$dartSdkBinDir:${env['PATH']}';
      Process.runSync('pub', <String>['get', '--verbose'],
          workingDirectory:
              p.join(tempBaseDir.absolute.path, 'example', 'aspectd_impl'),
          environment: env);
      expect(File(aspectdImplPubspecLock).existsSync(), equals(true));
    });

    test('Check if aspectd for regular call is working fine', () {
      File(p.join(tempBaseDir.absolute.path, mainDartRelativePath))
          .writeAsStringSync(regularCallDemoMainDartContent);
      File(p.join(tempBaseDir.absolute.path, aopImplDartRelativePath))
          .writeAsStringSync(regularCallDemoAopImplDartContent);
      final ProcessResult processResult = runAspectdForDart(
          flutterRootDir, dartSdkBinDir, tempBaseDir.absolute.path);
      expect(processResult.stdout, equals(regularCallDemoExpectResultContent));
    });

    test('Check if aspectd for regex call(instance method) is working fine', () {
      File(p.join(tempBaseDir.absolute.path, mainDartRelativePath))
          .writeAsStringSync(regexCallDemoInstanceMethodMainDartContent);
      File(p.join(tempBaseDir.absolute.path, aopImplDartRelativePath))
          .writeAsStringSync(regexCallDemoInstanceMethodAopImplDartContent);
      final ProcessResult processResult = runAspectdForDart(
          flutterRootDir, dartSdkBinDir, tempBaseDir.absolute.path);
      expect(processResult.stdout, equals(regexCallDemoInstanceMethodExpectResultContent));
    });

    test('Check if aspectd for regex call(static method) is working fine', () {
      File(p.join(tempBaseDir.absolute.path, mainDartRelativePath))
          .writeAsStringSync(regexCallDemoStaticMethodMainDartContent);
      File(p.join(tempBaseDir.absolute.path, aopImplDartRelativePath))
          .writeAsStringSync(regexCallDemoStaticMethodAopImplDartContent);
      final ProcessResult processResult = runAspectdForDart(
          flutterRootDir, dartSdkBinDir, tempBaseDir.absolute.path);
      expect(processResult.stdout, equals(regexCallDemoStaticMethodExpectResultContent));
    });

    test('Check if aspectd for regex call(mixin) is working fine', () {
      File(p.join(tempBaseDir.absolute.path, mainDartRelativePath))
          .writeAsStringSync(regexCallDemoMixinMainDartContent);
      File(p.join(tempBaseDir.absolute.path, aopImplDartRelativePath))
          .writeAsStringSync(regexCallDemoMixinAopImplDartContent);
      final ProcessResult processResult = runAspectdForDart(
          flutterRootDir, dartSdkBinDir, tempBaseDir.absolute.path);
      expect(processResult.stdout, equals(regexCallDemoMixinExpectResultContent));
    });

    test('Check if aspectd for regular execute is working fine', () {
      File(p.join(tempBaseDir.absolute.path, mainDartRelativePath))
          .writeAsStringSync(regularExecuteDemoMainDartContent);
      File(p.join(tempBaseDir.absolute.path, aopImplDartRelativePath))
          .writeAsStringSync(regularExecuteDemoAopImplDartContent);
      final ProcessResult processResult = runAspectdForDart(
          flutterRootDir, dartSdkBinDir, tempBaseDir.absolute.path);
      expect(processResult.stdout, equals(regularExecuteDemoExpectResultContent));
    });

    test('Check if aspectd for regex execute is working fine', () {
      File(p.join(tempBaseDir.absolute.path, mainDartRelativePath))
          .writeAsStringSync(regexExecuteDemoMainDartContent);
      File(p.join(tempBaseDir.absolute.path, aopImplDartRelativePath))
          .writeAsStringSync(regexExecuteDemoAopImplDartContent);
      final ProcessResult processResult = runAspectdForDart(
          flutterRootDir, dartSdkBinDir, tempBaseDir.absolute.path);
      expect(processResult.stdout, equals(regexExecuteDemoExpectResultContent));
    });

    test('Check if aspectd for regular inject is working fine', () {
      File(p.join(tempBaseDir.absolute.path, mainDartRelativePath))
          .writeAsStringSync(regularInjectDemoMainDartContent);
      File(p.join(tempBaseDir.absolute.path, aopImplDartRelativePath))
          .writeAsStringSync(regularInjectDemoAopImplDartContent);
      final ProcessResult processResult = runAspectdForDart(
          flutterRootDir, dartSdkBinDir, tempBaseDir.absolute.path);
      expect(processResult.stdout, equals(regularInjectDemoExpectResultContent));
    });
  });
}
