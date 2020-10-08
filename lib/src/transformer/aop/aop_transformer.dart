// Transformer/visitor for toString
// If we add any more of these, they really should go into a separate library.

import 'package:args/args.dart';
import 'package:frontend_server/frontend_server.dart' as frontend
    show
        FrontendCompiler,
        CompilerInterface,
        listenAndCompile,
        argParser,
        usage,
        ProgramTransformer;
import 'package:kernel/ast.dart';
import 'package:path/path.dart' as path;
import 'package:vm/incremental_compiler.dart';
import 'package:vm/target/flutter.dart';

import 'aop_iteminfo.dart';
import 'aop_mode.dart';
import 'aop_utils.dart';
import 'aspectd_aop_call_visitor.dart';
import 'aspectd_aop_execute_visitor.dart';
import 'aspectd_aop_inject_visitor.dart';

/// Replaces [Object.toString] overrides with calls to super for the specified
/// [packageUris].
class AspectdAopTransformer extends FlutterProgramTransformer {
  /// The [packageUris] parameter must not be null, but may be empty.
  AspectdAopTransformer();

  Component platformStrongComponent;
  final List<AopItemInfo> aopItemInfoList = <AopItemInfo>[];
  final List<AopItemInfo> callInfoList = <AopItemInfo>[];
  final List<AopItemInfo> executeInfoList = <AopItemInfo>[];
  final List<AopItemInfo> injectInfoList = <AopItemInfo>[];
  final Map<String, Library> libraryMap = <String, Library>{};
  final Map<Uri, Source> concatUriToSource = <Uri, Source>{};

  @override
  void transform(Component component) {
    prepareAopItemInfo(component);
    if (callInfoList.isNotEmpty) {
      component.transformChildren(
          AspectdAopCallVisitor(callInfoList, concatUriToSource, libraryMap));
    }
    if (executeInfoList.isNotEmpty) {
      component.visitChildren(AspectdAopExecuteVisitor(executeInfoList));
    }
    if (injectInfoList.isNotEmpty) {
      component.visitChildren(
          AspectdAopInjectVisitor(injectInfoList, concatUriToSource));
    }
  }

  void prepareAopItemInfo(Component program) {
    final List<Library> libraries = program.libraries;

    if (libraries.isEmpty) {
      return;
    }

    _resolveAopProcedures(libraries);
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
    concatUriToSource
      ..addAll(program.uriToSource)
      ..addAll(platformStrongComponent != null
          ? platformStrongComponent.uriToSource
          : <Uri, Source>{});
    for (Library library in concatLibraries) {
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
      // final AopCallImplTransformer aopCallImplTransformer =
      // AopCallImplTransformer(
      //   callInfoList,
      //   libraryMap,
      //   concatUriToSource,
      // );

      for (Library library in libraries) {
        // aopCallImplTransformer.visitLibrary(library);
      }
    }
    // Aop execute transformer
    if (executeInfoList.isNotEmpty) {
      // AopExecuteImplTransformer(executeInfoList, libraryMap)..aopTransform();
    }
    // Aop inject transformer
    if (injectInfoList.isNotEmpty) {
      // AopInjectImplTransformer(injectInfoList, libraryMap, concatUriToSource)
      //   ..aopTransform();
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
          final Class instanceClass = instanceConstant.classReference.node;
          final AopMode aopMode = AopUtils.getAopModeByNameAndImportUri(
              instanceClass.name,
              (instanceClass?.parent as Library)?.importUri.toString());
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
              if ((reference?.node as Field)?.name?.toString() ==
                  AopUtils.kAopAnnotationImportUri) {
                importUri = value;
              } else if ((reference?.node as Field)?.name?.toString() ==
                  AopUtils.kAopAnnotationClsName) {
                clsName = value;
              } else if ((reference?.node as Field)?.name?.toString() ==
                  AopUtils.kAopAnnotationMethodName) {
                methodName = value;
              }
            }
            if (constant is IntConstant) {
              final int value = constant.value;
              if ((reference?.node as Field)?.name?.toString() ==
                  AopUtils.kAopAnnotationLineNum) {
                lineNum = value - 1;
              }
            }
            if (constant is BoolConstant) {
              final bool value = constant.value;
              if ((reference?.node as Field)?.name?.toString() ==
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
