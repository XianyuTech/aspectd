
import '../component.dart';

@pragma("vm:entry-point")
class ComponentB implements CCComponent {

  @override
  String getName() {
    return "ComponentB";
  }

}

@pragma("vm:entry-point")
class ComponentC implements CCComponent {

  @override
  String getName() {
    return "ComponentC";
  }

}

class ComponentD implements CCComponent {

  @override
  String getName() {
    return "ComponentD";
  }

}