import '../router.dart';

@pragma("vm:entry-point")
class RouterB implements CCRouter {

  @override
  String getName() {
    return "RouterB";
  }

}

@pragma("vm:entry-point")
class RouterC implements CCRouter {

  @override
  String getName() {
    return "RouterC";
  }

}

class RouterD implements CCRouter {

  @override
  String getName() {
    return "RouterD";
  }

}