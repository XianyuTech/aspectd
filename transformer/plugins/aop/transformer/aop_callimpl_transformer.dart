// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:kernel/ast.dart';
import 'package:front_end/src/fasta/kernel/kernel_ast_api.dart';

import 'aop_iteminfo.dart';
import 'aop_mode.dart';
import 'aop_utils.dart';

class AopCallImplTransformer extends Transformer {
  List<AopItemInfo> _aopItemInfoList;
  Map<String,Library> _libraryMap;
  Library _curLibrary;
  Map<Uri, Source> _uriToSource;
  Map<InvocationExpression, InvocationExpression> _invocationExpressionMapping = Map<InvocationExpression, InvocationExpression>();

  AopCallImplTransformer(
      this._aopItemInfoList, this._libraryMap, this._uriToSource);

  @override
  Library visitLibrary(Library node) {
    _curLibrary = node;
    node.transformChildren(this);
    return node;
  }

  @override
  InvocationExpression visitConstructorInvocation(ConstructorInvocation constructorInvocation) {
    constructorInvocation.transformChildren(this);
    Node node = constructorInvocation.targetReference?.node;
    if (node is Constructor) {
      Constructor constructor = node;
      Class cls = constructor.parent as Class;
      String procedureImportUri = cls.reference.canonicalName.parent.name;
      String functionName = '${cls.name}';
      if (constructor.name.name.isNotEmpty) {
        functionName += '.${constructor.name.name}';
      }
      AopItemInfo aopItemInfo = _filterAopItemInfo(_aopItemInfoList, procedureImportUri, cls.name, functionName, true);
      if (aopItemInfo?.mode == AopMode.Call && AopUtils.checkIfSkipAOP(aopItemInfo, _curLibrary) == false) {
        return transformConstructorInvocation(
            constructorInvocation, aopItemInfo);
      }
    } else {
      return constructorInvocation;
    }
    return constructorInvocation;
  }

  @override
  StaticInvocation visitStaticInvocation(StaticInvocation staticInvocation) {
    staticInvocation.transformChildren(this);
    Node node = staticInvocation.targetReference?.node;
    if (node == null) {
      String procedureName = staticInvocation?.targetReference?.canonicalName?.name;
      String tempName = staticInvocation?.targetReference?.canonicalName?.parent?.parent?.name;
      if (tempName == '@methods') {
        tempName = staticInvocation?.targetReference?.canonicalName?.parent?.parent?.parent?.name;
      }
      //Library Static
      if ((procedureName?.length ?? 0) > 0 && tempName!=null && tempName.length > 0 && _libraryMap[tempName]!=null) {
        Library  originalLibrary = _libraryMap[tempName];
        for (Procedure procedure in originalLibrary.procedures) {
          if (procedure.name.name == procedureName) {
            node = procedure;
          }
        }
      }
      // Class Static
      else {
        tempName = staticInvocation?.targetReference?.canonicalName?.parent?.parent?.parent?.name;
        String clsName = staticInvocation?.targetReference?.canonicalName?.parent?.parent?.name;
        Library  originalLibrary = _libraryMap[tempName];
        for (Class cls in originalLibrary.classes) {
          for (Procedure procedure in cls.procedures) {
            if (cls.name == clsName && procedure.name.name == procedureName) {
              node = procedure;
            }
          }
        }
      }
    }
    if (node is Procedure) {
      Procedure procedure = node;
      TreeNode treeNode = procedure.parent;
      if (treeNode is Library) {
        Library library = treeNode;
        String libraryImportUri = library.importUri.toString();
        AopItemInfo aopItemInfo = _filterAopItemInfo(_aopItemInfoList, libraryImportUri, '', procedure.name.name, true);
        if (aopItemInfo?.mode == AopMode.Call && AopUtils.checkIfSkipAOP(aopItemInfo, _curLibrary) == false) {
          return transformLibraryStaticMethodInvocation(staticInvocation, procedure, aopItemInfo);
        }
      } else if (treeNode is Class) {
        Class cls = treeNode;
        String procedureImportUri = cls.reference.canonicalName.parent.name;
        AopItemInfo aopItemInfo = _filterAopItemInfo(_aopItemInfoList, procedureImportUri, cls.name, procedure.name.name, true);
        if (aopItemInfo?.mode == AopMode.Call && AopUtils.checkIfSkipAOP(aopItemInfo, _curLibrary) == false) {
          return transformClassStaticMethodInvocation(staticInvocation, aopItemInfo);
        }
      }
    } else {
      assert(false);
    }
    return staticInvocation;
  }

  @override
  MethodInvocation visitMethodInvocation(MethodInvocation methodInvocation) {
    methodInvocation.transformChildren(this);
    Node node = methodInvocation.interfaceTargetReference?.node;
    if (node is Procedure) {
      String nodeName = node.name.name;
      print(nodeName);
    }

    String importUri, clsName, methodName;
    if (node is Procedure || node == null) {
      if (node is Procedure) {
        Procedure procedure = node;
        Class cls = procedure.parent as Class;
        importUri = cls.reference.canonicalName.parent.name;
        clsName = cls.name;
        methodName = methodInvocation.name.name;
      }
      else if (node == null) {
        importUri = methodInvocation?.interfaceTargetReference?.canonicalName?.reference?.canonicalName?.nonRootTop?.name;
        clsName = methodInvocation?.interfaceTargetReference?.canonicalName?.parent?.parent?.name;
        methodName = methodInvocation?.interfaceTargetReference?.canonicalName?.name;
      }
      if (importUri?.contains('example') ?? false) {
        print('');
      }
      AopItemInfo aopItemInfo = _filterAopItemInfo(_aopItemInfoList, importUri, clsName, methodName, false);
      if (aopItemInfo?.mode == AopMode.Call && AopUtils.checkIfSkipAOP(aopItemInfo, _curLibrary) == false) {
        return transformInstanceMethodInvocation(
            methodInvocation, aopItemInfo);
      }
    }
    return methodInvocation;
  }

  //Filter AopInfoMap for specific callsite.
  AopItemInfo _filterAopItemInfo(List<AopItemInfo> aopItemInfoList, String importUri, String clsName, String methodName, bool isStatic) {
    //Reverse sorting so that the newly added Aspect might override the older ones.
    importUri ??= '';
    clsName ??= '';
    methodName ??= '';
    final int aopItemInfoCnt = aopItemInfoList.length;
    for (int i = aopItemInfoCnt-1; i >= 0; i--) {
      AopItemInfo aopItemInfo = aopItemInfoList[i];
      if (aopItemInfo.isRegex) {
        if (RegExp(aopItemInfo.importUri).hasMatch(importUri) &&
            RegExp(aopItemInfo.clsName).hasMatch(clsName) &&
            RegExp(aopItemInfo.methodName).hasMatch(methodName) &&
            isStatic == aopItemInfo.isStatic
        ) {
          return aopItemInfo;
        }
      } else {
        if (aopItemInfo.importUri == importUri &&
            aopItemInfo.clsName == clsName &&
            aopItemInfo.methodName == methodName &&
            isStatic == aopItemInfo.isStatic
        ) {
          return aopItemInfo;
        }
      }
    }
    return null;
  }

  //Library Static Method Invocation
  StaticInvocation transformLibraryStaticMethodInvocation(StaticInvocation staticInvocation, Procedure procedure, AopItemInfo aopItemInfo) {
    assert(aopItemInfo.mode!=null);

    if (_invocationExpressionMapping[staticInvocation] != null) {
      return _invocationExpressionMapping[staticInvocation];
    }

    Library procedureLibrary = procedure.parent as Library;

    String stubKey = '${AopUtils.kAopStubMethodPrefix}${AopUtils.kPrimaryKeyAopMethod}';
    AopUtils.kPrimaryKeyAopMethod++;

    //更改原始调用
    Arguments redirectArguments = Arguments.empty();
    Map<String, String> sourceInfo = AopUtils.calcSourceInfo(_uriToSource,_curLibrary, staticInvocation.fileOffset);
    AopUtils.concatArgumentsForAopMethod(sourceInfo,redirectArguments, stubKey, StringLiteral(procedureLibrary.importUri.toString()),procedure,staticInvocation.arguments);
    StaticInvocation staticInvocationNew = StaticInvocation(aopItemInfo.aopMember as Procedure, redirectArguments);

    insertStaticMethod4Pointcut(aopItemInfo, stubKey, AopUtils.pointCutProceedProcedure.parent as Class, staticInvocation, procedureLibrary,procedure);
    _invocationExpressionMapping[staticInvocation] = staticInvocationNew;
    return staticInvocationNew;
  }

  //Class Constructor Invocation
  StaticInvocation transformConstructorInvocation(ConstructorInvocation constructorInvocation, AopItemInfo aopItemInfo) {
    assert(aopItemInfo.mode!=null);

    if (_invocationExpressionMapping[constructorInvocation] != null) {
      return _invocationExpressionMapping[constructorInvocation];
    }

    Constructor constructor = constructorInvocation.targetReference.node as Constructor;
    Class procedureClass = constructor.parent as Class;

    String stubKey = '${AopUtils.kAopStubMethodPrefix}${AopUtils.kPrimaryKeyAopMethod}';
    AopUtils.kPrimaryKeyAopMethod++;

    //更改原始调用
    Arguments redirectArguments = Arguments.empty();
    Map<String, String>  sourceInfo = AopUtils.calcSourceInfo(_uriToSource,_curLibrary, constructorInvocation.fileOffset);
    AopUtils.concatArgumentsForAopMethod(sourceInfo, redirectArguments, stubKey, StringLiteral(procedureClass.name), constructor, constructorInvocation.arguments);

    StaticInvocation staticInvocationNew = StaticInvocation(aopItemInfo.aopMember, redirectArguments);

    insertConstructor4Pointcut(aopItemInfo, stubKey, AopUtils.pointCutProceedProcedure.parent as Class, constructorInvocation, constructorInvocation.targetReference.node.parent.parent as Library, constructor);
    _invocationExpressionMapping[constructorInvocation] = staticInvocationNew;
    return staticInvocationNew;
  }

  //Class Static Method Invocation
  StaticInvocation transformClassStaticMethodInvocation(StaticInvocation staticInvocation, AopItemInfo aopItemInfo) {
    assert(aopItemInfo.mode!=null);

    if (_invocationExpressionMapping[staticInvocation] != null) {
      return _invocationExpressionMapping[staticInvocation];
    }

    Procedure procedure = staticInvocation.targetReference.node as Procedure;
    Class procedureClass = procedure.parent as Class;

    String stubKey = '${AopUtils.kAopStubMethodPrefix}${AopUtils.kPrimaryKeyAopMethod}';
    AopUtils.kPrimaryKeyAopMethod++;

    //更改原始调用
    Arguments redirectArguments = Arguments.empty();
    Map<String, String>  sourceInfo = AopUtils.calcSourceInfo(_uriToSource,_curLibrary, staticInvocation.fileOffset);
    AopUtils.concatArgumentsForAopMethod(sourceInfo,redirectArguments, stubKey, StringLiteral(procedureClass.name),procedure,staticInvocation.arguments);

    StaticInvocation staticInvocationNew = StaticInvocation(aopItemInfo.aopMember, redirectArguments);

    insertStaticMethod4Pointcut(aopItemInfo, stubKey, AopUtils.pointCutProceedProcedure.parent as Class, staticInvocation, staticInvocation.targetReference.node.parent.parent as Library, procedure);
    _invocationExpressionMapping[staticInvocation] = staticInvocationNew;
    return staticInvocationNew;
  }

  //Instance Method Invocation
  MethodInvocation transformInstanceMethodInvocation(MethodInvocation methodInvocation, AopItemInfo aopItemInfo) {
    assert(aopItemInfo.mode!=null);

    if (_invocationExpressionMapping[methodInvocation] != null) {
      return _invocationExpressionMapping[methodInvocation];
    }

    Procedure methodProcedure = methodInvocation.interfaceTargetReference.node as Procedure;
    Class methodClass = methodInvocation?.interfaceTargetReference?.node?.parent;
    Class methodImplClass = methodClass;
    String procedureName = methodInvocation?.name?.name;
    Library originalLibrary = methodProcedure?.parent?.parent as Library;
    if (originalLibrary == null) {
      String libImportUri = methodInvocation?.interfaceTargetReference?.canonicalName?.nonRootTop?.name;
      originalLibrary = _libraryMap[libImportUri];
    }
    if (methodClass == null) {
      String expectedName = methodInvocation?.interfaceTargetReference?.canonicalName?.parent?.parent?.name;
      for (Class cls in originalLibrary.classes) {
        if (cls.name == expectedName) {
          methodClass = cls;
          break;
        }
      }
    }

    if (methodClass.flags & Class.FlagAbstract != 0) {
      for (Class cls in originalLibrary.classes) {
        String clsName = cls.name;
        if (cls.flags & Class.FlagAbstract != 0) //抽象类
          continue;
        if (methodClass.flags & Class.FlagAbstract != 0) {
          bool matches = false;
          cls.implementedTypes.forEach((Supertype superType) {
            if (superType.className.node == methodClass)
              matches = true;
          });
          if (!matches || (clsName != '_${methodClass.name}'))
            continue;
        } else if (clsName != methodClass.name) {
          continue;
        }
        methodImplClass = cls;
        for (Procedure procedure in cls.procedures) {
          String methodName = procedure.name.name;
          if (methodName == procedureName) {
            methodProcedure = procedure;
            break;
          }
        }
      }
    }

    String stubKey = '${AopUtils.kAopStubMethodPrefix}${AopUtils.kPrimaryKeyAopMethod}';
    AopUtils.kPrimaryKeyAopMethod++;

    //更改原始调用
    Arguments redirectArguments = Arguments.empty();
    Map<String, String>  sourceInfo = AopUtils.calcSourceInfo(_uriToSource,_curLibrary, methodInvocation.fileOffset);
    AopUtils.concatArgumentsForAopMethod(sourceInfo,redirectArguments, stubKey, methodInvocation.receiver,methodProcedure,methodInvocation.arguments);

    Class cls = aopItemInfo.aopMember.parent as Class;
    ConstructorInvocation redirectConstructorInvocation = ConstructorInvocation.byReference(cls.constructors.first.reference, Arguments([]));
    MethodInvocation methodInvocationNew = MethodInvocation(redirectConstructorInvocation, aopItemInfo.aopMember.name, redirectArguments);
    AopUtils.insertLibraryDependency(_curLibrary, aopItemInfo.aopMember.parent.parent);

    insertInstanceMethod4Pointcut(aopItemInfo, stubKey, AopUtils.pointCutProceedProcedure.parent as Class,methodImplClass, methodProcedure);
    _invocationExpressionMapping[methodInvocation] = methodInvocationNew;
    return methodInvocationNew;
  }

  bool insertConstructor4Pointcut(AopItemInfo aopItemInfo, String stubKey, Class pointCutClass, ConstructorInvocation constructorInvocation, Library originalLibrary,Member originalMember) {
    //Add library dependency
    AopUtils.insertLibraryDependency(pointCutClass.parent as Library, originalLibrary);
    //Add new Procedure
    ConstructorInvocation constructorInvocation = ConstructorInvocation(originalMember, AopUtils.concatArguments4PointcutStubCall(originalMember));
    bool shouldReturn = !(originalMember.function.returnType is VoidType);
    createPointcutStubProcedure(aopItemInfo, stubKey, pointCutClass,AopUtils.createProcedureBodyWithExpression(constructorInvocation, shouldReturn),shouldReturn);
    return true;
  }

  bool insertStaticMethod4Pointcut(AopItemInfo aopItemInfo, String stubKey, Class pointCutClass, StaticInvocation originalStaticInvocation, Library originalLibrary,Member originalMember) {
    //Add library dependency
    AopUtils.insertLibraryDependency(pointCutClass.parent as Library, originalLibrary);
    //Add new Procedure
    StaticInvocation staticInvocation = StaticInvocation(originalMember, AopUtils.concatArguments4PointcutStubCall(originalMember), isConst: originalMember.isConst);
    bool shouldReturn = !(originalMember.function.returnType is VoidType);
    createPointcutStubProcedure(aopItemInfo, stubKey, pointCutClass,AopUtils.createProcedureBodyWithExpression(staticInvocation, shouldReturn),shouldReturn);
    return true;
  }

  bool insertInstanceMethod4Pointcut(AopItemInfo aopItemInfo, String stubKey, Class pointCutClass, Class procedureImpl, Procedure originalProcedure) {
    //Add library dependency
    //Add new Procedure
    DirectMethodInvocation mockedInvocation = DirectMethodInvocation(AsExpression(PropertyGet(ThisExpression(),Name('target')), InterfaceType(procedureImpl, Nullability.legacy)), originalProcedure, AopUtils.concatArguments4PointcutStubCall(originalProcedure));
    bool shouldReturn = !(originalProcedure.function.returnType is VoidType);
    createPointcutStubProcedure(aopItemInfo, stubKey, pointCutClass, AopUtils.createProcedureBodyWithExpression(mockedInvocation, !(originalProcedure.function.returnType is VoidType)), shouldReturn);
    return true;
  }

  //Will create stub and insert call branch in proceed.
  void createPointcutStubProcedure(AopItemInfo aopItemInfo,  String stubKey, Class pointCutClass,Statement bodyStatements, bool shouldReturn) {
    Procedure procedure = AopUtils.createStubProcedure(Name(stubKey, AopUtils.pointCutProceedProcedure.name.library), aopItemInfo, AopUtils.pointCutProceedProcedure, bodyStatements, shouldReturn);
    pointCutClass.addMember(procedure);
    AopUtils.insertProceedBranch(procedure, shouldReturn);
  }
}

