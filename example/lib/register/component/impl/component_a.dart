
import '../component.dart';

/// 必须有这个注解，不然release模式下，不会打入包
@pragma("vm:entry-point")
class ComponentA implements CCComponent {

  @pragma("vm:entry-point")
  @override
  String getName() {
    return "ComponentA";
  }

}