import '../router.dart';

/// 必须有这个注解，不然release模式下，不会打入包
@pragma("vm:entry-point")
class RouterB implements CCRouter {

  @pragma("vm:entry-point")
  RouterB();

  @override
  String getName() {
    return "RouterB";
  }

}

@pragma("vm:entry-point")
class RouterC implements CCRouter {

  @pragma("vm:entry-point")
  RouterC();

  @override
  String getName() {
    return "RouterC";
  }

}