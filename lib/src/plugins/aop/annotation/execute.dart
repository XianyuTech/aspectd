import 'annotation_info.dart';

/// Execute grammar is working on method body.
/// In other words, it will fail when a function has no body in dart form, like
/// native method.
@pragma('vm:entry-point')
class Execute extends AnnotationInfo {
  /// Execute grammar default constructor.
  const factory Execute(String importUri, String clsName, String methodName,
      {bool isRegex}) = Execute._;

  @pragma('vm:entry-point')
  const Execute._(String importUri, String clsName, String methodName,
      {bool isRegex = false})
      : super(
            importUri: importUri,
            clsName: clsName,
            methodName: methodName,
            isRegex: isRegex);
}
