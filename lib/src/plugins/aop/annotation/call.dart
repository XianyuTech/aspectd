import 'annotation_info.dart';

@pragma('vm:entry-point')
class Call extends AnnotationInfo {
  const factory Call(String importUri, String clsName, String methodName) =
      Call._;

  @pragma('vm:entry-point')
  const Call._(importUri, clsName, methodName)
      : super(importUri: importUri, clsName: clsName, methodName: methodName);
}
