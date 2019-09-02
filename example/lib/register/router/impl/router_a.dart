import '../router.dart';

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