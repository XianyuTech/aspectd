@pragma('vm:entry-point')
class PointCut {
  final Map<dynamic, dynamic> sourceInfos;
  final Object target;
  final String function;
  final String stubId;
  final List<dynamic> positionalParams;
  final Map<dynamic, dynamic> namedParams;

  @pragma('vm:entry-point')
  PointCut(this.sourceInfos, this.target, this.function, this.stubId,
      this.positionalParams, this.namedParams);

  @pragma('vm:entry-point')
  Object proceed() {
    return null;
  }
}
