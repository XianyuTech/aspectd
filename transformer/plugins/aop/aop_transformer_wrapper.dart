import 'package:kernel/ast.dart';
import 'transformer/aop_callimpl_transformer.dart';
import 'transformer/aop_executeimpl_transformer.dart';
import 'transformer/aop_injectimpl_transformer.dart';

import 'transformer/aop_iteminfo.dart';
import 'transformer/aop_mode.dart';
import 'transformer/aop_utils.dart';

class AopWrapperTransformer {
  AopWrapperTransformer({this.platformStrongComponent});

  List<AopItemInfo> aopItemInfoList = <AopItemInfo>[];
  Component platformStrongComponent;

  void transform(Component program) {
    final List<Library> libraries = program.libraries;

    if (libraries.isEmpty) {
      return;
    }

    _resolveAopProcedures(libraries);

    for (Library library in libraries) {
      // ignore: DEPRECATED_MEMBER_USE
      if (library.isExternal) {
        continue;
      }
    }

    Procedure pointCutProceedProcedure;
    Procedure listGetProcedure;
    Procedure mapGetProcedure;
    //Search the PointCut class first
    final List<Library> concatLibraries = <Library>[
      ...libraries,
      ...platformStrongComponent != null
          ? platformStrongComponent.libraries
          : <Library>[]
    ];
    final Map<Uri, Source> concatUriToSource = <Uri, Source>{}
      ..addAll(program.uriToSource)
      ..addAll(platformStrongComponent != null
          ? platformStrongComponent.uriToSource
          : <Uri, Source>{});
    final Map<String, Library> libraryMap = <String, Library>{};
    for (Library library in concatLibraries) {
      // ignore: DEPRECATED_MEMBER_USE
      if (library.isExternal) {
        continue;
      }
      libraryMap.putIfAbsent(library.importUri.toString(), () => library);
      if (pointCutProceedProcedure != null &&
          listGetProcedure != null &&
          mapGetProcedure != null) {
        continue;
      }
      final Uri importUri = library.importUri;
      for (Class cls in library.classes) {
        final String clsName = cls.name;
        if (clsName == AopUtils.kAopAnnotationClassPointCut &&
            importUri.toString() == AopUtils.kImportUriPointCut) {
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
    final List<AopItemInfo> callInfoList = <AopItemInfo>[];
    final List<AopItemInfo> executeInfoList = <AopItemInfo>[];
    final List<AopItemInfo> injectInfoList = <AopItemInfo>[];
    for (AopItemInfo aopItemInfo in aopItemInfoList) {
      if (aopItemInfo.mode == AopMode.Call) {
        callInfoList.add(aopItemInfo);
      } else if (aopItemInfo.mode == AopMode.Execute) {
        executeInfoList.add(aopItemInfo);
      } else if (aopItemInfo.mode == AopMode.Inject) {
        injectInfoList.add(aopItemInfo);
      }
    }

    AopUtils.pointCutProceedProcedure = pointCutProceedProcedure;
    AopUtils.listGetProcedure = listGetProcedure;
    AopUtils.mapGetProcedure = mapGetProcedure;
    AopUtils.platformStrongComponent = platformStrongComponent;

    // Aop call transformer
    if (callInfoList.isNotEmpty) {
      final AopCallImplTransformer aopCallImplTransformer =
          AopCallImplTransformer(
        callInfoList,
        libraryMap,
        concatUriToSource,
      );

      for (Library library in libraries) {
        // ignore: DEPRECATED_MEMBER_USE
        if (library.isExternal) {
          continue;
        }
        aopCallImplTransformer.visitLibrary(library);
      }
    }
    // Aop execute transformer
    if (executeInfoList.isNotEmpty) {
      AopExecuteImplTransformer(executeInfoList, libraryMap)..aopTransform();
    }
    // Aop inject transformer
    if (injectInfoList.isNotEmpty) {
      AopInjectImplTransformer(injectInfoList, libraryMap, concatUriToSource)
        ..aopTransform();
    }
  }

  void _resolveAopProcedures(Iterable<Library> libraries) {
    for (Library library in libraries) {
      final List<Class> classes = library.classes;
      for (Class cls in classes) {
        final bool aspectdEnabled =
            AopUtils.checkIfClassEnableAspectd(cls.annotations);
        if (!aspectdEnabled) {
          continue;
        }
        for (Member member in cls.members) {
          if (!(member is Member)) {
            continue;
          }
          final AopItemInfo aopItemInfo = _processAopMember(member);
          if (aopItemInfo != null) {
            aopItemInfoList.add(aopItemInfo);
          }
        }
      }
    }
  }

  AopItemInfo _processAopMember(Member member) {
    for (Expression annotation in member.annotations) {
      //Release mode
      if (annotation is ConstantExpression) {
        final ConstantExpression constantExpression = annotation;
        final Constant constant = constantExpression.constant;
        if (constant is InstanceConstant) {
          final InstanceConstant instanceConstant = constant;
          final CanonicalName canonicalName =
              instanceConstant.classReference.canonicalName;
          final AopMode aopMode = AopUtils.getAopModeByNameAndImportUri(
              canonicalName.name, canonicalName?.parent?.name);
          if (aopMode == null) {
            continue;
          }
          String importUri;
          String clsName;
          String methodName;
          bool isRegex = false;
          int lineNum;
          instanceConstant.fieldValues
              .forEach((Reference reference, Constant constant) {
            if (constant is StringConstant) {
              final String value = constant.value;
              if (reference?.canonicalName?.name ==
                  AopUtils.kAopAnnotationImportUri) {
                importUri = value;
              } else if (reference?.canonicalName?.name ==
                  AopUtils.kAopAnnotationClsName) {
                clsName = value;
              } else if (reference?.canonicalName?.name ==
                  AopUtils.kAopAnnotationMethodName) {
                methodName = value;
              }
            }
            if (constant is IntConstant) {
              final int value = constant.value;
              if (reference?.canonicalName?.name ==
                  AopUtils.kAopAnnotationLineNum) {
                lineNum = value - 1;
              }
            }
            if (constant is BoolConstant) {
              final bool value = constant.value;
              if (reference?.canonicalName?.name ==
                  AopUtils.kAopAnnotationIsRegex) {
                isRegex = value;
              }
            }
          });
          bool isStatic = false;
          if (methodName
              .startsWith(AopUtils.kAopAnnotationInstanceMethodPrefix)) {
            methodName = methodName
                .substring(AopUtils.kAopAnnotationInstanceMethodPrefix.length);
          } else if (methodName
              .startsWith(AopUtils.kAopAnnotationStaticMethodPrefix)) {
            methodName = methodName
                .substring(AopUtils.kAopAnnotationStaticMethodPrefix.length);
            isStatic = true;
          }
          return AopItemInfo(
              importUri: importUri,
              clsName: clsName,
              methodName: methodName,
              isStatic: isStatic,
              aopMember: member,
              mode: aopMode,
              isRegex: isRegex,
              lineNum: lineNum);
        }
      }
      //Debug Mode
      else if (annotation is ConstructorInvocation) {
        final ConstructorInvocation constructorInvocation = annotation;
        final Class cls = constructorInvocation?.targetReference?.node?.parent;
        final Library clsParentLib = cls?.parent;
        final AopMode aopMode = AopUtils.getAopModeByNameAndImportUri(
            cls?.name, clsParentLib?.importUri?.toString());
        if (aopMode == null) {
          continue;
        }
        final StringLiteral stringLiteral0 =
            constructorInvocation.arguments.positional[0];
        final String importUri = stringLiteral0.value;
        final StringLiteral stringLiteral1 =
            constructorInvocation.arguments.positional[1];
        final String clsName = stringLiteral1.value;
        final StringLiteral stringLiteral2 =
            constructorInvocation.arguments.positional[2];
        String methodName = stringLiteral2.value;
        bool isRegex = false;
        int lineNum;
        for (NamedExpression namedExpression
            in constructorInvocation.arguments.named) {
          if (namedExpression.name == AopUtils.kAopAnnotationLineNum) {
            final IntLiteral intLiteral = namedExpression.value;
            lineNum = intLiteral.value - 1;
          }
          if (namedExpression.name == AopUtils.kAopAnnotationIsRegex) {
            final BoolLiteral boolLiteral = namedExpression.value;
            isRegex = boolLiteral.value;
          }
        }

        bool isStatic = false;
        if (methodName
            .startsWith(AopUtils.kAopAnnotationInstanceMethodPrefix)) {
          methodName = methodName
              .substring(AopUtils.kAopAnnotationInstanceMethodPrefix.length);
        } else if (methodName
            .startsWith(AopUtils.kAopAnnotationStaticMethodPrefix)) {
          methodName = methodName
              .substring(AopUtils.kAopAnnotationStaticMethodPrefix.length);
          isStatic = true;
        }
        return AopItemInfo(
            importUri: importUri,
            clsName: clsName,
            methodName: methodName,
            isStatic: isStatic,
            aopMember: member,
            mode: aopMode,
            isRegex: isRegex,
            lineNum: lineNum);
      }
    }
    return null;
  }
}
