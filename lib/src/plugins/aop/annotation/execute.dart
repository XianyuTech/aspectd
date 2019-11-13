import 'annotation_info.dart';

@pragma('vm:entry-point')
class Execute extends AnnotationInfo {
  const factory Execute(String importUri, String clsName, String methodName,
      {bool isRegex}) = Execute._;

  @pragma('vm:entry-point')
  const Execute._(String importUri, String clsName, String methodName, {bool isRegex})
      : super(
            importUri: importUri,
            clsName: clsName,
            methodName: methodName,
            isRegex: isRegex);
}
