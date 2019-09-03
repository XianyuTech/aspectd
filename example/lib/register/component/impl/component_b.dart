
import '../component.dart';

/// 必须有这个注解，不然release模式下，不会打入包
@pragma("vm:entry-point")
class ComponentB implements CCComponent {

  @pragma("vm:entry-point")
  ComponentB();

  @override
  String getName() {
    return "ComponentB";
  }

}

@pragma("vm:entry-point")
class ComponentC implements CCComponent {

  @pragma("vm:entry-point")
  ComponentC();

  @override
  String getName() {
    return "ComponentC";
  }

}
