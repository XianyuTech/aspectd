import 'annotation_info.dart';

/// Inject grammar can help you to inject statements into specific method
/// implementation on specific location.
@pragma('vm:entry-point')
class Inject extends AnnotationInfo {
  /// Inject grammar default constructor.
  const factory Inject(String importUri, String clsName, String methodName,
      {int lineNum, bool isRegex}) = Inject._;

  @pragma('vm:entry-point')
  const Inject._(String importUri, String clsName, String methodName,
      {int lineNum, bool isRegex})
      : super(
            importUri: importUri,
            clsName: clsName,
            methodName: methodName,
            lineNum: lineNum,
            isRegex: isRegex);
}
