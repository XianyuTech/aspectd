import 'annotation_info.dart';

@pragma('vm:entry-point')
class Inject extends AnnotationInfo {
  
  const factory Inject(String importUri, String clsName, String methodName, {int lineNum}) = Inject._;
  
  @pragma('vm:entry-point')
  const Inject._(importUri, clsName, methodName, {int lineNum}):super(importUri:importUri, clsName:clsName, methodName:methodName, lineNum:lineNum);
}