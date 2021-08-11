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

import 'aop_iteminfo.dart';
import 'aop_utils.dart';

class AspectdAopExecuteVisitor extends RecursiveVisitor<void> {
  AspectdAopExecuteVisitor(this._aopItemInfoList);
  final List<AopItemInfo> _aopItemInfoList;

  @override
  void visitLibrary(Library library) {
    String importUri = library.importUri.toString();
    bool matches = false;
    int aopItemInfoListLen = _aopItemInfoList.length;
    for (int i = 0; i < aopItemInfoListLen && !matches; i++) {
      AopItemInfo aopItemInfo = _aopItemInfoList[i];
      if ((aopItemInfo.isRegex &&
              RegExp(aopItemInfo.importUri).hasMatch(importUri)) ||
          (!aopItemInfo.isRegex && importUri == aopItemInfo.importUri)) {
        matches = true;
        break;
      }
    }
    if (matches) {
      library.visitChildren(this);
    }
  }

  @override
  void visitClass(Class cls) {
    String clsName = cls.name;
    bool matches = false;
    int aopItemInfoListLen = _aopItemInfoList.length;
    for (int i = 0; i < aopItemInfoListLen && !matches; i++) {
      AopItemInfo aopItemInfo = _aopItemInfoList[i];
      if ((aopItemInfo.isRegex &&
              RegExp(aopItemInfo.clsName).hasMatch(clsName)) ||
          (!aopItemInfo.isRegex && clsName == aopItemInfo.clsName)) {
        matches = true;
        break;
      }
    }
    if (matches) {
      cls.visitChildren(this);
    }
  }

  @override
  void visitProcedure(Procedure node) {
    String? procedureName = node.name?.name;
    if (procedureName == null) return;
    late AopItemInfo? matchedAopItemInfo;
    int aopItemInfoListLen = _aopItemInfoList.length;
    for (int i = 0; i < aopItemInfoListLen && matchedAopItemInfo == null; i++) {
      AopItemInfo aopItemInfo = _aopItemInfoList[i];
      if ((aopItemInfo.isRegex &&
              RegExp(aopItemInfo.methodName).hasMatch(procedureName)) ||
          (!aopItemInfo.isRegex && procedureName == aopItemInfo.methodName)) {
        matchedAopItemInfo = aopItemInfo;
        break;
      }
    }
    if (matchedAopItemInfo == null) {
      return;
    }
    if (node.isStatic) {
      if (node.parent is Library) {
        transformStaticMethodProcedure(
            node.parent as Library, matchedAopItemInfo, node);
      } else if (node.parent is Class) {
        transformStaticMethodProcedure(
            node.parent?.parent as Library, matchedAopItemInfo, node);
      }
    } else {
      if (node.parent != null) {
        transformInstanceMethodProcedure(
            node.parent?.parent as Library, matchedAopItemInfo, node);
      }
    }
  }

  void transformStaticMethodProcedure(Library originalLibrary,
      AopItemInfo aopItemInfo, Procedure originalProcedure) {
    if (AopUtils.manipulatedProcedureSet.contains(originalProcedure)) {
      return;
    }
    final FunctionNode functionNode = originalProcedure.function as FunctionNode ;
    final Statement body = functionNode.body as Statement;
    final bool shouldReturn =
        !(originalProcedure.function?.returnType is VoidType);

    final String stubKey =
        '${AopUtils.kAopStubMethodPrefix}${AopUtils.kPrimaryKeyAopMethod}';
    AopUtils.kPrimaryKeyAopMethod++;

    //目标新建stub函数，方便完成目标->aopstub->目标stub链路
    final Procedure originalStubProcedure = AopUtils.createStubProcedure(
        Name(originalProcedure.name!.name + '_' + stubKey,
            originalProcedure.name?.library),
        aopItemInfo,
        originalProcedure,
        body,
        shouldReturn);
    final Node parent = originalProcedure.parent as Node;
    late String parentIdentifier;
    if (parent is Library) {
      parent.procedures.add(originalStubProcedure);
      parentIdentifier = parent.importUri.toString();
    } else if (parent is Class) {
      parent.procedures.add(originalStubProcedure);
      parentIdentifier = parent.name;
    }
    functionNode.body = createPointcutCallFromOriginal(
        originalLibrary,
        aopItemInfo,
        stubKey,
        StringLiteral(parentIdentifier),
        originalProcedure,
        AopUtils.argumentsFromFunctionNode(functionNode),
        shouldReturn);

    //Pointcut类中新增stub，并且添加调用
    final Library pointcutLibrary =
        AopUtils.pointCutProceedProcedure.parent?.parent as Library ;
    final Class pointcutClass = AopUtils.pointCutProceedProcedure.parent as Class;
    AopUtils.insertLibraryDependency(pointcutLibrary, originalLibrary);

    final StaticInvocation staticInvocation = StaticInvocation(
        originalStubProcedure,
        AopUtils.concatArguments4PointcutStubCall(originalProcedure),
        isConst: originalStubProcedure.isConst);

    final Procedure stubProcedureNew = AopUtils.createStubProcedure(
        Name(stubKey, AopUtils.pointCutProceedProcedure.name?.library),
        aopItemInfo,
        AopUtils.pointCutProceedProcedure,
        AopUtils.createProcedureBodyWithExpression(
            staticInvocation, shouldReturn),
        shouldReturn);
    pointcutClass.procedures.add(stubProcedureNew);
    AopUtils.insertProceedBranch(stubProcedureNew, shouldReturn);
  }

  void transformInstanceMethodProcedure(Library originalLibrary,
      AopItemInfo aopItemInfo, Procedure originalProcedure) {
    if (AopUtils.manipulatedProcedureSet.contains(originalProcedure)) {
      return;
    }
    final FunctionNode functionNode = originalProcedure.function as FunctionNode;
    final Class originalClass = originalProcedure.parent as Class;
    final Statement body = functionNode.body as Statement;
    if (body == null) {
      return;
    }
    final bool shouldReturn =
        !(originalProcedure.function?.returnType is VoidType);

    final String stubKey =
        '${AopUtils.kAopStubMethodPrefix}${AopUtils.kPrimaryKeyAopMethod}';
    AopUtils.kPrimaryKeyAopMethod++;

    //目标新建stub函数，方便完成目标->aopstub->目标stub链路
    final Procedure originalStubProcedure = AopUtils.createStubProcedure(
        Name(originalProcedure.name!.name + '_' + stubKey,
            originalProcedure.name?.library),
        aopItemInfo,
        originalProcedure,
        body,
        shouldReturn);
    originalClass.procedures.add(originalStubProcedure);
    functionNode.body = createPointcutCallFromOriginal(
        originalLibrary,
        aopItemInfo,
        stubKey,
        ThisExpression(),
        originalProcedure,
        AopUtils.argumentsFromFunctionNode(functionNode),
        shouldReturn);

    //Pointcut类中新增stub，并且添加调用
    final Library pointcutLibrary =
        AopUtils.pointCutProceedProcedure.parent?.parent as Library;
    final Class pointcutClass = AopUtils.pointCutProceedProcedure.parent as Class;
    AopUtils.insertLibraryDependency(pointcutLibrary, originalLibrary);

    final MethodInvocation mockedInvocation = MethodInvocation(
        AsExpression(PropertyGet(ThisExpression(), Name('target')),
            InterfaceType(originalClass, Nullability.legacy)),
        originalStubProcedure.name as Name,
        AopUtils.concatArguments4PointcutStubCall(originalProcedure));

    final Procedure stubProcedureNew = AopUtils.createStubProcedure(
        Name(stubKey, AopUtils.pointCutProceedProcedure.name?.library),
        aopItemInfo,
        AopUtils.pointCutProceedProcedure,
        AopUtils.createProcedureBodyWithExpression(
            mockedInvocation, shouldReturn),
        shouldReturn);
    pointcutClass.procedures.add(stubProcedureNew);
    AopUtils.insertProceedBranch(stubProcedureNew, shouldReturn);
  }

  Block createPointcutCallFromOriginal(
      Library library,
      AopItemInfo aopItemInfo,
      String stubKey,
      Expression targetExpression,
      Member member,
      Arguments arguments,
      bool shouldReturn) {
    AopUtils.insertLibraryDependency(
        library, aopItemInfo.aopMember.parent?.parent as Library);
    final Arguments redirectArguments = Arguments.empty();
    AopUtils.concatArgumentsForAopMethod(
        null, redirectArguments, stubKey, targetExpression, member, arguments);
    late Expression callExpression;
    if (aopItemInfo.aopMember is Procedure) {
      final Procedure procedure = aopItemInfo.aopMember as Procedure;
      if (procedure.isStatic) {
        callExpression =
            StaticInvocation(aopItemInfo.aopMember as Procedure, redirectArguments);
      } else {
        final Class aopItemMemberCls = aopItemInfo.aopMember.parent as Class;
        final ConstructorInvocation redirectConstructorInvocation =
            ConstructorInvocation.byReference(
                aopItemMemberCls.constructors.first.reference,
                Arguments(<Expression>[]));
        callExpression = MethodInvocation(redirectConstructorInvocation,
            aopItemInfo.aopMember.name as Name, redirectArguments);
      }
    }
    return AopUtils.createProcedureBodyWithExpression(
        callExpression, shouldReturn);
  }

  @override
  void defaultMember(Member node) {}
}
