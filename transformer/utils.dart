import 'package:kernel/ast.dart';

enum AspectdMode{
  Call,
  Execute,
  Inject
}

class AspectdUtils {
  static String kAspectdAnnotationClassCall = 'Call';
  static String kAspectdAnnotationClassExecute = 'Execute';
  static String kAspectdAnnotationClassInject = 'Inject';
  static String kImportUriAspectdCall = 'package:aspectd/call.dart';
  static String kImportUriAspectdExecute = 'package:aspectd/execute.dart';
  static String kImportUriAspectdInject = 'package:aspectd/inject.dart';
  static String kAspectdUniqueKeySeperator = '#';
  static String kImportUriAspectdAspect = 'package:aspectd/aspect.dart';
  static String kAspectdAnnotationClassAspect = 'Aspect';
  static String kImportUriPointCut = 'package:aspectd/pointcut.dart';
  static String kAspectdAnnotationImportUri = 'importUri';
  static String kAspectdAnnotationClsName = 'clsName';
  static String kAspectdAnnotationMethodName = 'methodName';
  static String kAspectdAnnotationLineNum = 'lineNum';
  static String kAspectdAnnotationClassPointCut = 'PointCut';
  static String kAspectdAnnotationInstanceMethodPrefix = '-';
  static String kAspectdAnnotationStaticMethodPrefix = '+';
  static int kPrimaryKeyAspectdMethod = 0;
  static String kAspectdStubMethodPrefix = 'aspectd_stub_';
  static String kAspectdPointcutProcessName = 'proceed';
  static String kAspectdPointcutIgnoreVariableDeclaration = '//Aspectd Ignore';
  static Procedure pointCutProceedProcedure;
  static Procedure listGetProcedure;
  static Procedure mapGetProcedure;
  static Component platformStrongComponent;

  static AspectdMode getAspectdModeByNameAndImportUri(String name, String importUri) {
    if(name == kAspectdAnnotationClassCall && importUri == kImportUriAspectdCall)
      return AspectdMode.Call;
    if(name == kAspectdAnnotationClassExecute && importUri == kImportUriAspectdExecute)
      return AspectdMode.Execute;
    if(name == kAspectdAnnotationClassInject && importUri == kImportUriAspectdInject)
      return AspectdMode.Inject;
    return null;
  }

  //Generic Operation
  static void insertLibraryDependency(Library library, Library dependLibrary) {
    for(LibraryDependency dependency in library.dependencies) {
      if(dependency.importedLibraryReference.node == dependLibrary)
        return;
    }
    library.dependencies.add(new LibraryDependency.import(dependLibrary));
  }

  static int getLineStartNumForStatement(Source source, Statement statement) {
    int fileOffset = statement.fileOffset;
    if(fileOffset == -1) {
      if(statement is ExpressionStatement) {
        ExpressionStatement expressionStatement = statement;
        fileOffset = expressionStatement.expression.fileOffset;
      } else if(statement is AssertStatement) {
        AssertStatement assertStatement = statement;
        fileOffset = assertStatement.conditionStartOffset;
      } else if(statement is LabeledStatement) {
        fileOffset = statement.body.fileOffset;
      }
    }
    return getLineNumBySourceAndOffset(source, fileOffset);
  }

  static int getLineStartNumForInitializer(Source source, Initializer initializer) {
    int fileOffset = initializer.fileOffset;
    if(fileOffset == -1) {
      if(initializer is AssertInitializer) {
        fileOffset = initializer.statement.conditionStartOffset;
      }
    }
    return getLineNumBySourceAndOffset(source, fileOffset);
  }

  static int getLineNumBySourceAndOffset(Source source, int fileOffset) {
    int lineNum = source.lineStarts.length;
    for(int i=0;i<lineNum;i++) {
      int lineStart = source.lineStarts[i];
      if(fileOffset>=lineStart && (i==lineNum-1 || fileOffset<source.lineStarts[i+1])) {
        return i;
      }
    }
    return -1;
  }

  static VariableDeclaration checkIfSkipableVarDeclaration(Source source, Statement statement) {
    if(statement is VariableDeclaration) {
      VariableDeclaration variableDeclaration = statement;
      int lineNum = AspectdUtils.getLineNumBySourceAndOffset(source, variableDeclaration.fileOffset);
      if(lineNum == -1) {
        return null;
      }
      int charFrom = source.lineStarts[lineNum];
      int charTo = source.source.length;
      if(lineNum<source.lineStarts.length-1) {
        charTo = source.lineStarts[lineNum+1];
      }
      List<int> sourceLineChars = source.source.sublist(charFrom,charTo);
      String sourceLine = String.fromCharCodes(sourceLineChars).trim();
      if(sourceLine.endsWith(AspectdUtils.kAspectdPointcutIgnoreVariableDeclaration)) {
        return variableDeclaration;
      }
    }
    return null;
  }

  static List<String> getPropertyKeyPaths(String propertyDesc) {
    List<String> tmpItems = propertyDesc.split('.');
    List<String> items = [];
    tmpItems.forEach((item){
      int idx1 = item.lastIndexOf('::');
      int idx2 = item.lastIndexOf('}');
      if(idx1!=-1 && idx2!=-1) {
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
    for(int i=0;i<len-1;i++) {
      String part = keypaths[i];
      if(part == 'this')
        continue;
      for(Field field in cls.fields) {
        if(field.name.name == part) {
          cls = (field.type as InterfaceType).className.node;
          break;
        }
      }
    }
    return cls;
  }

  static Field findFieldForClassWithName(Class cls,String fieldName) {
    for(Field field in cls.fields) {
      if(field.name.name == fieldName) {
        return field;
      }
    }
    return null;
  }

  static bool isAsyncFunctionNode(FunctionNode functionNode) {
    return functionNode.dartAsyncMarker == AsyncMarker.Async || functionNode.dartAsyncMarker == AsyncMarker.AsyncStar;
  }

  static Node getNodeToVisitRecursively(Object statement) {
    if(statement is FunctionDeclaration) {
      return statement.function;
    }
    if(statement is LabeledStatement) {
      return statement.body;
    }
    if(statement is IfStatement) {
      return statement.then;
    }
    return null;
  }

  static void concatArgumentsForAspectdMethod(Map<String, String> sourceInfo,Arguments redirectArguments,AspectdItemInfo aspectdItemInfo,
      Expression targetExpression, Procedure procedure,Arguments invocationArguments) {
    String stubMethodName = '${AspectdUtils.kAspectdStubMethodPrefix}${AspectdUtils.kPrimaryKeyAspectdMethod}';
    //重定向到AOP的函数体中去
    Arguments pointCutConstructorArguments = Arguments.empty();
    List<MapEntry> sourceInfos = List<MapEntry>();
    sourceInfo?.forEach((String key, String value){
      sourceInfos.add(MapEntry(StringLiteral(key), StringLiteral(value)));
    });
    pointCutConstructorArguments.positional.add(MapLiteral(sourceInfos));
    pointCutConstructorArguments.positional.add(targetExpression);
    pointCutConstructorArguments.positional.add(StringLiteral(procedure?.name?.name));
    pointCutConstructorArguments.positional.add(StringLiteral(aspectdItemInfo.stubKey??stubMethodName));
    pointCutConstructorArguments.positional.add(ListLiteral(List<Expression>()..addAll(invocationArguments.positional)));
    List<MapEntry> entries = <MapEntry>[];
    for(NamedExpression namedExpression in invocationArguments.named){
      entries.add(MapEntry(StringLiteral(namedExpression.name),namedExpression.value));
    }
    pointCutConstructorArguments.positional.add(MapLiteral(entries));

    ConstructorInvocation pointCutConstructorInvocation = ConstructorInvocation((pointCutProceedProcedure.parent as Class).constructors.first, pointCutConstructorArguments);
    redirectArguments.positional.add(pointCutConstructorInvocation);
  }

  /// 从PointCut中的positionalParams和namedParams属性中获取参数
  static Arguments concatArguments4PointcutStubCall(Procedure procedure) {
    Arguments arguments = Arguments.empty();
    int i=0;
    for(VariableDeclaration variableDeclaration in procedure.function.positionalParameters) {
      Arguments getArguments = Arguments.empty();
      getArguments.positional.add(IntLiteral(i));
      MethodInvocation methodInvocation = MethodInvocation(PropertyGet(ThisExpression(),Name('positionalParams')), listGetProcedure.name, getArguments);
      AsExpression asExpression = AsExpression(methodInvocation, variableDeclaration.type);
      arguments.positional.add(asExpression);
      i++;
    }
    List<NamedExpression> namedEntries = List<NamedExpression>();
    for(VariableDeclaration variableDeclaration in procedure.function.namedParameters){
      Arguments getArguments = Arguments.empty();
      getArguments.positional.add(StringLiteral(variableDeclaration.name));
      MethodInvocation methodInvocation = MethodInvocation(PropertyGet(ThisExpression(),Name('namedParams')), mapGetProcedure.name, getArguments);
      AsExpression asExpression = AsExpression(methodInvocation, variableDeclaration.type);
      namedEntries.add(NamedExpression(variableDeclaration.name, asExpression));
    }
    if(namedEntries.length>0)
      arguments.named.addAll(namedEntries);
    return arguments;
  }

  static void insertProceedBranch(Procedure procedure, bool shouldReturn) {
    Block block = pointCutProceedProcedure.function.body as Block;
    String methodName = procedure.name.name;
    MethodInvocation methodInvocation = MethodInvocation(ThisExpression(), Name(methodName), Arguments.empty());
    List<Statement> statements = block.statements;
    statements.insert(statements.length-1,IfStatement(
        MethodInvocation(PropertyGet(ThisExpression(), Name('stubId')), Name('=='), Arguments([StringLiteral(methodName)])),
        Block(<Statement>[(shouldReturn?ReturnStatement(methodInvocation):ExpressionStatement(methodInvocation))]),
        null));
  }

  static bool canOperateLibrary(Library library) {
    if(platformStrongComponent != null && platformStrongComponent.libraries.contains(library))
      return false;
    return true;
  }

  static Block createProcedureBodyWithExpression(Expression expression,bool shouldReturn) {
    Block bodyStatements = Block(List<Statement>());
    if(shouldReturn) {
      bodyStatements.addStatement(ReturnStatement(expression));
    } else {
      bodyStatements.addStatement(ExpressionStatement(expression));
    }
    return bodyStatements;
  }

  // Skip aop operation for those aspectd/aop package.
  static bool checkIfSkipAOP(AspectdItemInfo aspectdItemInfo, Library curLibrary) {
    Library aopLibrary = aspectdItemInfo.aspectdProcedure.parent.parent;
    Library aspectdLibrary = pointCutProceedProcedure.parent.parent;
    if(curLibrary == aopLibrary || curLibrary == aspectdLibrary)
      return true;
    return false;
  }

  static bool checkIfClassEnableAspectd(List<Expression> annotations){
    bool enabled = false;
    for(Expression annotation in annotations){
      //Release Mode
      if(annotation is ConstantExpression){
        ConstantExpression constantExpression = annotation;
        Constant constant = constantExpression.constant;
        if(constant is InstanceConstant){
          InstanceConstant instanceConstant = constant;
          CanonicalName canonicalName =  instanceConstant.classReference.canonicalName;
          if(canonicalName.name == AspectdUtils.kAspectdAnnotationClassAspect && canonicalName?.parent?.name == AspectdUtils.kImportUriAspectdAspect){
            enabled = true;
            break;
          }
        }
      }
      //Debug Mode
      else if(annotation is ConstructorInvocation) {
        ConstructorInvocation constructorInvocation = annotation;
        Class cls = constructorInvocation.targetReference.node?.parent as Class;
        if(cls == null)
          continue;
        Library library = cls?.parent as Library;
        if(cls.name == AspectdUtils.kAspectdAnnotationClassAspect && library.importUri.toString() == AspectdUtils.kImportUriAspectdAspect){
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
    if(idx != -1) {
      importUri = importUri.substring(0,idx);
    }
    Uri fileUri = library.fileUri;
    Source source = uriToSource[fileUri];
    int lineNum;
    int lineOffSet;
    int lineStartCnt = source.lineStarts.length;
    for(int i=0;i<lineStartCnt;i++){
      int lineStartIdx = source.lineStarts[i];
      if(lineStartIdx<=fileOffset
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

  static Procedure createStubProcedure(Name methodName, AspectdItemInfo aspectdItemInfo, Procedure referProcedure ,Statement bodyStatements, bool shouldReturn) {
    FunctionNode functionNode = new FunctionNode(bodyStatements,
        typeParameters: referProcedure.function.typeParameters,
        positionalParameters: referProcedure.function.positionalParameters,
        namedParameters: referProcedure.function.namedParameters,
        requiredParameterCount: referProcedure.function.requiredParameterCount,
        returnType: shouldReturn ? referProcedure.function.returnType : VoidType(),
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

  static Arguments argumentsFromFunctionNode(FunctionNode functionNode) {
    List<Expression> positional = [];
    List<NamedExpression> named = [];
    for(VariableDeclaration variableDeclaration in functionNode.positionalParameters){
      positional.add(VariableGet(variableDeclaration));
    }
    for(VariableDeclaration variableDeclaration in functionNode.namedParameters){
      named.add(NamedExpression(variableDeclaration.name, VariableGet(variableDeclaration)));
    }
    return Arguments(positional,named: named);
  }
}

class AspectdItemInfo {
  final AspectdMode mode;
  final String importUri;
  final String clsName;
  final String methodName;
  final bool isStatic;
  final Procedure aspectdProcedure;
  final int lineNum;
  String stubKey;
  static String uniqueKeyForMethod(String importUri, String clsName, String methodName, bool isStatic, int lineNum){
    return (importUri??"")+AspectdUtils.kAspectdUniqueKeySeperator
        +(clsName??"")+AspectdUtils.kAspectdUniqueKeySeperator
        +(methodName??"")+AspectdUtils.kAspectdUniqueKeySeperator
        +(isStatic==true?"+":"-")
        +(lineNum!=null?(AspectdUtils.kAspectdUniqueKeySeperator+"$lineNum"):"");
  }
  AspectdItemInfo({this.mode,this.importUri,this.clsName,this.methodName,this.isStatic,this.aspectdProcedure,this.lineNum});
}