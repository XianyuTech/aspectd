import 'package:kernel/ast.dart';
import 'aspectd_callimpl_transformer.dart';
import 'aspectd_executeimpl_transformer.dart';
import 'aspectd_injectimpl_transformer.dart';
import 'utils.dart';

class AspectdWrapperTransformer {
  Map<String,AspectdItemInfo> aspectdInfoMap = Map<String, AspectdItemInfo>();
  Component platformStrongComponent;

  AspectdWrapperTransformer({this.platformStrongComponent});

  void transform(Component program) {
    final List<Library> libraries = program.libraries;

    if (libraries.isEmpty) {
      return;
    }

    _resolveAspectdProcedures(libraries);

    for (Library library in libraries) {
      if (library.isExternal) {
        continue;
      }
    }

    Procedure pointCutProceedProcedure = null;
    Procedure listGetProcedure = null;
    Procedure mapGetProcedure = null;
    //Search the PointCut class first
    List<Library> concatLibraries = List<Library>()
      ..addAll(libraries)
      ..addAll(this.platformStrongComponent!=null?this.platformStrongComponent.libraries:[]);
    Map<Uri, Source> concatUriToSource = Map<Uri, Source>()
      ..addAll(program.uriToSource)
      ..addAll(this.platformStrongComponent!=null?this.platformStrongComponent.uriToSource:{});
    Map<String, Library> libraryMap = Map<String, Library>();
    for (Library library in concatLibraries) {
      if (library.isExternal) {
        continue;
      }
      libraryMap.putIfAbsent(library.importUri.toString(), ()=>library);
      if (pointCutProceedProcedure != null && listGetProcedure != null && mapGetProcedure != null) {
        continue;
      }
      Uri importUri = library.importUri;
      for(Class cls in library.classes) {
        String clsName = cls.name;
        if(clsName == AspectdUtils.kAspectdAnnotationClassPointCut && importUri.toString() == AspectdUtils.kImportUriPointCut){
          for(Procedure procedure in cls.procedures){
            if(procedure.name.name == AspectdUtils.kAspectdPointcutProcessName)
              pointCutProceedProcedure = procedure;
          }
        }
        if(clsName == 'List' && importUri.toString() == 'dart:core'){
          for(Procedure procedure in cls.procedures ){
            if(procedure.name.name == '[]')
              listGetProcedure = procedure;
          }
        }
        if(clsName == 'Map' && importUri.toString() == 'dart:core') {
          for(Procedure procedure in cls.procedures){
            if(procedure.name.name == '[]')
              mapGetProcedure = procedure;
          }
        }
      }
    }
    Map<String,AspectdItemInfo> callInfoMap = Map<String, AspectdItemInfo>();
    Map<String,AspectdItemInfo> executeInfoMap = Map<String, AspectdItemInfo>();
    Map<String,AspectdItemInfo> injectInfoMap = Map<String, AspectdItemInfo>();
    aspectdInfoMap.forEach((String key, AspectdItemInfo aspectdItemInfo){
      if(aspectdItemInfo.mode == AspectdMode.Call) {
        callInfoMap.putIfAbsent(key, ()=>aspectdItemInfo);
      } else if(aspectdItemInfo.mode == AspectdMode.Execute) {
        executeInfoMap.putIfAbsent(key, ()=>aspectdItemInfo);
      } else if(aspectdItemInfo.mode == AspectdMode.Inject) {
        injectInfoMap.putIfAbsent(key, ()=>aspectdItemInfo);
      }
    });

    AspectdUtils.pointCutProceedProcedure = pointCutProceedProcedure;
    AspectdUtils.listGetProcedure = listGetProcedure;
    AspectdUtils.mapGetProcedure = mapGetProcedure;
    AspectdUtils.platformStrongComponent = platformStrongComponent;

    // Aspectd call transformer
    if(callInfoMap.keys.length>0) {
      final AspectdCallImplTransformer aspectdCallImplTransformer =
      AspectdCallImplTransformer(
        callInfoMap,
        libraryMap,
        concatUriToSource,
      );

      for (Library library in libraries) {
        if (library.isExternal) {
          continue;
        }
        aspectdCallImplTransformer.visitLibrary(library);
      }
    }
    // Aspectd execute transformer
    if(executeInfoMap.keys.length>0) {
      AspectdExecuteImplTransformer(
          executeInfoMap,
          libraryMap
      )..aspectdTransform();
    }
    // Aspectd inject transformer
    if(injectInfoMap.keys.length>0) {
      AspectdInjectImplTransformer(
          injectInfoMap,
          libraryMap,
          concatUriToSource
      )..aspectdTransform();
    }
  }

  void _resolveAspectdProcedures(Iterable<Library> libraries) {
    for (Library library in libraries) {
      List<Class> classes = library.classes;
      for(Class cls in classes){
        final bool aspectdEnabled = AspectdUtils.checkIfClassEnableAspectd(cls.annotations);
        if(!aspectdEnabled)
          continue;
        for(Member member in cls.members){
          if(!(member is Procedure))
            continue;
          AspectdItemInfo aspectdItemInfo =  _processAspectdProcedure(member as Procedure);
          if(aspectdItemInfo != null) {
            String uniqueKeyForMethod = AspectdItemInfo.uniqueKeyForMethod(aspectdItemInfo.importUri, aspectdItemInfo.clsName, aspectdItemInfo.methodName, aspectdItemInfo.isStatic, aspectdItemInfo.lineNum);
            aspectdInfoMap.putIfAbsent(uniqueKeyForMethod,()=>aspectdItemInfo);
          }
        }
      }
    }
  }

  AspectdItemInfo _processAspectdProcedure(Procedure procedure){
    for(Expression annotation in procedure.annotations){
      //Release mode
      if(annotation is ConstantExpression){
        ConstantExpression constantExpression = annotation;
        Constant constant = constantExpression.constant;
        if(constant is InstanceConstant){
          InstanceConstant instanceConstant = constant;
          CanonicalName canonicalName =  instanceConstant.classReference.canonicalName;
          AspectdMode aspectdMode = AspectdUtils.getAspectdModeByNameAndImportUri(canonicalName.name,canonicalName?.parent?.name);
          if(aspectdMode == null)
            continue;
          String importUri;
          String clsName;
          String methodName;
          int lineNum;
          instanceConstant.fieldValues.forEach((Reference reference,Constant constant){
            if(constant is StringConstant){
              String value = constant.value;
              if(reference?.canonicalName?.name == AspectdUtils.kAspectdAnnotationImportUri) {
                importUri = value;
              } else if(reference?.canonicalName?.name == AspectdUtils.kAspectdAnnotationClsName) {
                clsName = value;
              } else if(reference?.canonicalName?.name == AspectdUtils.kAspectdAnnotationMethodName) {
                methodName = value;
              }
            }
            if(constant is IntConstant){
              int value = constant.value;
              if(reference?.canonicalName?.name == AspectdUtils.kAspectdAnnotationLineNum) {
                lineNum = value-1;
              }
            }
          });
          bool isStatic = false;
          if(methodName.startsWith(AspectdUtils.kAspectdAnnotationInstanceMethodPrefix)){
            methodName = methodName.substring(AspectdUtils.kAspectdAnnotationInstanceMethodPrefix.length);
          } else if(methodName.startsWith(AspectdUtils.kAspectdAnnotationStaticMethodPrefix)){
            methodName = methodName.substring(AspectdUtils.kAspectdAnnotationStaticMethodPrefix.length);
            isStatic = true;
          }
          return AspectdItemInfo(importUri: importUri,clsName: clsName,methodName: methodName, isStatic: isStatic,aspectdProcedure: procedure,mode: aspectdMode, lineNum: lineNum);
        }
      }
      //Debug Mode
      else if(annotation is ConstructorInvocation){
        ConstructorInvocation constructorInvocation = annotation;
        Class cls = constructorInvocation?.targetReference?.node?.parent as Class;
        AspectdMode aspectdMode = AspectdUtils.getAspectdModeByNameAndImportUri(cls.name,(cls?.parent as Library).importUri.toString());
        if(aspectdMode == null)
          continue;
        String importUri = (constructorInvocation.arguments.positional[0] as StringLiteral).value;
        String clsName = (constructorInvocation.arguments.positional[1] as StringLiteral).value;
        String methodName = (constructorInvocation.arguments.positional[2] as StringLiteral).value;
        int lineNum;
        constructorInvocation.arguments.named.forEach((namedExpression) {
          if(namedExpression.name == AspectdUtils.kAspectdAnnotationLineNum)
            lineNum = (namedExpression.value as IntLiteral).value-1;
        });
        bool isStatic = false;
        if(methodName.startsWith(AspectdUtils.kAspectdAnnotationInstanceMethodPrefix)){
          methodName = methodName.substring(AspectdUtils.kAspectdAnnotationInstanceMethodPrefix.length);
        } else if(methodName.startsWith(AspectdUtils.kAspectdAnnotationStaticMethodPrefix)){
          methodName = methodName.substring(AspectdUtils.kAspectdAnnotationStaticMethodPrefix.length);
          isStatic = true;
        }
        return AspectdItemInfo(importUri: importUri,clsName: clsName,methodName: methodName, isStatic: isStatic,aspectdProcedure: procedure,mode: aspectdMode, lineNum: lineNum);
      }
    }
    return null;
  }
}