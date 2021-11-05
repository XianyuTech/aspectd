import 'package:flutter/src/gestures/events.dart';
// import 'package:flutter/src/gestures/hit_test.dart';
import 'package:flutter/src/rendering/object.dart';
import 'package:flutter/src/widgets/framework.dart';
import 'package:aspectd/aspectd.dart';
import 'package:flutter/foundation.dart';

import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/src/widgets/widget_inspector.dart';
import 'package:aspectd_impl/growing_impl.dart';

@Aspect()
@pragma("vm:entry-point")
class GrowingAopClass {
  @pragma("vm:entry-point")
  GrowingAopClass();
  /// click event aop step 1
  /// hittest
  @Call("package:flutter/src/gestures/hit_test.dart", "HitTestTarget",
      "-handleEvent")
  @pragma("vm:entry-point")
  dynamic hookHitTestTargetHandleEvent(PointCut pointCut) {
    dynamic target = pointCut.target;
    PointerEvent pointerEvent = pointCut.positionalParams[0];
    if (target is RenderObject) {
      GrowingHelper.getInstance().handleEvent(target, pointerEvent);
    }
    target.handleEvent(pointerEvent, pointCut.positionalParams[1]);
  }
  // @Execute("package:flutter/src/gestures/binding.dart", "GestureBinding",
  //     "-dispatchEvent")
  // @pragma("vm:entry-point")
  // dynamic hookGestureBindingDispatchEvent(PointCut pointCut) {
  //   PointerEvent pointEvent = pointCut.positionalParams[0];
  //   HitTestResult hitTestResult = pointCut.positionalParams[1];
  //   if (pointEvent is PointerUpEvent) {
  //     GrowingHelper.getInstance().handleDispatchEvent(hitTestResult.path.first, pointEvent);
  //   }
  //   return pointCut.proceed();
  // }
  /// click event aop step 2
  /// callback
  @Execute("package:flutter/src/gestures/recognizer.dart", "GestureRecognizer",
      "-invokeCallback")
  @pragma("vm:entry-point")
  dynamic hookInvokeCallback(PointCut pointCut) {
    dynamic result = pointCut.proceed();
    dynamic eventName = pointCut.positionalParams[0];
    GrowingHelper.getInstance().handleClickEvent(eventName);
    return result;
  }
  /// DebugCreator add
  @Execute("package:flutter/src/widgets/framework.dart", "RenderObjectElement",
      "-mount")
  @pragma('vm:entry-point')
  static dynamic hookElementMount(PointCut pointCut) {
    dynamic obj = pointCut.proceed();
    if (pointCut.target.runtimeType is Element) return;
    Element element = pointCut.target as Element;
    if (kReleaseMode || kProfileMode) {
      //release和profile模式创建这个属性
      element.renderObject?.debugCreator = DebugCreator(element);
    }
  }
  /// DebugCreator add
  @Execute('package:flutter/src/widgets/framework.dart', 'RenderObjectElement',
      '-update')
  @pragma('vm:entry-point')
  static dynamic hookElementUpdate(PointCut pointCut) {
    dynamic obj = pointCut.proceed();
    if (pointCut.target.runtimeType is Element) return;
    Element element = pointCut.target as Element;
    if (kReleaseMode || kProfileMode) {
      //release和profile模式创建这个属性
      element.renderObject?.debugCreator = DebugCreator(element);
    }
  }
  /// Page Push - get only RouteEntry
  @Execute("package:flutter/src/widgets/navigator.dart", "_RouteEntry", "-handlePush")
  @pragma("vm:entry-point")
  void hookRouteEntryHandlePush(PointCut pointCut) {
    pointCut.proceed();
    dynamic target = pointCut.target;
    dynamic previous = pointCut.namedParams["previousPresent"];
    GrowingHelper.getInstance().handlePush(target.route,previous);
  }
  /// Page Push - get only RouteEntry
  @Execute(
      "package:flutter/src/widgets/navigator.dart", "_RouteEntry", "-handlePop")
  @pragma("vm:entry-point")
  void hookRouteEntryHandlePop(PointCut pointCut) {
    dynamic target = pointCut.target;
    dynamic previous = pointCut.namedParams["previousPresent"];
    pointCut.proceed();
    GrowingHelper.getInstance().handlePop(target.route,previous);
  }

  // @Call('package:flutter/src/widgets/routes.dart', 'ModalRoute', '-buildPage')
  // @pragma('vm:entry-point')
  // dynamic hookRouteBuildPage(PointCut pointcut) {
  //   ModalRoute target = pointcut.target;
  //   List<dynamic> positionalParams = pointcut.positionalParams;
  //   if (target is ModalRoute) {
  //     GrowingHelper.getInstance().handleBuildPage(target, null);
  //   }
  //   return target.buildPage(
  //       positionalParams[0], positionalParams[1], positionalParams[2]);
  // }
  /// Page Build
  /// can get context and widget
  @Execute("package:flutter/src/material/page.dart",
      "MaterialRouteTransitionMixin", "-buildPage")
  @pragma("vm:entry-point")
  dynamic hookMaterialRouteTransitionMixinBuildPage(PointCut pointCut) {
    Route target = pointCut.target as Route;
    Semantics? widgetResult = pointCut.proceed() as Semantics;
    GrowingHelper.getInstance().handleBuildPage(
        target,widgetResult.child!, pointCut.positionalParams[0]);
    return widgetResult;
  }
  /// Page Build
  /// can get context and widget
  @Execute("package:flutter/src/cupertino/route.dart",
      "CupertinoRouteTransitionMixin", "-buildPage")
  @pragma("vm:entry-point")
  dynamic hookCupertinoRouteTransitionMixinBuildPage(PointCut pointCut) {
    Route target = pointCut.target as Route;
    Semantics widgetResult = pointCut.proceed() as Semantics;
    GrowingHelper.getInstance().handleBuildPage(
        target,widgetResult.child!, pointCut.positionalParams[0]);
    return widgetResult;
  }
  /// Draw Frame - 每次变动刷新
  /// SchedulerBinding：support window.onBeginFrame/window.onDrawFrame call back
  @Execute("package:flutter/src/scheduler/binding.dart", "SchedulerBinding",
      "-handleDrawFrame")
  @pragma("vm:entry-point")
  void hookSchedulerBindingHandleDrawFrame(PointCut pointCut) {
    pointCut.proceed();
    GrowingHelper.getInstance().handleDrawFrame();
  }

  /// text value changed
  /// EditableTextState
  @Execute("package:flutter/src/widgets/editable_text.dart", "EditableTextState",
      "-updateEditingValue")
  @pragma("vm:entry-point")
  void hookEditableTextStateUpdateEditingValue(PointCut pointCut) {
    pointCut.proceed();
    GrowingHelper.getInstance().handleTextChanged(pointCut.target as EditableTextState, pointCut.positionalParams[0]);
  }
}


