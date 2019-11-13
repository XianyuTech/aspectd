/// Indicating which (library, cls, method) pair to operate on.
@pragma('vm:entry-point')
class AnnotationInfo {

  /// AnnotationInfo default constructor.
  @pragma('vm:entry-point')
  const AnnotationInfo(
      {this.importUri,
      this.clsName,
      this.methodName,
      this.lineNum,
      this.isRegex = false});

  /// Indicating which dart file to operate on.
  final String importUri;

  /// Indicating which dart class to operate on.
  final String clsName;

  /// Indicating which dart method to operate on.
  final String methodName;

  /// Indicating whether those specification above should be regarded as
  /// regex expressions.
  final bool isRegex;

  /// Indicating which line to operate on.
  /// This is only meaningful for inject grammar.
  final int lineNum; //Line Number to insert at(Before), 1 based.
}
