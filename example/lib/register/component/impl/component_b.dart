
import '../component.dart';

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
