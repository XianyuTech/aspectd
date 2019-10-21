import 'package:kernel/ast.dart';

import 'aop_iteminfo.dart';
import 'aop_mode.dart';

class AopUtils {
  static String kAopAnnotationClassCall = 'Call';
  static String kAopAnnotationClassExecute = 'Execute';
  static String kAopAnnotationClassInject = 'Inject';
  static String kImportUriAopAspect = 'package:aspectd/src/plugins/aop/annotation/aspect.dart';
  static String kImportUriAopCall = 'package:aspectd/src/plugins/aop/annotation/call.dart';
  static String kImportUriAopExecute = 'package:aspectd/src/plugins/aop/annotation/execute.dart';
  static String kImportUriAopInject = 'package:aspectd/src/plugins/aop/annotation/inject.dart';
  static String kImportUriPointCut = 'package:aspectd/src/plugins/aop/annotation/pointcut.dart';
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

  static AopMode getAopModeByNameAndImportUri(String name, String importUri) {
    if (name == kAopAnnotationClassCall && importUri == kImportUriAopCall) {
      return AopMode.Call;
    }
    if (name == kAopAnnotationClassExecute && importUri == kImportUriAopExecute) {
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
    library.dependencies.add(new LibraryDependency.import(dependLibrary));
  }

  static int getLineStartNumForStatement(Source source, Statement statement) {
    int fileOffset = statement.fileOffset;
    if (fileOffset == -1) {
      if (statement is ExpressionStatement) {
        ExpressionStatement expressionStatement = statement;
        fileOffset = expressionStatement.expression.fileOffset;
      } else if (statement is AssertStatement) {
        AssertStatement assertStatement = statement;
        fileOffset = assertStatement.conditionStartOffset;
      } else if (statement is LabeledStatement) {
        fileOffset = statement.body.fileOffset;
      }
    }
    return getLineNumBySourceAndOffset(source, fileOffset);
  }

  static int getLineStartNumForInitializer(Source source, Initializer initializer) {
    int fileOffset = initializer.fileOffset;
    if (fileOffset == -1) {
      if (initializer is AssertInitializer) {
        fileOffset = initializer.statement.conditionStartOffset;
      }
    }
    return getLineNumBySourceAndOffset(source, fileOffset);
  }

  static int getLineNumBySourceAndOffset(Source source, int fileOffset) {
    int lineNum = source.lineStarts.length;
    for (int i=0;i<lineNum;i++) {
      int lineStart = source.lineStarts[i];
      if (fileOffset>=lineStart && (i==lineNum-1 || fileOffset<source.lineStarts[i+1])) {
        return i;
      }
    }
    return -1;
  }

  static VariableDeclaration checkIfSkipableVarDeclaration(Source source, Statement statement) {
    if (statement is VariableDeclaration) {
      VariableDeclaration variableDeclaration = statement;
      int lineNum = AopUtils.getLineNumBySourceAndOffset(source, variableDeclaration.fileOffset);
      if (lineNum == -1) {
        return null;
      }
      int charFrom = source.lineStarts[lineNum];
      int charTo = source.source.length;
      if (lineNum<source.lineStarts.length-1) {
        charTo = source.lineStarts[lineNum+1];
      }
      List<int> sourceLineChars = source.source.sublist(charFrom,charTo);
      String sourceLine = String.fromCharCodes(sourceLineChars).trim();
      if (sourceLine.endsWith(AopUtils.kAopPointcutIgnoreVariableDeclaration)) {
        return variableDeclaration;
      }
    }
    return null;
  }

  static List<String> getPropertyKeyPaths(String propertyDesc) {
    List<String> tmpItems = propertyDesc.split('.');
    List<String> items = [];
    tmpItems.forEach((item) {
      int idx1 = item.lastIndexOf('::');
      int idx2 = item.lastIndexOf('}');
      if (idx1!=-1 && idx2!=-1) {
        items.add(item.substring(idx1+2,idx2));
      } else {
        items.add(item);
      }
    });
    return items;
  }

  static Class findClassFromThisWithKeypath(Class thisClass, List<String> keypaths) {
    int len = keypaths.length;
    Class cls = thisClass;
    for (int i=0;i<len-1;i++) {
      String part = keypaths[i];
      if (part == 'this') {
        continue;
      }
      for (Field field in cls.fields) {
        if (field.name.name == part) {
          cls = (field.type as InterfaceType).className.node;
          break;
        }
      }
    }
    return cls;
  }

  static Field findFieldForClassWithName(Class cls,String fieldName) {
    for (Field field in cls.fields) {
      if (field.name.name == fieldName) {
        return field;
      }
    }
    return null;
  }

  static bool isAsyncFunctionNode(FunctionNode functionNode) {
    return functionNode.dartAsyncMarker == AsyncMarker.Async || functionNode.dartAsyncMarker == AsyncMarker.AsyncStar;
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
    return null;
  }

  static void concatArgumentsForAopMethod(Map<String, String> sourceInfo,Arguments redirectArguments,AopItemInfo aopItemInfo, Expression targetExpression, Member member,Arguments invocationArguments) {
    String stubMethodName = '${AopUtils.kAopStubMethodPrefix}${AopUtils.kPrimaryKeyAopMethod}';
    //重定向到AOP的函数体中去
    Arguments pointCutConstructorArguments = Arguments.empty();
    List<MapEntry> sourceInfos = List<MapEntry>();
    sourceInfo?.forEach((String key, String value) {
      sourceInfos.add(MapEntry(StringLiteral(key), StringLiteral(value)));
    });
    pointCutConstructorArguments.positional.add(MapLiteral(sourceInfos));
    pointCutConstructorArguments.positional.add(targetExpression);
    pointCutConstructorArguments.positional.add(StringLiteral(member?.name?.name));
    pointCutConstructorArguments.positional.add(StringLiteral(aopItemInfo.stubKey??stubMethodName));
    pointCutConstructorArguments.positional.add(ListLiteral(List<Expression>()..addAll(invocationArguments.positional)));
    List<MapEntry> entries = <MapEntry>[];
    for (NamedExpression namedExpression in invocationArguments.named) {
      entries.add(MapEntry(StringLiteral(namedExpression.name),namedExpression.value));
    }
    pointCutConstructorArguments.positional.add(MapLiteral(entries));

    ConstructorInvocation pointCutConstructorInvocation = ConstructorInvocation((pointCutProceedProcedure.parent as Class).constructors.first, pointCutConstructorArguments);
    redirectArguments.positional.add(pointCutConstructorInvocation);
  }

  static Arguments concatArguments4PointcutStubCall(Member member) {
    Arguments arguments = Arguments.empty();
    int i=0;
    for (VariableDeclaration variableDeclaration in member.function.positionalParameters) {
      Arguments getArguments = Arguments.empty();
      getArguments.positional.add(IntLiteral(i));
      MethodInvocation methodInvocation = MethodInvocation(PropertyGet(ThisExpression(),Name('positionalParams')), listGetProcedure.name, getArguments);
      AsExpression asExpression = AsExpression(methodInvocation, deepCopyASTNode(variableDeclaration.type, ignoreGenerics: true));
      arguments.positional.add(asExpression);
      i++;
    }
    List<NamedExpression> namedEntries = List<NamedExpression>();
    for (VariableDeclaration variableDeclaration in member.function.namedParameters) {
      Arguments getArguments = Arguments.empty();
      getArguments.positional.add(StringLiteral(variableDeclaration.name));
      MethodInvocation methodInvocation = MethodInvocation(PropertyGet(ThisExpression(),Name('namedParams')), mapGetProcedure.name, getArguments);
      AsExpression asExpression = AsExpression(methodInvocation,  deepCopyASTNode(variableDeclaration.type, ignoreGenerics: true));
      namedEntries.add(NamedExpression(variableDeclaration.name, asExpression));
    }
    if (namedEntries.length>0) {
      arguments.named.addAll(namedEntries);
    }
    return arguments;
  }

  static void insertProceedBranch(Procedure procedure, bool shouldReturn) {
    Block block = pointCutProceedProcedure.function.body as Block;
    String methodName = procedure.name.name;
    MethodInvocation methodInvocation = MethodInvocation(ThisExpression(), Name(methodName), Arguments.empty());
    List<Statement> statements = block.statements;
    statements.insert(statements.length-1,IfStatement(MethodInvocation(PropertyGet(ThisExpression(), Name('stubId')), Name('=='), Arguments([StringLiteral(methodName)])),
        Block(<Statement>[(shouldReturn?ReturnStatement(methodInvocation):ExpressionStatement(methodInvocation))]),
        null));
  }

  static bool canOperateLibrary(Library library) {
    if (platformStrongComponent != null && platformStrongComponent.libraries.contains(library)) {
      return false;
    }
    return true;
  }

  static Block createProcedureBodyWithExpression(Expression expression,bool shouldReturn) {
    Block bodyStatements = Block(List<Statement>());
    if (shouldReturn) {
      bodyStatements.addStatement(ReturnStatement(expression));
    } else {
      bodyStatements.addStatement(ExpressionStatement(expression));
    }
    return bodyStatements;
  }

  // Skip aop operation for those aspectd/aop package.
  static bool checkIfSkipAOP(AopItemInfo aopItemInfo, Library curLibrary) {
    Library aopLibrary1 = aopItemInfo.aopMember.parent.parent;
    Library aopLibrary2 = pointCutProceedProcedure.parent.parent;
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
        ConstantExpression constantExpression = annotation;
        Constant constant = constantExpression.constant;
        if (constant is InstanceConstant) {
          InstanceConstant instanceConstant = constant;
          CanonicalName canonicalName =  instanceConstant.classReference.canonicalName;
          if (canonicalName.name == AopUtils.kAopAnnotationClassAspect && canonicalName?.parent?.name == AopUtils.kImportUriAopAspect) {
            enabled = true;
            break;
          }
        }
      }
      //Debug Mode
      else if (annotation is ConstructorInvocation) {
        ConstructorInvocation constructorInvocation = annotation;
        Class cls = constructorInvocation.targetReference.node?.parent as Class;
        if (cls == null) {
          continue;
        }
        Library library = cls?.parent as Library;
        if (cls.name == AopUtils.kAopAnnotationClassAspect && library.importUri.toString() == AopUtils.kImportUriAopAspect) {
          enabled = true;
          break;
        }
      }
    }
    return enabled;
  }

  static Map<String,String> calcSourceInfo(Map<Uri, Source> uriToSource,Library library,int fileOffset) {
    Map<String, String> sourceInfo = Map<String, String>();
    String importUri = library.importUri.toString();
    int idx = importUri.lastIndexOf('/');
    if (idx != -1) {
      importUri = importUri.substring(0,idx);
    }
    Uri fileUri = library.fileUri;
    Source source = uriToSource[fileUri];
    int lineNum;
    int lineOffSet;
    int lineStartCnt = source.lineStarts.length;
    for (int i=0;i<lineStartCnt;i++) {
      int lineStartIdx = source.lineStarts[i];
      if (lineStartIdx<=fileOffset
          && (i==lineStartCnt-1 || source.lineStarts[i+1]>fileOffset)) {
        lineNum = i;
        lineOffSet = fileOffset-lineStartIdx;
        break;
      }
    }
    sourceInfo.putIfAbsent('library', ()=>importUri);
    sourceInfo.putIfAbsent('file', ()=>fileUri.toString());
    sourceInfo.putIfAbsent('lineNum', ()=>'${lineNum+1}');
    sourceInfo.putIfAbsent('lineOffset', ()=>'$lineOffSet');
    return sourceInfo;
  }

  static Procedure createStubProcedure(Name methodName, AopItemInfo aopItemInfo, Procedure referProcedure ,Statement bodyStatements, bool shouldReturn) {
    FunctionNode functionNode = new FunctionNode(bodyStatements,
        typeParameters: deepCopyASTNodes<TypeParameter>(referProcedure.function.typeParameters),
        positionalParameters: referProcedure.function.positionalParameters,
        namedParameters: referProcedure.function.namedParameters,
        requiredParameterCount: referProcedure.function.requiredParameterCount,
        returnType: shouldReturn ? deepCopyASTNode(referProcedure.function.returnType) : VoidType(),
        asyncMarker: referProcedure.function.asyncMarker,
        dartAsyncMarker: referProcedure.function.dartAsyncMarker
    );
    Procedure procedure = new Procedure(
      Name(methodName.name, methodName.library),ProcedureKind.Method, functionNode,
      isStatic: referProcedure.isStatic,
      fileUri: referProcedure.fileUri,
      forwardingStubSuperTarget: referProcedure.forwardingStubSuperTarget,
      forwardingStubInterfaceTarget: referProcedure.forwardingStubInterfaceTarget,
    );

    procedure.fileOffset = referProcedure.fileOffset;
    procedure.fileEndOffset = referProcedure.fileEndOffset;
    procedure.startFileOffset = referProcedure.startFileOffset;
    return procedure;
  }

  static Constructor createStubConstructor(Name methodName, AopItemInfo aopItemInfo, Constructor referConstructor ,Statement bodyStatements, bool shouldReturn) {
    FunctionNode functionNode = new FunctionNode(bodyStatements,
        typeParameters: deepCopyASTNodes<TypeParameter>(referConstructor.function.typeParameters),
        positionalParameters: referConstructor.function.positionalParameters,
        namedParameters: referConstructor.function.namedParameters,
        requiredParameterCount: referConstructor.function.requiredParameterCount,
        returnType: shouldReturn ? deepCopyASTNode(referConstructor.function.returnType) : VoidType(),
        asyncMarker: referConstructor.function.asyncMarker,
        dartAsyncMarker: referConstructor.function.dartAsyncMarker
    );
    Constructor constructor = new Constructor(
      functionNode,
      name: Name(methodName.name, methodName.library),
      isConst: referConstructor.isConst,
      isExternal: referConstructor.isExternal,
      isSynthetic: referConstructor.isSynthetic,
      initializers: deepCopyASTNodes(referConstructor.initializers),
      transformerFlags: referConstructor.transformerFlags,
      fileUri: referConstructor.fileUri,
      reference: Reference()..node = referConstructor.reference.node
    );

    constructor.fileOffset = referConstructor.fileOffset;
    constructor.fileEndOffset = referConstructor.fileEndOffset;
    constructor.startFileOffset = referConstructor.startFileOffset;
    return constructor;
  }

  static dynamic deepCopyASTNode(dynamic node,{bool isReturnType = false, bool ignoreGenerics = false}) {
    if (node is TypeParameter) {
      if (ignoreGenerics)
        return TypeParameter(node.name, node.bound, node.defaultType);
    }
    if (node is VariableDeclaration) {
      return VariableDeclaration(node.name,
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
      if (isReturnType || ignoreGenerics)
        return DynamicType();
      return TypeParameterType(deepCopyASTNode(node.parameter), deepCopyASTNode(node.promotedBound));
    }
    if (node is FunctionType) {
      return FunctionType(deepCopyASTNodes(node.positionalParameters), deepCopyASTNode(node.returnType, isReturnType: true),
          namedParameters: deepCopyASTNodes(node.namedParameters),
          typeParameters: deepCopyASTNodes(node.typeParameters),
          requiredParameterCount: node.requiredParameterCount,
          typedefType: deepCopyASTNode(node.typedefType, ignoreGenerics: ignoreGenerics)
      );
    }
    if (node is TypedefType) {
      return TypedefType(node.typedefNode, deepCopyASTNodes(node.typeArguments, ignoreGeneric: ignoreGenerics));
    }
    return node;
  }

  static List<T> deepCopyASTNodes<T>(List<T> nodes, {bool ignoreGeneric = false}) {
    List<T> newNodes = List<T>();
    for (T node in nodes) {
      dynamic newNode = deepCopyASTNode(node, ignoreGenerics: ignoreGeneric);
      if (newNode != null)
        newNodes.add(newNode);
    }
    return newNodes;
  }

  static Arguments argumentsFromFunctionNode(FunctionNode functionNode) {
    List<Expression> positional = [];
    List<NamedExpression> named = [];
    for (VariableDeclaration variableDeclaration in functionNode.positionalParameters) {
      positional.add(VariableGet(variableDeclaration));
    }
    for (VariableDeclaration variableDeclaration in functionNode.namedParameters) {
      named.add(NamedExpression(variableDeclaration.name, VariableGet(variableDeclaration)));
    }
    return Arguments(positional,named: named);
  }
}