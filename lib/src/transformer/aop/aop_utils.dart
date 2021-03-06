import 'dart:convert';

import 'package:kernel/ast.dart';

import 'aop_iteminfo.dart';
import 'aop_mode.dart';

class AopUtils {
  AopUtils();

  static String kAopAnnotationClassCall = 'Call';
  static String kAopAnnotationClassExecute = 'Execute';
  static String kAopAnnotationClassInject = 'Inject';
  static String kImportUriAopAspect =
      'package:aspectd/src/plugins/aop/annotation/aspect.dart';
  static String kImportUriAopCall =
      'package:aspectd/src/plugins/aop/annotation/call.dart';
  static String kImportUriAopExecute =
      'package:aspectd/src/plugins/aop/annotation/execute.dart';
  static String kImportUriAopInject =
      'package:aspectd/src/plugins/aop/annotation/inject.dart';
  static String kImportUriPointCut =
      'package:aspectd/src/plugins/aop/annotation/pointcut.dart';
  static String kAopUniqueKeySeperator = '#';
  static String kAopAnnotationClassAspect = 'Aspect';
  static String kAopAnnotationImportUri = 'importUri';
  static String kAopAnnotationClsName = 'clsName';
  static String kAopAnnotationMethodName = 'methodName';
  static String kAopAnnotationIsRegex = 'isRegex';
  static String kAopAnnotationLineNum = 'lineNum';
  static String kAopAnnotationClassPointCut = 'PointCut';
  static String kAopAnnotationInstanceMethodPrefix = '-';
  static String kAopAnnotationStaticMethodPrefix = '+';
  static int kPrimaryKeyAopMethod = 0;
  static String kAopStubMethodPrefix = 'aop_stub_';
  static String kAopPointcutProcessName = 'proceed';
  static String kAopPointcutIgnoreVariableDeclaration = '//Aspectd Ignore';
  static Procedure pointCutProceedProcedure;
  static Procedure listGetProcedure;
  static Procedure mapGetProcedure;
  static Component platformStrongComponent;
  static Set<Procedure> manipulatedProcedureSet = {};

  static AopMode getAopModeByNameAndImportUri(String name, String importUri) {
    if (name == kAopAnnotationClassCall && importUri == kImportUriAopCall) {
      return AopMode.Call;
    }
    if (name == kAopAnnotationClassExecute &&
        importUri == kImportUriAopExecute) {
      return AopMode.Execute;
    }
    if (name == kAopAnnotationClassInject && importUri == kImportUriAopInject) {
      return AopMode.Inject;
    }
    return null;
  }

  //Generic Operation
  static void insertLibraryDependency(Library library, Library dependLibrary) {
    for (LibraryDependency dependency in library.dependencies) {
      if (dependency.importedLibraryReference.node == dependLibrary) {
        return;
      }
    }
    library.dependencies.add(LibraryDependency.import(dependLibrary));
  }

  static int getLineStartNumForStatement(Source source, Statement statement) {
    int fileOffset = statement.fileOffset;
    if (fileOffset == -1) {
      if (statement is ExpressionStatement) {
        final ExpressionStatement expressionStatement = statement;
        fileOffset = expressionStatement.expression.fileOffset;
      } else if (statement is AssertStatement) {
        final AssertStatement assertStatement = statement;
        fileOffset = assertStatement.conditionStartOffset;
      } else if (statement is LabeledStatement) {
        fileOffset = statement.body.fileOffset;
      }
    }
    return getLineNumBySourceAndOffset(source, fileOffset);
  }

  static int getLineStartNumForInitializer(
      Source source, Initializer initializer) {
    int fileOffset = initializer.fileOffset;
    if (fileOffset == -1) {
      if (initializer is AssertInitializer) {
        fileOffset = initializer.statement.conditionStartOffset;
      }
    }
    return getLineNumBySourceAndOffset(source, fileOffset);
  }

  static int getLineNumBySourceAndOffset(Source source, int fileOffset) {
    final int lineNum = source.lineStarts.length;
    for (int i = 0; i < lineNum; i++) {
      final int lineStart = source.lineStarts[i];
      if (fileOffset >= lineStart &&
          (i == lineNum - 1 || fileOffset < source.lineStarts[i + 1])) {
        return i;
      }
    }
    return -1;
  }

  static VariableDeclaration checkIfSkipableVarDeclaration(
      Source source, Statement statement) {
    if (statement is VariableDeclaration) {
      final VariableDeclaration variableDeclaration = statement;
      final int lineNum = AopUtils.getLineNumBySourceAndOffset(
          source, variableDeclaration.fileOffset);
      if (lineNum == -1) {
        return null;
      }
      final int charFrom = source.lineStarts[lineNum];
      int charTo = source.source.length;
      if (lineNum < source.lineStarts.length - 1) {
        charTo = source.lineStarts[lineNum + 1];
      }
      final String sourceString = const Utf8Decoder().convert(source.source);
      final String sourceLine = sourceString.substring(charFrom, charTo);
      if (sourceLine.endsWith(AopUtils.kAopPointcutIgnoreVariableDeclaration)) {
        return variableDeclaration;
      }
    }
    return null;
  }

  static List<String> getPropertyKeyPaths(String propertyDesc) {
    final List<String> tmpItems = propertyDesc.split('.');
    final List<String> items = <String>[];
    for (String item in tmpItems) {
      final int idx1 = item.lastIndexOf('::');
      final int idx2 = item.lastIndexOf('}');
      if (idx1 != -1 && idx2 != -1) {
        items.add(item.substring(idx1 + 2, idx2));
      } else {
        items.add(item);
      }
    }
    return items;
  }

  static Class findClassFromThisWithKeypath(
      Class thisClass, List<String> keypaths) {
    final int len = keypaths.length;
    Class cls = thisClass;
    for (int i = 0; i < len - 1; i++) {
      final String part = keypaths[i];
      if (part == 'this') {
        continue;
      }
      for (Field field in cls.fields) {
        if (field.name.name == part) {
          final InterfaceType interfaceType = field.type;
          cls = interfaceType.className.node;
          break;
        }
      }
    }
    return cls;
  }

  static Field findFieldForClassWithName(Class cls, String fieldName) {
    for (Field field in cls.fields) {
      if (field.name.name == fieldName) {
        return field;
      }
    }
    return null;
  }

  static bool isAsyncFunctionNode(FunctionNode functionNode) {
    return functionNode.dartAsyncMarker == AsyncMarker.Async ||
        functionNode.dartAsyncMarker == AsyncMarker.AsyncStar;
  }

  static Node getNodeToVisitRecursively(Object statement) {
    if (statement is FunctionDeclaration) {
      return statement.function;
    }
    if (statement is LabeledStatement) {
      return statement.body;
    }
    if (statement is IfStatement) {
      return statement.then;
    }
    if (statement is ForInStatement) {
      return statement.body;
    }
    if (statement is ForStatement) {
      return statement.body;
    }
    return null;
  }

  static void concatArgumentsForAopMethod(
      Map<String, String> sourceInfo,
      Arguments redirectArguments,
      String stubKey,
      Expression targetExpression,
      Member member,
      Arguments invocationArguments) {
    final String stubKeyDefault =
        '${AopUtils.kAopStubMethodPrefix}${AopUtils.kPrimaryKeyAopMethod}';
    //重定向到AOP的函数体中去
    final Arguments pointCutConstructorArguments = Arguments.empty();
    final List<MapEntry> sourceInfos = <MapEntry>[];
    sourceInfo?.forEach((String key, String value) {
      sourceInfos.add(MapEntry(StringLiteral(key), StringLiteral(value)));
    });
    pointCutConstructorArguments.positional.add(MapLiteral(sourceInfos));
    pointCutConstructorArguments.positional.add(targetExpression);
    String memberName = member?.name?.name;
    if (member is Constructor) {
      memberName = AopUtils.nameForConstructor(member);
    }
    pointCutConstructorArguments.positional.add(StringLiteral(memberName));
    pointCutConstructorArguments.positional
        .add(StringLiteral(stubKey ?? stubKeyDefault));
    pointCutConstructorArguments.positional
        .add(ListLiteral(invocationArguments.positional));
    final List<MapEntry> entries = <MapEntry>[];
    for (NamedExpression namedExpression in invocationArguments.named) {
      entries.add(
          MapEntry(StringLiteral(namedExpression.name), namedExpression.value));
    }
    pointCutConstructorArguments.positional.add(MapLiteral(entries));

    final Class pointCutProceedProcedureCls = pointCutProceedProcedure.parent;
    final ConstructorInvocation pointCutConstructorInvocation =
        ConstructorInvocation(pointCutProceedProcedureCls.constructors.first,
            pointCutConstructorArguments);
    redirectArguments.positional.add(pointCutConstructorInvocation);
  }

  static Arguments concatArguments4PointcutStubCall(Member member) {
    final Arguments arguments = Arguments.empty();
    int i = 0;
    for (VariableDeclaration variableDeclaration
        in member.function.positionalParameters) {
      final Arguments getArguments = Arguments.empty();
      getArguments.positional.add(IntLiteral(i));
      final MethodInvocation methodInvocation = MethodInvocation(
          PropertyGet(ThisExpression(), Name('positionalParams')),
          listGetProcedure.name,
          getArguments);
      final AsExpression asExpression = AsExpression(methodInvocation,
          deepCopyASTNode(variableDeclaration.type, ignoreGenerics: true));
      arguments.positional.add(asExpression);
      i++;
    }
    final List<NamedExpression> namedEntries = <NamedExpression>[];
    for (VariableDeclaration variableDeclaration
        in member.function.namedParameters) {
      final Arguments getArguments = Arguments.empty();
      getArguments.positional.add(StringLiteral(variableDeclaration.name));
      final MethodInvocation methodInvocation = MethodInvocation(
          PropertyGet(ThisExpression(), Name('namedParams')),
          mapGetProcedure.name,
          getArguments);
      final AsExpression asExpression = AsExpression(methodInvocation,
          deepCopyASTNode(variableDeclaration.type, ignoreGenerics: true));
      namedEntries.add(NamedExpression(variableDeclaration.name, asExpression));
    }
    if (namedEntries.isNotEmpty) {
      arguments.named.addAll(namedEntries);
    }
    return arguments;
  }

  static void insertProceedBranch(Procedure procedure, bool shouldReturn) {
    final Block block = pointCutProceedProcedure.function.body;
    final String methodName = procedure.name.name;
    final MethodInvocation methodInvocation =
        MethodInvocation(ThisExpression(), Name(methodName), Arguments.empty());
    final List<Statement> statements = block.statements;
    statements.insert(
        statements.length - 1,
        IfStatement(
            MethodInvocation(PropertyGet(ThisExpression(), Name('stubKey')),
                Name('=='), Arguments(<Expression>[StringLiteral(methodName)])),
            Block(<Statement>[
              if (shouldReturn) ReturnStatement(methodInvocation),
              if (!shouldReturn) ExpressionStatement(methodInvocation),
            ]),
            null));
  }

  static bool canOperateLibrary(Library library) {
    if (platformStrongComponent != null &&
        platformStrongComponent.libraries.contains(library)) {
      return false;
    }
    return true;
  }

  static Block createProcedureBodyWithExpression(
      Expression expression, bool shouldReturn) {
    final Block bodyStatements = Block(<Statement>[]);
    if (shouldReturn) {
      bodyStatements.addStatement(ReturnStatement(expression));
    } else {
      bodyStatements.addStatement(ExpressionStatement(expression));
    }
    return bodyStatements;
  }

  // Skip aop operation for those aspectd/aop package.
  static bool checkIfSkipAOP(AopItemInfo aopItemInfo, Library curLibrary) {
    final Library aopLibrary1 = aopItemInfo.aopMember.parent.parent;
    final Library aopLibrary2 = pointCutProceedProcedure.parent.parent;
    if (curLibrary == aopLibrary1 || curLibrary == aopLibrary2) {
      return true;
    }
    return false;
  }

  static bool checkIfClassEnableAspectd(List<Expression> annotations) {
    bool enabled = false;
    for (Expression annotation in annotations) {
      //Release Mode
      if (annotation is ConstantExpression) {
        final ConstantExpression constantExpression = annotation;
        final Constant constant = constantExpression.constant;
        if (constant is InstanceConstant) {
          final InstanceConstant instanceConstant = constant;
          final Class instanceClass = instanceConstant.classReference.node;
          if (instanceClass.name == AopUtils.kAopAnnotationClassAspect &&
              AopUtils.kImportUriAopAspect ==
                  (instanceClass?.parent as Library)?.importUri.toString()) {
            enabled = true;
            break;
          }
        }
      }
      //Debug Mode
      else if (annotation is ConstructorInvocation) {
        final ConstructorInvocation constructorInvocation = annotation;
        final Class cls = constructorInvocation.targetReference.node?.parent;
        if (cls == null) {
          continue;
        }
        final Library library = cls?.parent;
        if (cls.name == AopUtils.kAopAnnotationClassAspect &&
            library.importUri.toString() == AopUtils.kImportUriAopAspect) {
          enabled = true;
          break;
        }
      }
    }
    return enabled;
  }

  static Map<String, String> calcSourceInfo(
      Map<Uri, Source> uriToSource, Library library, int fileOffset) {
    final Map<String, String> sourceInfo = <String, String>{};
    String importUri = library.importUri.toString();
    final int idx = importUri.lastIndexOf('/');
    if (idx != -1) {
      importUri = importUri.substring(0, idx);
    }
    final Uri fileUri = library.fileUri;
    final Source source = uriToSource[fileUri];
    int lineNum;
    int lineOffSet;
    final int lineStartCnt = source.lineStarts.length;
    for (int i = 0; i < lineStartCnt; i++) {
      final int lineStartIdx = source.lineStarts[i];
      if (lineStartIdx <= fileOffset &&
          (i == lineStartCnt - 1 || source.lineStarts[i + 1] > fileOffset)) {
        lineNum = i;
        lineOffSet = fileOffset - lineStartIdx;
        break;
      }
    }
    sourceInfo.putIfAbsent('library', () => importUri);
    sourceInfo.putIfAbsent('file', () => fileUri.toString());
    sourceInfo.putIfAbsent('lineNum', () => '${lineNum + 1}');
    sourceInfo.putIfAbsent('lineOffset', () => '$lineOffSet');
    return sourceInfo;
  }

  static Procedure createStubProcedure(Name methodName, AopItemInfo aopItemInfo,
      Procedure referProcedure, Statement bodyStatements, bool shouldReturn) {
    final FunctionNode functionNode = FunctionNode(bodyStatements,
        typeParameters: deepCopyASTNodes<TypeParameter>(
            referProcedure.function.typeParameters),
        positionalParameters: referProcedure.function.positionalParameters,
        namedParameters: referProcedure.function.namedParameters,
        requiredParameterCount: referProcedure.function.requiredParameterCount,
        returnType: shouldReturn
            ? deepCopyASTNode(referProcedure.function.returnType)
            : const VoidType(),
        asyncMarker: referProcedure.function.asyncMarker,
        dartAsyncMarker: referProcedure.function.dartAsyncMarker);
    final Procedure procedure = Procedure(
      Name(methodName.name, methodName.library),
      ProcedureKind.Method,
      functionNode,
      isStatic: referProcedure.isStatic,
      fileUri: referProcedure.fileUri,
      stubKind : referProcedure.stubKind,
      stubTarget: referProcedure.stubTarget,
    );

    procedure.fileOffset = referProcedure.fileOffset;
    procedure.fileEndOffset = referProcedure.fileEndOffset;
    procedure.startFileOffset = referProcedure.startFileOffset;
    manipulatedProcedureSet.add(procedure);
    return procedure;
  }

  static Constructor createStubConstructor(
      Name methodName,
      AopItemInfo aopItemInfo,
      Constructor referConstructor,
      Statement bodyStatements,
      bool shouldReturn) {
    final FunctionNode functionNode = FunctionNode(bodyStatements,
        typeParameters: deepCopyASTNodes<TypeParameter>(
            referConstructor.function.typeParameters),
        positionalParameters: referConstructor.function.positionalParameters,
        namedParameters: referConstructor.function.namedParameters,
        requiredParameterCount:
            referConstructor.function.requiredParameterCount,
        returnType: shouldReturn
            ? deepCopyASTNode(referConstructor.function.returnType)
            : const VoidType(),
        asyncMarker: referConstructor.function.asyncMarker,
        dartAsyncMarker: referConstructor.function.dartAsyncMarker);
    final Constructor constructor = Constructor(functionNode,
        name: Name(methodName.name, methodName.library),
        isConst: referConstructor.isConst,
        isExternal: referConstructor.isExternal,
        isSynthetic: referConstructor.isSynthetic,
        initializers: deepCopyASTNodes(referConstructor.initializers),
        transformerFlags: referConstructor.transformerFlags,
        fileUri: referConstructor.fileUri,
        reference: Reference()..node = referConstructor.reference.node);

    constructor.fileOffset = referConstructor.fileOffset;
    constructor.fileEndOffset = referConstructor.fileEndOffset;
    constructor.startFileOffset = referConstructor.startFileOffset;
    return constructor;
  }

  static dynamic deepCopyASTNode(dynamic node,
      {bool isReturnType = false, bool ignoreGenerics = false}) {
    if (node is TypeParameter) {
      if (ignoreGenerics)
        return TypeParameter(node.name, node.bound, node.defaultType);
    }
    if (node is VariableDeclaration) {
      return VariableDeclaration(
        node.name,
        initializer: node.initializer,
        type: deepCopyASTNode(node.type),
        flags: node.flags,
        isFinal: node.isFinal,
        isConst: node.isConst,
        isFieldFormal: node.isFieldFormal,
        isCovariant: node.isCovariant,
      );
    }
    if (node is TypeParameterType) {
      if (isReturnType || ignoreGenerics) {
        return const DynamicType();
      }
      return TypeParameterType(
          deepCopyASTNode(node.parameter), node.nullability,deepCopyASTNode(node.promotedBound));
    }
    if (node is FunctionType) {
      return FunctionType(
          deepCopyASTNodes(node.positionalParameters),
          deepCopyASTNode(node.returnType, isReturnType: true),
          Nullability.legacy,
          namedParameters: deepCopyASTNodes(node.namedParameters),
          typeParameters: deepCopyASTNodes(node.typeParameters),
          requiredParameterCount: node.requiredParameterCount,
          typedefType: deepCopyASTNode(node.typedefType,
              ignoreGenerics: ignoreGenerics));
    }
    if (node is TypedefType) {
      return TypedefType(node.typedefNode, Nullability.legacy,
          deepCopyASTNodes(node.typeArguments, ignoreGeneric: ignoreGenerics));
    }
    return node;
  }

  static List<T> deepCopyASTNodes<T>(List<T> nodes,
      {bool ignoreGeneric = false}) {
    final List<T> newNodes = <T>[];
    for (T node in nodes) {
      final dynamic newNode =
          deepCopyASTNode(node, ignoreGenerics: ignoreGeneric);
      if (newNode != null) {
        newNodes.add(newNode);
      }
    }
    return newNodes;
  }

  static Arguments argumentsFromFunctionNode(FunctionNode functionNode) {
    final List<Expression> positional = <Expression>[];
    final List<NamedExpression> named = <NamedExpression>[];
    for (VariableDeclaration variableDeclaration
        in functionNode.positionalParameters) {
      positional.add(VariableGet(variableDeclaration));
    }
    for (VariableDeclaration variableDeclaration
        in functionNode.namedParameters) {
      named.add(NamedExpression(
          variableDeclaration.name, VariableGet(variableDeclaration)));
    }
    return Arguments(positional, named: named);
  }

  static String nameForConstructor(Constructor constructor) {
    final Class constructorCls = constructor.parent;
    String constructorName = '${constructorCls.name}';
    if (constructor.name.name.isNotEmpty) {
      constructorName += '.${constructor.name.name}';
    }
    return constructorName;
  }
}
