import 'dart:ui';

enum GrowingViewElementType {
  Click,
  Change,
}

/// view element event : click / content change
class GrowingViewElementEvent {
  /// VIEW_CLICK VIEW_CHANGE
  GrowingViewElementType eventType;
  /// 对应原生sdk中的字段
  String? path;
  int? pageShowTimestamp;
  String? textValue;
  String? xpath;
  int? index;

  GrowingViewElementEvent(this.eventType,{this.path,this.pageShowTimestamp,this.textValue,this.xpath,this.index});

  Map<String,dynamic> toMap() {
    var jsonMap = Map<String,dynamic>();
    if (this.eventType == GrowingViewElementType.Click) {
      jsonMap["eventType"] = "VIEW_CLICK";
    }else if (this.eventType == GrowingViewElementType.Change) {
      jsonMap["eventType"] = "VIEW_CHANGE";
    }
    jsonMap["path"] = this.path;
    jsonMap["pageShowTimestamp"] = this.pageShowTimestamp;
    jsonMap["textValue"] = this.textValue;
    jsonMap["xpath"] = this.xpath;
    jsonMap["index"] = this.index;
    return jsonMap;
  }

  @override
  String toString() {
    return this.toMap().toString();
  }
}

/// page event : push a page will track
class GrowingPageEvent {
  /// flutter route name eg: /abc
  String? routeName;
  /// native about
  String path;
  String title;
  int timestamp;
  GrowingPageEvent(this.path,this.timestamp,this.title,{this.routeName});

  Map<String,dynamic> toMap() {
    var jsonMap = Map<String,dynamic>();
    jsonMap["routeName"] = this.routeName;
    jsonMap["path"] = this.path;
    jsonMap["timestamp"] = this.timestamp;
    jsonMap["title"] = this.title;
    return jsonMap;
  }

  @override
  String toString() {
    return this.toMap().toString();
  }
}

/// GrowingIO flutter web circle element
class GrowingCircleElement {
  /// element rect eg: {0,0,100,50}
  Rect? rect;
  /// element z position
  int zLevel = 0;
  String? content;
  String? xpath;
  String? nodeType;
  String? parentXPath;
  bool isContainer = false;
  int index = -1;
  String? page;
  bool isIgnored = false;
  GrowingCircleElement();

  Map<String,dynamic> toMap() {
    var jsonMap = Map<String,dynamic>();
    /// transform rect to left top width height
    jsonMap["left"] = this.rect!.left;
    jsonMap["top"] = this.rect!.top;
    jsonMap["width"] = this.rect!.width;
    jsonMap["height"] = this.rect!.height;
    /// key value
    jsonMap["zLevel"] = this.zLevel;
    jsonMap["content"] = this.content;
    jsonMap["xpath"] = this.xpath;
    jsonMap["nodeType"] = this.nodeType;
    jsonMap["parentXPath"] = this.parentXPath;
    jsonMap["isContainer"] = this.isContainer;
    jsonMap["index"] = this.index;
    jsonMap["page"] = this.page;
    jsonMap["isIgnored"] = this.isIgnored;
    return jsonMap;
  }

  @override
  String toString() {
    return this.toMap().toString();
  }
}