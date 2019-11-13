import 'annotation_info.dart';

@pragma('vm:entry-point')
class Call extends AnnotationInfo {
  const factory Call(String importUri, String clsName, String methodName,
      {bool isRegex}) = Call._;

  @pragma('vm:entry-point')
  const Call._(String importUri, String clsName, String methodName,
      {bool isRegex})
      : super(
            importUri: importUri,
            clsName: clsName,
            methodName: methodName,
            isRegex: isRegex);
}
