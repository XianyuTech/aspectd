import 'dart:io';
import 'dart:ui' as ui show window;
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
    } else {
      GIOLogger.warn("Aop Location failed");
    }
  }
  factory GrowingHelper.getInstance() => _instance;

  /// aop helper
  List<GrowingPageEntry> pageList = <GrowingPageEntry>[];

  /// cache send Page
  List<GrowingPageEntry> pageCache = <GrowingPageEntry>[];

  /// click event about
  Map<int, dynamic> clickRenderMap = Map<int, dynamic>();
  int mPointerCode = 0;
  int mHitPointerCode = 0;

  /// webcircle
  List<GrowingCircleElement> circleElments = <GrowingCircleElement>[];
  int? lastTimestamp;

  GrowingPageEntry currentPage() {
    /// isCurrent isnot correct in some time
    var tmplist = pageList.where((element) => element.current.isCurrent);
    if (tmplist.isEmpty) {
      return pageList.last;
    } else {
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
        RenderObject? clickRender = clickRenderMap[mPointerCode];
        if (clickRender != null) {
          DebugCreator creator = clickRender.debugCreator as DebugCreator;
          Element element = creator.element;
          var clickEvent =
              new GrowingViewElementEvent(GrowingViewElementType.Click);
          var parser = GrowingElementParser(element);
          /// create elementPathList data
          clickEvent.xpath = parser.xpath;
          clickEvent.textValue = parser.content;

          /// first object must be local
          clickEvent.index = parser.index;
          var page = parser.parentPage ?? currentPage();
          /// page about
          clickEvent.path = _getPagePath(page);
          clickEvent.pageShowTimestamp = page.pageShowTimestamp;
          GIOLogger.debug('handleClickEvent ' + clickEvent.toMap().toString());
          GrowingAutotracker.getInstance()
              .flutterClickEvent(clickEvent.toMap());

        }
        mHitPointerCode = mPointerCode;
      }
    }
  }


  void handlePush(Route route, Route previousRoute) {
    if (route is ModalRoute) {
      if (route == pageList.last.current) {
        pageList.last.previous = previousRoute as ModalRoute;
      }
    }
  }

  void handlePop(Route route, Route previousRoute) {
    if (route is ModalRoute) {
      pageList.removeWhere((element) => (element.current == route));
      pageCache.removeWhere((element) => (element.current == route));
    }
  }
  /// 从pagelist中删除相关的元素
  void _removeLinkedElement(Widget child) {
    var rmElement = null;
    pageList.forEach((element) {
      if (rmElement != null) return;
      if (element.widget == child) {
        rmElement = element;
      }
    });
    if (rmElement == null) return;
    pageList.remove(rmElement);
    GIOLogger.debug("remove Element" + rmElement.toString());
    if (rmElement.container != null)  {
      pageList.remove(rmElement.container);
      GIOLogger.debug("remove Element" + rmElement.container.toString());
    }
  }

  void handleDeactivate(Element parent,Element child) {
    this._removeLinkedElement(child.widget);
  }

  void handleBuildPage(Route route, Widget widget, BuildContext context) {
    if (route is ModalRoute) {
      /// MyPage 可能被 Scaffold 包裹，需要获取其真实的代表，MyPage
      var realwidget = GrowingUtil.getRealWidget(widget);

      if (realwidget is MultiChildRenderObjectWidget) {
        GIOLogger.debug("Ignored MultiChildRenderObjectWidget" + realwidget.runtimeType.toString());
        return;
      }
      if (realwidget is StatefulWidget || realwidget is StatelessWidget) {
        var container = null;
        if (realwidget != widget) {
          this._removeLinkedElement(widget);
          /// add Scaffold
          container = GrowingPageEntry(route, GrowingRouteActionType.Push,
              widget: widget, context: context);
          pageList.add(container);
          /// page cache 存储page实体，drawFrame时，发出page事件后清空，仅需要add，无需删除
          pageCache.add(container);
          GIOLogger.debug("add Element" + container.toString());
        }

        this._removeLinkedElement(realwidget);
        var element = GrowingPageEntry(route, GrowingRouteActionType.Push,
            widget: realwidget, context: context, container: container);
        pageList.add(element);
        /// page cache 存储page实体，drawFrame时，发出page事件后清空，仅需要add，无需删除
        pageCache.add(element);
        GIOLogger.debug("add Element" + element.toString());


      }

    }
    GIOLogger.debug(pageList.toString());
  }

  void handleDrawFrame() {
    /// page event create
    /// visitChildElements can`t call in buildPage
    if (lastTimestamp == null || DateTime.now().microsecondsSinceEpoch - lastTimestamp! > 200) {
      // GIOLogger.debug("currernt : " + DateTime.now().toString() + " last : " + lastTimestamp.toString());
      lastTimestamp = DateTime
          .now()
          .microsecondsSinceEpoch;
      this.webcircleSend();

      pageCache.forEach((element) {
        /// 仅获取title

        var title = element.title;
        var page = GrowingPageEvent(
            _getPagePath(element), element.pageShowTimestamp, title,
            routeName: element.current.settings.name);
        GIOLogger.debug('send Cache Event ' + page.toMap().toString());
        GrowingAutotracker.getInstance().flutterPageEvent(page.toMap());
      });
      pageCache.clear();
    }
  }

  void webcircleSend() {
    /// 圈选遍历逻辑
    if (GrowingAutotracker.getInstance().webCircleRunning) {
      if (pageList.isEmpty) {
        GIOLogger.debug(
            "handleDrawFrame webcircle error : no found page entry");
        return;
      }
      GrowingPageEntry entry = pageList.last;
      entry.context.visitChildElements((element) {
        traverseElement(element, entry.context as Element, false, 0);
      });

      circleElments.forEach((child) {
        GIOLogger.debug("circleElement : " + child.toString());
      });
      Map<String, dynamic> map = <String, dynamic>{};
      Map<String, dynamic> page = <String, dynamic>{};

      /// translate entry to map
      List<Map> elements = <Map>[];
      circleElments.forEach((element) {
        elements.add(element.toMap());
      });
      map["elements"] = elements;

      var element = entry.context as Element;
      final RenderBox box = element.renderObject as RenderBox;
      final size = box.size;
      final offset = box.localToGlobal(Offset.zero);
      MediaQueryData queryData = MediaQueryData.fromWindow(ui.window);
      if (queryData.devicePixelRatio > 1) {
        page["left"] = offset.dx*queryData.devicePixelRatio;
        page["top"] = offset.dy*queryData.devicePixelRatio;
        page["width"] = size.width*queryData.devicePixelRatio;
        page["height"] = size.height*queryData.devicePixelRatio;
      } else {
        page["left"] = offset.dx;
        page["top"] = offset.dy;
        page["width"] = size.width;
        page["height"] = size.height;
      }
      page["path"] = _getPagePath(entry);
      page["title"] = entry.title;
      page["isIgnored"] = false;

      /// pages
      map["pages"] = <Map>[page];
      GrowingAutotracker.getInstance().flutterWebCircleEvent(map);
      GIOLogger.debug('handleDrawFrame circle ' + map.toString());
      circleElments.clear();
    }
  }

  void traverseElement(Element element,Element parent, bool isIgnored, int z) {
    // GIOLogger.debug("reversedObjc " + element.widget.runtimeType.toString());
    if (_isLocalElement(element)) {
      String? elementType = null;
      if (element.widget is IgnorePointer) {
        /// ignorePointer will ignore all subtree if is ignoring
        IgnorePointer widget = element.widget as IgnorePointer;
        if (widget.ignoring) {
          element.visitChildElements((child) {
            traverseElement(child,element, true,z++);
          });
          return;
        }
      }else if (element.widget is RawMaterialButton || element.widget is MaterialButton || element.widget is FloatingActionButton || element.widget is AppBar) {
        /// because of is local element, Gesture is create by system
        /// RawMaterialButton is super class of RaisedButton、FlatButton、OutlineButton
        // [RawMaterialButton,MaterialButton,FloatingActionButton].takeWhile((e) => element.widget is e).isNotEmpty;
        elementType = "BUTTON";
      }else if (element.widget is TextFormField || element.widget is TextField) {
        elementType = "INPUT";
      }else if (element.widget is ListView || element.widget is CustomScrollView || element.widget is SingleChildScrollView || element.widget is GridView) {
        elementType = "LIST";
      }else if (parent.widget is GestureDetector) {
        /// gesture click enable
        elementType = "TEXT";
      }

      if (elementType != null) {
        GrowingCircleElement circle = GrowingCircleElement();
        final RenderBox box = element.renderObject as RenderBox;
        final size = box.size;
        final offset = box.localToGlobal(Offset.zero);
        MediaQueryData mediaQuery = MediaQueryData.fromWindow(ui.window);
        if (mediaQuery.devicePixelRatio > 1) {
          circle.rect = Rect.fromLTWH(offset.dx*mediaQuery.devicePixelRatio, offset.dy*mediaQuery.devicePixelRatio, size.width*mediaQuery.devicePixelRatio, size.height*mediaQuery.devicePixelRatio);
        }else {
          circle.rect = Rect.fromLTWH(offset.dx, offset.dy, size.width, size.height);
        }
        var parser = GrowingElementParser(element);
        var parentParser = GrowingElementParser(parent);
        circle.xpath = parser.xpath;
        circle.parentXPath = parentParser.xpath;
        circle.content = parser.content;
        circle.index = parser.index;
        circle.page = _getPagePath(parser.parentPage ?? currentPage());
        circle.zLevel = z;
        circle.isContainer = false;
        circle.isIgnored = isIgnored;
        circle.nodeType = elementType;
        circleElments.add(circle);
      }
      element.visitChildElements((child) {
        traverseElement(child,element, isIgnored,z++);
      });
    }else {
      element.visitChildElements((child) {
        traverseElement(child,parent, isIgnored,z++);
      });
    }


  }

  void handleTextChanged(EditableTextState state, TextEditingValue value) {
    var clickEvent = new GrowingViewElementEvent(GrowingViewElementType.Change);
    var parser = GrowingElementParser(state.context as Element);
    /// create elementPathList data
    clickEvent.xpath = parser.xpath;
    clickEvent.textValue = value.text;

    /// first object must be local
    clickEvent.index = parser.index;
    var page = parser.parentPage ?? currentPage();
    /// page about
    clickEvent.path = _getPagePath(page);
    clickEvent.pageShowTimestamp = page.pageShowTimestamp;
    GIOLogger.debug('handleTextChanged ' + clickEvent.toMap().toString());
    GrowingAutotracker.getInstance().flutterViewChangeEvent(clickEvent.toMap());
  }

  /// page path
  /// if user real path eg: MyApp/MaterialApp/CustomPage can`t identify a unique path
  /// so use page stack list /MyHomePage/CustomPage
  String _getPagePath(GrowingPageEntry entry) {
    if (!pageList.contains(entry)) return "";
    String finalResult = "";
    var list = pageList.sublist(0,pageList.indexOf(entry)+1);
    list.forEach((ele) {
      var widget = ele.widget;
      String name = widget.runtimeType.toString();
      finalResult += "/${name}";
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


class GrowingElementParser {
  late Element element;
  GrowingPageEntry? parentPage;
  List<Element> elementComponents = <Element>[];

  GrowingElementParser(this.element);
  /// private
  String? _xpath;
  int? _index;


  String get content {
    return _getElementContent(element);
  }

  String _getElementContent(Element? element) {
    if (element == null) return "";
    if (element.widget is Text
        || element.widget is RichText
        || element.widget is TextField
        || element.widget is TextFormField) {
      String? tmp = getTextFromWidget(element.widget);
      if (tmp != null) {
        return tmp;
      }
    }
    return "";
  }

  String? getTextFromWidget(Widget widget) {
    String? result;
    if (widget is Text) {
      result = widget.data;
    } else if (widget is Tab) {
      result = widget.text;
    } else if (widget is IconButton) {
      result = widget.tooltip;
    }
    return result;
  }

  int get index {
    if (_index != null) return _index!;
    _index = _getIndex(element);
    return _index!;
  }

  String get xpath {
    if (_xpath != null) return _xpath!;
    if (_isLocalElement(element)) {
      elementComponents.add(element);
    }
    element.visitAncestorElements((ele) {
      if (parentPage != null) return true;
      if (_isLocalElement(ele)) {
        if (ele.widget is StatelessWidget || ele.widget is StatefulWidget) {
          GIOLogger.debug("visit " + ele.toString());
          var tempList = GrowingHelper.getInstance().pageList.where((element) => element.widget == ele.widget);
          if (tempList.isNotEmpty) {
            parentPage = tempList.first;
            return true;
          }
        }
        elementComponents.add(ele);
      }
      return true;
    });


    /// growingio logic : page element can`t contained in click xpath
    /// page element contain in page path
    var listResult = elementComponents.reversed;
    // elementComponents.reversed.forEach((element) {
    //   var widget = GrowingUtil.getInstance().getRealWidget(element.widget);
    //   if (widget == currentPage.widget) {
    //
    //   }
    // });
    String finalResult = "Page";

    /// remove MyHomePage
    // listResult = listResult.skip(1);
    listResult.forEach((ele) {
      finalResult += "/${ele.widget.runtimeType.toString()}";
      if (ele == listResult.last) {
        finalResult += "[-]";
      } else {
        int slot = _getIndex(ele);
        if (slot >= 0) {
          finalResult += "[$slot]";
        }
      }
    });

    if (finalResult.startsWith('/')) {
      finalResult = finalResult.replaceFirst('/', '');
    }
    _xpath = finalResult;
    return _xpath!;
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
  int _getIndex(Element ele) {
    int slot = 0;
    if (ele.slot != null) {
      if (ele.slot is IndexedSlot) {
        slot = (ele.slot as IndexedSlot).index;
      }
    }
    return slot;
  }
}


/// Page action
enum GrowingRouteActionType {
  Push,
  Pop,
}

class GrowingUtil {
  /// find real widget that reflect real use class
  static Widget getRealWidget(Widget widget) {
    if (widget is Scaffold) {
      if (widget.body != null) widget = widget.body!;
    }
    bool isNext = true;
    while (isNext) {
      if (widget is Container) {
        if (widget.child != null) {
          widget = widget.child!;
          continue;
        }
      }
      if (widget is SingleChildScrollView) {
        if (widget.child != null) {
          widget = widget.child!;
          continue;
        }
      }
      if (widget is SingleChildRenderObjectWidget) {
        if (widget.child != null) {
          widget = widget.child!;
          continue;
        }
      }
      isNext = false;
    }

    return widget;
  }
}

/// flutter three kind Route : PopupRoute, PageRoute and there common super class ModalRoute
class GrowingPageEntry {
  ModalRoute? previous;
  ModalRoute current;
  GrowingRouteActionType actionType;
  GrowingPageEntry? container;
  Widget widget;
  String? alias;
  BuildContext context;
  int pageShowTimestamp = 0;
  // GrowingPageEntry(this.current, this.previous, this.actionType,
  //     {required this.widget, required this.context})
  //     : pageShowTimestamp = DateTime.now().microsecondsSinceEpoch;
  GrowingPageEntry(this.current,this.actionType,
      {required this.widget, required this.context,this.previous,this.container,this.alias})
      : pageShowTimestamp = DateTime.now().microsecondsSinceEpoch;
  @override
  String toString() {
    return 'GrowingPageEntry{previous: $previous, current: $current, actionType: $actionType, widget: $widget, context: $context}';
  }

  String? _pageTitle;
  String get title {
    if (_pageTitle != null) return _pageTitle!;
    return _getPageTitle(widget, context);
  }

  String _getPageTitle(Widget widget, BuildContext context) {
    // RenderObject object = context.findRenderObject();
    reversedObjc(context as Element);
    if (_pageTitle == null) return "";
    return _pageTitle!;
  }

  

  void reversedObjc(Element object) {
    object.visitChildElements((element) {
      // GIOLogger.debug("reversedObjc " + element.widget.runtimeType.toString());
      if (element.widget is AppBar ||
          element.widget.runtimeType.toString() == "Appbar") {
        var widget = (element.widget as AppBar).title;
        _pageTitle = getTextFromWidget(widget as Widget);
      }
      if (_pageTitle == null) {
        reversedObjc(element);
      }
    });
  }

  String? getTextFromWidget(Widget widget) {
    String? result;
    if (widget is Text) {
      result = widget.data;
    } else if (widget is Tab) {
      result = widget.text;
    } else if (widget is IconButton) {
      result = widget.tooltip;
    }
    return result;
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
    if (file.contains('packages/flutter/')) return false;
    if (file.startsWith(rootUrl)) {
      return true;
    }
    return false;
  }

  @override
  String toString() {
    return '_CustomLocation{rootUrl: $rootUrl, file: $file, line: $line, column: $column, name: $name}';
  }
}
