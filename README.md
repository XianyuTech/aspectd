# AspectD

Salute to AspectJ.

AspectD is an AOP(aspect oriented programming) framework for dart. Like other traditional aop framework,   AspectD provides call&execute grammar. Besides, as we can't use dart:mirrors in flutter, AspectD also provides a  way named inject enhancing the dart code manipulation.

# Design

![Aspectd Diagram](https://gw.alicdn.com/bao/uploaded/TB1RjKyRAzoK1RjSZFlXXai4VXa-720-150.png)

Suppose you have a flutter project called hello_flutter located in hf_dir.

# Installation

## 1. Create a dart package named aop in hf_dir/hello_flutter

```dart
flutter create --template=package aop
```

## 2. Add aspectd&hello_flutter dependency to aop package
```dart
dependencies:
  flutter:
    sdk: flutter
  aspectd:
    git:
      url: git@github.com:alibaba-flutter/aspectd.git
      ref: master
  hello_flutter:
    path: ../
```
Fetch package dependency in aop package

```dart
flutter packages get
```
## 3. Modify aop package

aop.dart(entrypoint)
```dart
import 'package:hello_flutter/main.dart' as app;
import 'aop_impl.dart';

void main()=> app.main();
```
aop_impl.dart(aop implementation)
```dart
import 'package:aspectd/aspectd.dart';

@Aspect()
@pragma("vm:entry-point")
class ExecuteDemo {
  @pragma("vm:entry-point")
  ExecuteDemo();

  @Execute("package:hello_flutter/main.dart", "_MyHomePageState", "-_incrementCounter")
  @pragma("vm:entry-point")
  void _incrementCounter(PointCut pointcut) {
    pointcut.proceed();
    print('KWLM called!');
  }
}
```

## 4. Compile transformer snapshot for aspectd

As the flutter(dart) environment may vary for different developers, the aspectd transformer snapshot might need to be recompiled by developers manually.

### a. Get the right dart-sdk version(sha commit)

Get engine version:(**7375a0f414** in this case)
```dart
flutter doctor -v
[✓] Flutter (Channel unknown, v1.0.0, on Mac OS X 10.14.5 18F118d, locale en-CN)
    • Flutter version 1.0.0 at ~/Codes/Flutter/official/flutter
    • Framework revision 5391447fae (5 months ago), 2018-11-29 19:41:26 -0800
    • Engine revision 7375a0f414
    • Dart version 2.1.0 (build 2.1.0-dev.9.4 f9ebf21297)
```

Get corresponding dart sdk sha:(https://github.com/flutter/engine/blob/7375a0f414/DEPS)

```dart
'dart_revision': 'f9ebf2129732fd2b606286fdf58e500384b8a0bc',
```

If the kernel&front_end's sha-ref specified in package:aspectd/pubspec.yaml matches the 'dart_revision' above, you can skip 4.a~4.c as snapshot/aspectd.dart.snapshot located in aspectd repo is the expected one. 

If the sha-refs don't match the 'dart_revision', modify it to be the dart_revision above to match your flutter(dart) sdk:

```dart
name: aspectd
description: AOP for Flutter.
version: 0.9.1
author:
homepage:

environment:
  sdk: ">=2.0.0-dev.68.0 <3.0.0"

dependencies:
  kernel: any
  front_end: any

dependency_overrides:
  kernel:
    git:
      url: https://github.com/dart-lang/sdk.git
      ref: dart-revision-you-got-above
      path: pkg/kernel
  front_end:
    git:
      url: https://github.com/dart-lang/sdk.git
      ref: dart-revision-you-got-above
      path: pkg/front_end
```
### b. Fetch dependencies for aspectd

```shell
cd path-for-aspectd-package #Typically located in ~/.pub-cache/git/aspectd-xxx
flutter packages get
```
### c. Compile aspectd.dart.snapshot
```shell
flutter/bin/cache/dart-sdk/bin/dart --snapshot=snapshot/aspectd.dart.snapshot bin/starter.dart
```

## 5. Patch flutter_tools to apply aspectd.dart.snapshot
```shell
cd path-for-flutter-git-repo
git apply path-for-aspectd-package/0001-aspectd.patch
rm bin/cache/flutter_tools.stamp
```
Notice that, if you want to customize the aop package, edit aopPackageRelPath(aop package relative path to the hello_flutter's pubspec.yaml) and aopPackageName(aop package folder name and main entry file name) defined in path-for-flutter-git-repo/flutter/packages/flutter_tools/lib/src/aspectd.dart. 
```dart
const String aopPackageRelPath = '.';
const String aopPackageName = 'aop';
```

Step 1~3 are expected to run each time you want to add aop to a flutter(dart) package. 4&5 is expected to run only once unless the dart-sdk changes. For example, If you upgrade flutter, you need to check if to rerun 4&5.

If you're using hello_flutter with an aop package not generated locally, remember to run `flutter packages get` in aop package to get aspectd and check 4&5.


# Tutorial
Now AspectD provides three ways to do AOP programming.

## call
Every callsites for a specific function would be manipulated.
```dart
import 'package:aspectd/aspectd.dart';

@Aspect()
@pragma("vm:entry-point")
class CallDemo{
  @Call("package:app/calculator.dart","Calculator","-getCurTime")
  @pragma("vm:entry-point")
  Future<String> getCurTime(PointCut pointcut) async{
    print('Aspectd:KWLM02');
    print('${pointcut.sourceInfos.toString()}');
    Future<String> result = pointcut.proceed();
    String test = await result;
    print('Aspectd:KWLM03');
    print('${test}');
    return result;
  }

  @Call("package:app/calculator.dart","Calculator","+getCurTemporature")
  @pragma("vm:entry-point")
  String getCurTemporature(PointCut pointcut) {
    print('Aspectd:KWLM04');
    print('${pointcut.sourceInfos.toString()}');
    try{
      String res = pointcut.proceed();
    } catch (error, trace){
      print('Aspectd:KWLM05');
    }
    return null;
  }

  @Call("package:flutter/src/widgets/binding.dart","","+runApp")
  @pragma("vm:entry-point")
  static void runAppKWLM(PointCut pointcut){
    print('Aspectd:KWLM07');
    print('${pointcut.sourceInfos.toString()}');
    pointcut.proceed();
  }
}
```

In this case, notice that @Aspect() is needed to mark a class so that the aspectd will know that this class contains AspectD annotation informations. 
@pragma("vm:entry-point") is needed so that the class/function will not be removed by tree-shaking.
For @Call("package:app/calculator.dart","Calculator","-getCurTime"), there are several things to know. Now call/execute/inject accept three positional parameters, package name, class name(If the procedure is a library method, this part is empty string), and function name. The function name may have a prefix('-' or '+'), '-' refers to instance method while '+' refers to library static method(like main) and class method. There is also a named parameter lineNum for inject so that AspectD know which line to inject a code snippet. The lineNum parameter is 1 based and code snippet would be injected before that line.

## execute

Every implementation for a specific function would be manipulated.
```dart
import 'package:aspectd/aspectd.dart';

@Aspect()
@pragma("vm:entry-point")
class ExecuteDemo{
  @Execute("package:app/calculator.dart","Calculator","-getCurTime")
  @pragma("vm:entry-point")
  Future<String> getCurTime(PointCut pointcut) async{
    print('Aspectd:KWLM12');
    print('${pointcut.sourceInfos.toString()}');
    Future<String> result = pointcut.proceed();
    String test = await result;
    print('Aspectd:KWLM13');
    print('${test}');
    return result;
  }

  @Execute("package:app/calculator.dart","Calculator","+getCurTemporature")
  @pragma("vm:entry-point")
  String getCurTemporature(PointCut pointcut) {
    print('Aspectd:KWLM14');
    print('${pointcut.sourceInfos.toString()}');
    try{
      String res = pointcut.proceed();
    } catch (error, trace){
      print('Aspectd:KWLM15');
    }
    return null;
  }

  @Execute("package:flutter/src/widgets/binding.dart","","+runApp")
  @pragma("vm:entry-point")
  static void runAppKWLM(PointCut pointcut){
    print('Aspectd:KWLM17');
    print('${pointcut.sourceInfos.toString()}');
    pointcut.proceed();
  }
}
```

## inject
For a original function like below:(package:flutter/src/widgets/gesture_detector.dart)
```dart
  @override
  Widget build(BuildContext context) {
    final Map<Type, GestureRecognizerFactory> gestures = <Type, GestureRecognizerFactory>{};

    if (onTapDown != null || onTapUp != null || onTap != null || onTapCancel != null) {
      gestures[TapGestureRecognizer] = GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
        () => TapGestureRecognizer(debugOwner: this),
        (TapGestureRecognizer instance) {
          instance
            ..onTapDown = onTapDown
            ..onTapUp = onTapUp
            ..onTap = onTap
            ..onTapCancel = onTapCancel;
        },
      );
    }
...
}
```

```dart
import 'package:aspectd/aspectd.dart';
import 'package:flutter/services.dart';

@Aspect()
@pragma("vm:entry-point")
class InjectDemo{
  @Inject("package:flutter/src/widgets/gesture_detector.dart","GestureDetector","-build", lineNum:452)
  @pragma("vm:entry-point")
  static void onTapBuild() {
    Object instance; //Aspectd Ignore
    Object context; //Aspectd Ignore
    print(instance);
    print(context);
    print('Aspectd:KWLM25');
  }
}
```

After that, the original build function will look like below:
```dart
  @override
  Widget build(BuildContext context) {
    final Map<Type, GestureRecognizerFactory> gestures = <Type, GestureRecognizerFactory>{};

    if (onTapDown != null || onTapUp != null || onTap != null || onTapCancel != null) {
      gestures[TapGestureRecognizer] = GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
        () => TapGestureRecognizer(debugOwner: this),
        (TapGestureRecognizer instance) {
          instance
            ..onTapDown = onTapDown
            ..onTapUp = onTapUp
            ..onTap = onTap
            ..onTapCancel = onTapCancel;
        },
    	print(instance);
    	print(context);
    	print('Aspectd:KWLM25');
      );
    }
...
}
```
Notice that `//Aspectd Ignore` part when using injection, we need to compile the aop package successfully so we need to declare the instance/context variable. However, when injecting to origin function (build in this case), variable declaration
```dart
Object instance; //Aspectd Ignore 
Object context; //Aspectd Ignore
```
would be discarded to avoid overring the original one.

# Compatibility
Flutter 1.0 and above.


# Notice
Because of the dart compilation implementation, there are several points to pay attention to:
1. package:aop/aop.dart should contains the main entry for aop package and contains a app.main call.
2. Every aop implementation file should be imported by aop.dart so that it will work in debug mode.
3. @pragma("vm:entry-point") is needed to mark class/function to avoid been trimmed by tree-shaking.
4. inject might fail in some cases while call&execute are expected to be more stable.
5. If you want to disable AOP, remove the aspectd.dart.snapshot located in aspectd or change the name of aop package, or remove the @Aspect() annotation. Anyone will be fine.

# Contact

If you meet any problem when using AspectD, file a issue or contact me directly. 

[Contact Author](mailto:kang.wang1988@gmail.com)