import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

import 'package:aspectd_impl/growing_event.dart';
import 'package:growingio_sdk_autotracker_plugin/growingio_sdk_autotracker_plugin.dart';

@pragma("vm:entry-point")
class GrowingHelper {
  static final _instance = GrowingHelper._();
  GrowingHelper._() {
    /// init method
    if (isWidgetCreationTracked() == true) {
      GIOLogger.info("Aop Location success");
    }else{
      GIOLogger.warn("Aop Location failed");
    }
  }
  factory GrowingHelper.getInstance() => _instance;

  /// aop helper
  List<GrowingPageEntry> pageList = <GrowingPageEntry>[];

  /// cache send Page
  List<GrowingPageEntry> pageCache = <GrowingPageEntry>[];
  var elementPathList = <Element>[];
  List<String> contentList = [];

  /// click event about
  Map<int, dynamic> clickRenderMap = Map<int, dynamic>();
  int mPointerCode = 0;
  int mHitPointerCode = 0;

  GrowingPageEntry currentPage() {
    /// isCurrent isnot correct in some time
    var tmplist = pageList.where((element) => element.current.isCurrent);
    if (tmplist.isEmpty) {
      return pageList.last;
    }else{
      return tmplist.last;
    }
  }

  void handleEvent(HitTestTarget target, PointerEvent event) {
    var pointer = event.pointer;
    if (pointer > mPointerCode) {
      clickRenderMap.clear();
    }
    if (!clickRenderMap.containsKey(pointer)) {
      clickRenderMap[pointer] = target;
    }
    mPointerCode = pointer;
  }

  void handleClickEvent(String eventName) {
    if (mPointerCode > mHitPointerCode) {
      if (eventName == 'onTap' ||
          eventName == 'onTapDown' ||
          eventName == 'onDoubleTap') {
        RenderObject clickRender = clickRenderMap[mPointerCode];
        if (clickRender != null) {
          DebugCreator creator = clickRender.debugCreator as DebugCreator;
          Element element = creator.element;
          var clickEvent =
              new GrowingViewElementEvent(GrowingViewElementType.Click);
          /// create elementPathList data
          clickEvent.xpath = _getElementXPath(element);
          clickEvent.textValue = _getElementContent(element);
          /// first object must be local
          clickEvent.index = _getIndex(elementPathList.first);
          /// page about
          clickEvent.path = _getPagePath(currentPage());
          clickEvent.pageShowTimestamp = currentPage().pageShowTimestamp;
          GIOLogger.debug('handleClickEvent ' + clickEvent.toMap().toString());
          GrowingAutotracker.getInstance()
              .flutterClickEvent(clickEvent.toMap());
          _resetValues();
        }
        mHitPointerCode = mPointerCode;
      }
    }
  }

  void _resetValues() {
    elementPathList.clear();
    contentList.clear();
  }

  void handlePush(Route route, Route previousRoute) {
    if (route is ModalRoute) {
      if (route == pageList.last.current) {
        pageList.last.previous = previousRoute as ModalRoute;
      }
    }
  }

  void handleBuildPage(Route route, Widget widget, BuildContext context) {
    if (route is ModalRoute) {
      var page = GrowingPageEntry(route, null, GrowingRouteActionType.Push,
          widget: widget, context: context);
      pageList.add(page);
      pageCache.add(page);
    }
    GIOLogger.debug(pageList.toString());
  }

  void handleDrawFrame() {
    /// page event create
    /// visitChildElements can`t call in buildPage
    pageCache.forEach((element) {
      var title = _getPageTitle(element.widget, element.context);
      pageTitle = "";
      var page = GrowingPageEvent(_getPagePath(element),
          element.pageShowTimestamp, title,
          routeName: element.current.settings.name);
      GIOLogger.debug('send Cache Event ' + page.toMap().toString());
      GrowingAutotracker.getInstance()
          .flutterPageEvent(page.toMap());
    });
    pageCache.clear();
  }

  void handleTextChanged(EditableTextState state,TextEditingValue value) {
    var clickEvent =
    new GrowingViewElementEvent(GrowingViewElementType.Change);
    /// create elementPathList data
    clickEvent.xpath = _getElementXPath(state.context as Element);
    clickEvent.textValue = value.text;
    /// first object must be local
    clickEvent.index = _getIndex(elementPathList.first);
    /// page about
    clickEvent.path = _getPagePath(currentPage());
    clickEvent.pageShowTimestamp = currentPage().pageShowTimestamp;
    GIOLogger.debug('handleTextChanged ' + clickEvent.toMap().toString());
    GrowingAutotracker.getInstance()
        .flutterViewChangeEvent(clickEvent.toMap());
    _resetValues();
  }

  String _getPageTitle(Widget widget, BuildContext context) {
    // RenderObject object = context.findRenderObject();
    reversedObjc(context as Element);
    return pageTitle;
  }

  static var pageTitle = "";

  void reversedObjc(Element object) {
    object.visitChildElements((element) {
      // GIOLogger.debug("reversedObjc " + element.widget.runtimeType.toString());
      if (element.widget is AppBar ||
          element.widget.runtimeType.toString() == "Appbar") {
        var widget = (element.widget as AppBar).title;
        pageTitle = getTextFromWidget(widget as Widget);
        GIOLogger.debug("title is " + pageTitle);
      }
      if (pageTitle.length == 0) {
        reversedObjc(element);
      }
    });
  }

  void handlePop(Route route, Route previousRoute) {
    if (route is ModalRoute) {
      pageList.removeWhere((element) => (element.current == route));
    }
  }

  int _getIndex(Element ele) {
    int slot = 0;
    if (ele.slot != null) {
      if (ele.slot is IndexedSlot) {
        slot = (ele.slot as IndexedSlot).index;
      }
    }
    return slot;
  }
  /// page path
  /// eg: MyApp/MaterialApp/MyHomePage
  String _getPagePath(GrowingPageEntry? entry) {
    if (entry == null) return "";
    var list = <Element>[];
    var element = entry.context;
    element.visitAncestorElements((ele) {
      if (_isLocalElement(ele)) {
        list.add(ele);
      }
      return true;
    });
    var listResult = list.reversed;
    String finalResult = "";
    listResult.forEach((ele) {
      // int slot = _getIndex(ele);
      finalResult += "/${ele.widget.runtimeType.toString()}";
      // finalResult += "[$slot]";
    });
    /// add current page widget ; eg:MyHomePage
    finalResult += "/${entry.widget.runtimeType.toString()}";
    if (finalResult.startsWith('/')) {
      finalResult = finalResult.replaceFirst('/', '');
    }
    return finalResult;
  }
  /// eg: full path is MyApp[0]/MaterialApp[0]/MyHomePage[0]/Scaffold[0]/Center[0]/Column[0]/GestureDetector[2]/Text[0]
  /// page path is MyApp/MaterialApp/MyHomePage
  /// element xpath is Page/Scaffold[0]/Center[0]/Column[0]/GestureDetector[2]/Text[0]
  String _getElementXPath(Element element) {
    if (element == null) return "";
    if (_isLocalElement(element)) {
      elementPathList.add(element);
    }

    element.visitAncestorElements((ele) {
      if (_isLocalElement(ele)) {
        elementPathList.add(ele);
      }
      return true;
    });
    /// growingio logic : page element can`t contained in click xpath
    /// page element contain in page path
    var listResult = elementPathList.reversed.skipWhile((value) => value.widget.runtimeType.toString() != currentPage().widget.runtimeType.toString());
    String finalResult = "Page";
    /// remove MyHomePage
    listResult = listResult.skip(1);
    listResult.forEach((ele) {
      finalResult += "/${ele.widget.runtimeType.toString()}";
      if (ele == listResult.last) {
        finalResult += "[-]";
      }else{
        int slot = _getIndex(ele);
        finalResult += "[$slot]";
      }
    });

    if (finalResult.startsWith('/')) {
      finalResult = finalResult.replaceFirst('/', '');
    }
    return finalResult;
  }

  bool _isLocalElement(Element element) {
    Widget widget = element.widget;
    if (widget is _CustomHasCreationLocation) {
      _CustomHasCreationLocation creationLocation =
          widget as _CustomHasCreationLocation;
      if (creationLocation._customLocation.isProjectRoot()) {
        return true;
      }
    }
    return false;
  }

  String _getElementContent(Element element) {
    if (element == null) return "";
    Element? finalContainerElement;
    element.visitAncestorElements((element) {
      String finalResult;
      dynamic widget = element.widget;
      finalResult = widget.runtimeType.toString();
      if (finalResult != null) {
        finalContainerElement = element;
        return false;
      }
      return true;
    });

    if (finalContainerElement == null &&
        (element.widget is Text || element.widget is RichText)) {
      finalContainerElement = element;
    }

    if (finalContainerElement != null) {
      _getElementContentByType(finalContainerElement!);
      if (contentList.isNotEmpty) {
        String result = contentList.join("-");
        if (result == null) return "";
        return result;
      }
    }
    return "";
  }

  void _getElementContentByType(Element element) {
    if (element != null) {
      String tmp = getTextFromWidget(element.widget);
      if (tmp != null) {
        contentList.add(tmp);
        return;
      }
      element.visitChildElements(_getElementContentByType);
    }
  }

  String getTextFromWidget(Widget widget) {
    String? result;
    if (widget is Text) {
      result = widget.data;
    } else if (widget is Tab) {
      result = widget.text;
    } else if (widget is IconButton) {
      result = widget.tooltip ?? "";
    }
    return result ?? "";
  }
}

/// Page action
enum GrowingRouteActionType {
  Push,
  Pop,
}

/// flutter three kind Route : PopupRoute, PageRoute and there common super class ModalRoute
class GrowingPageEntry {
  ModalRoute? previous;
  ModalRoute current;
  GrowingRouteActionType actionType;
  Widget widget;
  BuildContext context;
  int pageShowTimestamp = 0;
  GrowingPageEntry(this.current, this.previous, this.actionType,
      {required this.widget, required this.context})
      : pageShowTimestamp = DateTime.now().microsecondsSinceEpoch;

  @override
  String toString() {
    return 'GrowingPageEntry{previous: $previous, current: $current, actionType: $actionType, widget: $widget, context: $context}';
  }
}

class GIOLogger {
  static void debug(String str) {
    print("GrowingIO [DEBUG] $str");
  }

  static void info(String str) {
    print("GrowingIO [INFO] $str");
  }

  static void warn(String str) {
    print("GrowingIO [WARN] $str");
  }
}

class _GrowingWidgetForTypeTests extends Widget {
  @override
  Element createElement() => throw UnimplementedError();
}

bool isWidgetCreationTracked() {
  var _widgetCreationTracked =
      _GrowingWidgetForTypeTests() is _CustomHasCreationLocation;
  return _widgetCreationTracked;
}

/// Interface for classes that track the source code location the their
/// constructor was called from.
///
/// {@macro flutter.widgets.WidgetInspectorService.getChildrenSummaryTree}
// ignore: unused_element
@pragma("vm:entry-point")
abstract class _CustomHasCreationLocation {
  _CustomLocation get _customLocation;
}

@pragma("vm:entry-point")
class _CustomLocation {
  const _CustomLocation({
    required this.file,
    required this.rootUrl,
    required this.line,
    required this.column,
    required this.name,
    required this.parameterLocations,
  });

  final String rootUrl;
  final String file;
  final int line;
  final int column;
  final String name;
  final List<_CustomLocation> parameterLocations;

  bool isProjectRoot() {
    if (rootUrl == null || file == null) {
      return false;
    }

    if (file.contains('packages/flutter/')) return false;
    if (file.startsWith(rootUrl)) {
      // print(file.toString() + 'is startwith ' + rootUrl);
      return true;
    }
    return false;
  }

  @override
  String toString() {
    return '_CustomLocation{rootUrl: $rootUrl, file: $file, line: $line, column: $column, name: $name}';
  }
}
