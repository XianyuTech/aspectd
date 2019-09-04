import 'annotation_info.dart';

@pragma('vm:entry-point')
class Execute extends AnnotationInfo {
  const factory Execute(String importUri, String clsName, String methodName,
      {int lineNum}) = Execute._;

  @pragma('vm:entry-point')
  const Execute._(importUri, clsName, methodName, {int lineNum})
      : super(
            importUri: importUri,
            clsName: clsName,
            methodName: methodName,
            lineNum: lineNum);
}
