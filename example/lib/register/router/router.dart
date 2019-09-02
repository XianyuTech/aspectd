/// debug模式下必须在某个地方引用，不然没法打入包
import 'impl/router_a.dart';



abstract class CCRouter {

  /// date: 2019-07-26 11:12
  /// author: bruce.zhang
  /// description: 定义组件名称
  String getName();

}

final List<CCRouter> _Routers = <CCRouter>[];

@pragma("vm:entry-point")
void registerRouter(CCRouter router) {
  if (router != null) {
    if(!_Routers.contains(router)) {
      _Routers.add(router);
    }
  }
}

void init() {
  //registerRouter(new RouterA());
  //registerRouter(new RouterAA());
}

class RouterManager {

  RouterManager._internal() {
    init();
  }

  static RouterManager _singleton = new RouterManager._internal();

  factory RouterManager()=> _singleton;

  void printRouter() {
    _Routers.forEach((it){print('router: $it');});
  }

}

