import 'package:kernel/ast.dart';
import 'transformer/aop_callimpl_transformer.dart';
import 'transformer/aop_executeimpl_transformer.dart';
import 'transformer/aop_injectimpl_transformer.dart';

import 'transformer/aop_iteminfo.dart';
import 'transformer/aop_mode.dart';
import 'transformer/aop_utils.dart';

class AopWrapperTransformer {
  Map<String,AopItemInfo> aopInfoMap = Map<String, AopItemInfo>();
  Component platformStrongComponent;

  AopWrapperTransformer({this.platformStrongComponent});

  void transform(Component program) {
    final List<Library> libraries = program.libraries;

    if (libraries.isEmpty) {
      return;
    }

    _resolveAopProcedures(libraries);

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
      for (Class cls in library.classes) {
        String clsName = cls.name;
        if (clsName == AopUtils.kAopAnnotationClassPointCut && importUri.toString() == AopUtils.kImportUriPointCut) {
          for (Procedure procedure in cls.procedures) {
            if (procedure.name.name == AopUtils.kAopPointcutProcessName) {
              pointCutProceedProcedure = procedure;
            }
          }
        }
        if (clsName == 'List' && importUri.toString() == 'dart:core') {
          for (Procedure procedure in cls.procedures) {
            if (procedure.name.name == '[]') {
              listGetProcedure = procedure;
            }
          }
        }
        if (clsName == 'Map' && importUri.toString() == 'dart:core') {
          for (Procedure procedure in cls.procedures) {
            if (procedure.name.name == '[]') {
              mapGetProcedure = procedure;
            }
          }
        }
      }
    }
    Map<String,AopItemInfo> callInfoMap = Map<String, AopItemInfo>();
    Map<String,AopItemInfo> executeInfoMap = Map<String, AopItemInfo>();
    Map<String,AopItemInfo> injectInfoMap = Map<String, AopItemInfo>();
    aopInfoMap.forEach((String key, AopItemInfo aopItemInfo) {
      if (aopItemInfo.mode == AopMode.Call) {
        callInfoMap.putIfAbsent(key, ()=>aopItemInfo);
      } else if (aopItemInfo.mode == AopMode.Execute) {
        executeInfoMap.putIfAbsent(key, ()=>aopItemInfo);
      } else if (aopItemInfo.mode == AopMode.Inject) {
        injectInfoMap.putIfAbsent(key, ()=>aopItemInfo);
      }
    });

    AopUtils.pointCutProceedProcedure = pointCutProceedProcedure;
    AopUtils.listGetProcedure = listGetProcedure;
    AopUtils.mapGetProcedure = mapGetProcedure;
    AopUtils.platformStrongComponent = platformStrongComponent;

    // Aop call transformer
    if (callInfoMap.keys.length>0) {
      final AopCallImplTransformer aopCallImplTransformer =
      AopCallImplTransformer(
        callInfoMap,
        libraryMap,
        concatUriToSource,
      );

      for (Library library in libraries) {
        if (library.isExternal) {
          continue;
        }
        aopCallImplTransformer.visitLibrary(library);
      }
    }
    // Aop execute transformer
    if (executeInfoMap.keys.length>0) {
      AopExecuteImplTransformer(
          executeInfoMap,
          libraryMap
      )..aopTransform();
    }
    // Aop inject transformer
    if (injectInfoMap.keys.length>0) {
      AopInjectImplTransformer(
          injectInfoMap,
          libraryMap,
          concatUriToSource
      )..aopTransform();
    }
  }

  void _resolveAopProcedures(Iterable<Library> libraries) {
    for (Library library in libraries) {
      List<Class> classes = library.classes;
      for (Class cls in classes) {
        final bool aspectdEnabled = AopUtils.checkIfClassEnableAspectd(cls.annotations);
        if (!aspectdEnabled) {
          continue;
        }
        for (Member member in cls.members) {
          if (!(member is Member)) {
            continue;
          }
          AopItemInfo aopItemInfo =  _processAopMember(member);
          if (aopItemInfo != null) {
            String uniqueKeyForMethod = AopItemInfo.uniqueKeyForMethod(aopItemInfo.importUri, aopItemInfo.clsName, aopItemInfo.methodName, aopItemInfo.isStatic, aopItemInfo.lineNum);
            aopInfoMap.putIfAbsent(uniqueKeyForMethod,()=>aopItemInfo);
          }
        }
      }
    }
  }

  AopItemInfo _processAopMember(Member member) {
    for (Expression annotation in member.annotations) {
      //Release mode
      if (annotation is ConstantExpression) {
        ConstantExpression constantExpression = annotation;
        Constant constant = constantExpression.constant;
        if (constant is InstanceConstant) {
          InstanceConstant instanceConstant = constant;
          CanonicalName canonicalName =  instanceConstant.classReference.canonicalName;
          AopMode aopMode = AopUtils.getAopModeByNameAndImportUri(canonicalName.name,canonicalName?.parent?.name);
          if (aopMode == null) {
            continue;
          }
          String importUri;
          String clsName;
          String methodName;
          bool isRegex;
          int lineNum;
          instanceConstant.fieldValues.forEach((Reference reference,Constant constant) {
            if (constant is StringConstant) {
              String value = constant.value;
              if (reference?.canonicalName?.name == AopUtils.kAopAnnotationImportUri) {
                importUri = value;
              } else if (reference?.canonicalName?.name == AopUtils.kAopAnnotationClsName) {
                clsName = value;
              } else if (reference?.canonicalName?.name == AopUtils.kAopAnnotationMethodName) {
                methodName = value;
              }
            }
            if (constant is IntConstant) {
              int value = constant.value;
              if (reference?.canonicalName?.name == AopUtils.kAopAnnotationLineNum) {
                lineNum = value-1;
              }
            }
            if (constant is BoolConstant) {
              bool value = constant.value;
              if (reference?.canonicalName?.name == AopUtils.kAopAnnotationIsRegex) {
                isRegex = value;
              }
            }
          });
          bool isStatic = false;
          if (methodName.startsWith(AopUtils.kAopAnnotationInstanceMethodPrefix)) {
            methodName = methodName.substring(AopUtils.kAopAnnotationInstanceMethodPrefix.length);
          } else if (methodName.startsWith(AopUtils.kAopAnnotationStaticMethodPrefix)) {
            methodName = methodName.substring(AopUtils.kAopAnnotationStaticMethodPrefix.length);
            isStatic = true;
          }
          return AopItemInfo(importUri: importUri,clsName: clsName,methodName: methodName, isStatic: isStatic, aopMember: member, mode: aopMode, isRegex: (isRegex==true?true:false), lineNum: lineNum);
        }
      }
      //Debug Mode
      else if (annotation is ConstructorInvocation) {
        ConstructorInvocation constructorInvocation = annotation;
        Class cls = constructorInvocation?.targetReference?.node?.parent as Class;
        AopMode aopMode = AopUtils.getAopModeByNameAndImportUri(cls?.name,(cls?.parent as Library)?.importUri?.toString());
        if (aopMode == null) {
          continue;
        }
        String importUri = (constructorInvocation.arguments.positional[0] as StringLiteral).value;
        String clsName = (constructorInvocation.arguments.positional[1] as StringLiteral).value;
        String methodName = (constructorInvocation.arguments.positional[2] as StringLiteral).value;
        bool isRegex;
        int lineNum;
        constructorInvocation.arguments.named.forEach((namedExpression) {
          if (namedExpression.name == AopUtils.kAopAnnotationLineNum) {
            lineNum = (namedExpression.value as IntLiteral).value - 1;
          }
          if (namedExpression.name == AopUtils.kAopAnnotationIsRegex) {
            isRegex = (namedExpression.value as BoolLiteral).value;
          }
        });
        bool isStatic = false;
        if (methodName.startsWith(AopUtils.kAopAnnotationInstanceMethodPrefix)) {
          methodName = methodName.substring(AopUtils.kAopAnnotationInstanceMethodPrefix.length);
        } else if (methodName.startsWith(AopUtils.kAopAnnotationStaticMethodPrefix)) {
          methodName = methodName.substring(AopUtils.kAopAnnotationStaticMethodPrefix.length);
          isStatic = true;
        }
        return AopItemInfo(importUri: importUri,clsName: clsName,methodName: methodName, isStatic: isStatic, aopMember: member,mode: aopMode, isRegex: (isRegex==true?true:false), lineNum: lineNum);
      }
    }
    return null;
  }
}