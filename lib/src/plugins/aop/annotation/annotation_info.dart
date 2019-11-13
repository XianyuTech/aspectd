@pragma('vm:entry-point')
class AnnotationInfo {
  @pragma('vm:entry-point')
  const AnnotationInfo(
      {this.importUri,
      this.clsName,
      this.methodName,
      this.lineNum,
      this.isRegex = false});

  final String importUri;
  final String clsName;
  final String methodName;
  final bool isRegex;
  final int lineNum; //Line Number to insert at(Before), 1 based.
}
