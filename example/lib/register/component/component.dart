/// date: 2019-09-03 16:44
/// author: bruce.zhang
/// description: register和init方法是[实例方法] demo
///
/// modification history:


/// debug模式下必须在某个地方引用，不然没法打入包
import 'impl/component_a.dart';
import 'impl/component_b.dart';

abstract class CCComponent {

  /// date: 2019-07-26 11:12
  /// author: bruce.zhang
  /// description: 定义组件名称
  String getName();

}

class ComponentManager {
  ComponentManager._internal() {
    init();
  }

  static ComponentManager _singleton = new ComponentManager._internal();

  factory ComponentManager()=> _singleton;

  static final Map<String, CCComponent> _components = <String, CCComponent>{};

  /// 初始化所有全局拦截器
  void init() {
    //registerComponent(new ComponentA());
    //registerComponent(new ComponentAA());
  }

  @pragma("vm:entry-point")
  void registerComponent(CCComponent component) {
    if (component != null) {
      if(_components[component.getName()] == null) {
        _components[component.getName()] = component;
      }
    }
  }

   void printComponent() {
    _components.forEach((key, value){
      print('component.name: ${value.getName()}');
    });
  }

}

