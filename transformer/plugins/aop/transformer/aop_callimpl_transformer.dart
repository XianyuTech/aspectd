// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:kernel/ast.dart';
import 'package:front_end/src/fasta/kernel/kernel_ast_api.dart';
import 'utils.dart';

class AopCallImplTransformer extends Transformer {
  Map<String,AopItemInfo> _aopInfoMap;
  Map<String,Library> _libraryMap;
  Set<Object> _transformedInvocationSet = new Set<Object>();
  Library _curLibrary;
  Map<Uri, Source> _uriToSource;

  AopCallImplTransformer(
      this._aopInfoMap, this._libraryMap, this._uriToSource);

  @override
  Library visitLibrary(Library node){
    _curLibrary = node;
    node.transformChildren(this);
    return node;
  }

  @override
  InvocationExpression visitConstructorInvocation(ConstructorInvocation constructorInvocation) {
    constructorInvocation.transformChildren(this);
    Node node = constructorInvocation.targetReference?.node;
    String uniqueKeyForMethod = null;
    if (node is Constructor) {
      Constructor constructor = node;
      Class cls = constructor.parent as Class;
      String procedureImportUri = cls.reference.canonicalName.parent.name;
      String functionName = '${cls.name}';
      if (constructor.name.name.isNotEmpty) {
        functionName += '.${constructor.name.name}';
      }
      uniqueKeyForMethod = AopItemInfo.uniqueKeyForMethod(
          procedureImportUri, cls.name, functionName, true, null);
    } else {
      assert(false);
    }
    if(uniqueKeyForMethod != null) {
      AopItemInfo aopItemInfo = _aopInfoMap[uniqueKeyForMethod];
      if (aopItemInfo?.mode == AopMode.Call &&
          !_transformedInvocationSet.contains(constructorInvocation) && AopUtils.checkIfSkipAOP(aopItemInfo, _curLibrary) == false) {
        return transformConstructorInvocation(
            constructorInvocation, aopItemInfo);
      }
    }
    return constructorInvocation;
  }

  @override
  MethodInvocation visitMethodInvocation(MethodInvocation methodInvocation) {
    methodInvocation.transformChildren(this);
    Node node = methodInvocation.interfaceTargetReference?.node;
    String uniqueKeyForMethod = null;
    if (node is Procedure) {
      Procedure procedure = node;
      Class cls = procedure.parent as Class;
      String procedureImportUri = cls.reference.canonicalName.parent.name;
      uniqueKeyForMethod = AopItemInfo.uniqueKeyForMethod(
          procedureImportUri, cls.name, methodInvocation.name.name, false, null);
    }
    else if(node == null) {
      String importUri = methodInvocation?.interfaceTargetReference?.canonicalName?.reference?.canonicalName?.nonRootTop?.name;
      String clsName = methodInvocation?.interfaceTargetReference?.canonicalName?.parent?.parent?.name;
      String methodName = methodInvocation?.interfaceTargetReference?.canonicalName?.name;
      uniqueKeyForMethod = AopItemInfo.uniqueKeyForMethod(
          importUri, clsName, methodName, false, null);
    }
    if(uniqueKeyForMethod != null) {
      AopItemInfo aopItemInfo = _aopInfoMap[uniqueKeyForMethod];
      if (aopItemInfo?.mode == AopMode.Call &&
          !_transformedInvocationSet.contains(methodInvocation) && AopUtils.checkIfSkipAOP(aopItemInfo, _curLibrary) == false) {
        return transformInstanceMethodInvocation(
            methodInvocation, aopItemInfo);
      }
    }
    return methodInvocation;
  }

  @override
  StaticInvocation visitStaticInvocation(StaticInvocation staticInvocation){
    staticInvocation.transformChildren(this);
    Node node = staticInvocation.targetReference?.node;
    if(node == null) {
      String procedureName = staticInvocation?.targetReference?.canonicalName?.name;
      String tempName = staticInvocation?.targetReference?.canonicalName?.parent?.parent?.name;
      if(tempName == '@methods') {
        tempName = staticInvocation?.targetReference?.canonicalName?.parent?.parent?.parent?.name;
      }
      //Library Static
      if(procedureName != null && procedureName.length>0 && tempName!=null && tempName.length>0 && _libraryMap[tempName]!=null) {
        Library  originalLibrary = _libraryMap[tempName];
        for(Procedure procedure in originalLibrary.procedures){
          if(procedure.name.name == procedureName) {
            node = procedure;
          }
        }
      }
      // Class Static
      else {
        tempName = staticInvocation?.targetReference?.canonicalName?.parent?.parent?.parent?.name;
        String clsName = staticInvocation?.targetReference?.canonicalName?.parent?.parent?.name;
        Library  originalLibrary = _libraryMap[tempName];
        for(Class cls in originalLibrary.classes) {
          for(Procedure procedure in cls.procedures){
            if(cls.name == clsName && procedure.name.name == procedureName) {
              node = procedure;
            }
          }
        }
      }
    }
    if (node is Procedure) {
      Procedure procedure = node;
      TreeNode treeNode = procedure.parent;
      if(treeNode is Library) {
        Library library = treeNode;
        String libraryImportUri = library.importUri.toString();
        String uniqueKeyForMethod = AopItemInfo.uniqueKeyForMethod(libraryImportUri, '', procedure.name.name, true,null);
        AopItemInfo aopItemInfo = _aopInfoMap[uniqueKeyForMethod];
        if(aopItemInfo?.mode == AopMode.Call && !_transformedInvocationSet.contains(staticInvocation) && AopUtils.checkIfSkipAOP(aopItemInfo, _curLibrary) == false) {
          return transformLibraryStaticMethodInvocation(staticInvocation, procedure, aopItemInfo);
        }
      } else if(treeNode is Class) {
        Class cls = treeNode;
        String procedureImportUri = cls.reference.canonicalName.parent.name;
        String uniqueKeyForMethod = AopItemInfo.uniqueKeyForMethod(procedureImportUri, cls.name, procedure.name.name, true,null);
        AopItemInfo aopItemInfo = _aopInfoMap[uniqueKeyForMethod];
        if(aopItemInfo?.mode == AopMode.Call && !_transformedInvocationSet.contains(staticInvocation) && AopUtils.checkIfSkipAOP(aopItemInfo, _curLibrary) == false) {
          return transformClassStaticMethodInvocation(staticInvocation, aopItemInfo);
        }
      }
    } else {
      assert(false);
    }
    return staticInvocation;
  }

  //Library Static Method Invocation
  StaticInvocation transformLibraryStaticMethodInvocation(StaticInvocation staticInvocation, Procedure procedure, AopItemInfo aopItemInfo) {
    assert(aopItemInfo.mode!=null);
    Library procedureLibrary = procedure.parent as Library;

    //更改原始调用
    Arguments redirectArguments = Arguments.empty();
    Map<String, String> sourceInfo = AopUtils.calcSourceInfo(_uriToSource,_curLibrary, staticInvocation.fileOffset);
    AopUtils.concatArgumentsForAopMethod(sourceInfo,redirectArguments, aopItemInfo, StringLiteral(procedureLibrary.importUri.toString()),procedure,staticInvocation.arguments);

    StaticInvocation staticInvocationNew = StaticInvocation(aopItemInfo.aopMember as Procedure, redirectArguments);
    if(aopItemInfo.stubKey != null){
      return staticInvocationNew;
    }

    insertStaticMethod4Pointcut(aopItemInfo, AopUtils.pointCutProceedProcedure.parent as Class, staticInvocation, procedureLibrary,procedure);
    return staticInvocationNew;
  }

  //Class Constructor Invocation
  StaticInvocation transformConstructorInvocation(ConstructorInvocation constructorInvocation, AopItemInfo aopItemInfo) {
    assert(aopItemInfo.mode!=null);
    Constructor constructor = constructorInvocation.targetReference.node as Constructor;
    Class procedureClass = constructor.parent as Class;

    //更改原始调用
    Arguments redirectArguments = Arguments.empty();
    Map<String, String>  sourceInfo = AopUtils.calcSourceInfo(_uriToSource,_curLibrary, constructorInvocation.fileOffset);
    AopUtils.concatArgumentsForAopMethod(sourceInfo, redirectArguments, aopItemInfo, StringLiteral(procedureClass.name), constructor, constructorInvocation.arguments);

    StaticInvocation staticInvocationNew = StaticInvocation(aopItemInfo.aopMember, redirectArguments);
    if(aopItemInfo.stubKey != null){
      return staticInvocationNew;
    }

    insertConstructor4Pointcut(aopItemInfo, AopUtils.pointCutProceedProcedure.parent as Class, constructorInvocation, constructorInvocation.targetReference.node.parent.parent as Library, constructor);
    return staticInvocationNew;
  }

  //Class Static Method Invocation
  StaticInvocation transformClassStaticMethodInvocation(StaticInvocation staticInvocation, AopItemInfo aopItemInfo) {
    assert(aopItemInfo.mode!=null);
    Procedure procedure = staticInvocation.targetReference.node as Procedure;
    Class procedureClass = procedure.parent as Class;

    //更改原始调用
    Arguments redirectArguments = Arguments.empty();
    Map<String, String>  sourceInfo = AopUtils.calcSourceInfo(_uriToSource,_curLibrary, staticInvocation.fileOffset);
    AopUtils.concatArgumentsForAopMethod(sourceInfo,redirectArguments, aopItemInfo, StringLiteral(procedureClass.name),procedure,staticInvocation.arguments);

    StaticInvocation staticInvocationNew = StaticInvocation(aopItemInfo.aopMember, redirectArguments);
    if(aopItemInfo.stubKey != null){
      return staticInvocationNew;
    }

    insertStaticMethod4Pointcut(aopItemInfo, AopUtils.pointCutProceedProcedure.parent as Class, staticInvocation, staticInvocation.targetReference.node.parent.parent as Library, procedure);
    return staticInvocationNew;
  }

  //Instance Method Invocation
  MethodInvocation transformInstanceMethodInvocation(MethodInvocation methodInvocation, AopItemInfo aopItemInfo) {
    assert(aopItemInfo.mode!=null);

    Procedure methodProcedure = methodInvocation.interfaceTargetReference.node as Procedure;
    Class methodClass = methodInvocation?.interfaceTargetReference?.node?.parent;
    Class methodImplClass = methodClass;
    String procedureName = methodInvocation?.name?.name;
    Library originalLibrary = methodProcedure?.parent?.parent as Library;
    if(originalLibrary == null) {
      String libImportUri = methodInvocation?.interfaceTargetReference?.canonicalName?.nonRootTop?.name;
      originalLibrary = _libraryMap[libImportUri];
    }
    if(methodClass == null){
      String expectedName = methodInvocation?.interfaceTargetReference?.canonicalName?.parent?.parent?.name;
      for(Class cls in originalLibrary.classes) {
        if(cls.name == expectedName) {
          methodClass = cls;
          break;
        }
      }
    }

    if(methodClass.flags & Class.FlagAbstract != 0) {
      for(Class cls in originalLibrary.classes) {
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
        for(Procedure procedure in cls.procedures) {
          String methodName = procedure.name.name;
          if(methodName == procedureName) {
            methodProcedure = procedure;
            break;
          }
        }
      }
    }

    //更改原始调用
    Arguments redirectArguments = Arguments.empty();
    Map<String, String>  sourceInfo = AopUtils.calcSourceInfo(_uriToSource,_curLibrary, methodInvocation.fileOffset);
    AopUtils.concatArgumentsForAopMethod(sourceInfo,redirectArguments, aopItemInfo, methodInvocation.receiver,methodProcedure,methodInvocation.arguments);

    Class cls = aopItemInfo.aopMember.parent as Class;
    ConstructorInvocation redirectConstructorInvocation = ConstructorInvocation.byReference(cls.constructors.first.reference, Arguments([]));
    MethodInvocation methodInvocationNew = MethodInvocation(redirectConstructorInvocation, aopItemInfo.aopMember.name, redirectArguments);
    AopUtils.insertLibraryDependency(_curLibrary, aopItemInfo.aopMember.parent.parent);
    if(aopItemInfo.stubKey != null){
      return methodInvocationNew;
    }

    insertInstanceMethod4Pointcut(aopItemInfo, AopUtils.pointCutProceedProcedure.parent as Class,methodImplClass, methodProcedure);
    return methodInvocationNew;
  }

  bool insertConstructor4Pointcut(AopItemInfo aopItemInfo, Class pointCutClass, ConstructorInvocation constructorInvocation, Library originalLibrary,Member originalMember) {
    //Add library dependency
    AopUtils.insertLibraryDependency(pointCutClass.parent as Library, originalLibrary);
    //Add new Procedure
    ConstructorInvocation constructorInvocation = ConstructorInvocation(originalMember, AopUtils.concatArguments4PointcutStubCall(originalMember));
    _transformedInvocationSet.add(constructorInvocation);
    bool shouldReturn = !(originalMember.function.returnType is VoidType);
    createPointcutStubProcedure(aopItemInfo,pointCutClass,AopUtils.createProcedureBodyWithExpression(constructorInvocation, shouldReturn),shouldReturn);
    return true;
  }

  bool insertStaticMethod4Pointcut(AopItemInfo aopItemInfo, Class pointCutClass, StaticInvocation originalStaticInvocation, Library originalLibrary,Member originalMember) {
    //Add library dependency
    AopUtils.insertLibraryDependency(pointCutClass.parent as Library, originalLibrary);
    //Add new Procedure
    StaticInvocation staticInvocation = StaticInvocation(originalMember, AopUtils.concatArguments4PointcutStubCall(originalMember), isConst: originalMember.isConst);
    _transformedInvocationSet.add(staticInvocation);
    bool shouldReturn = !(originalMember.function.returnType is VoidType);
    createPointcutStubProcedure(aopItemInfo,pointCutClass,AopUtils.createProcedureBodyWithExpression(staticInvocation, shouldReturn),shouldReturn);
    return true;
  }

  bool insertInstanceMethod4Pointcut(AopItemInfo aopItemInfo,Class pointCutClass, Class procedureImpl, Procedure originalProcedure) {
    //Add library dependency
    //Add new Procedure
    DirectMethodInvocation mockedInvocation = DirectMethodInvocation(AsExpression(PropertyGet(ThisExpression(),Name('target')), InterfaceType(procedureImpl)), originalProcedure, AopUtils.concatArguments4PointcutStubCall(originalProcedure));
    _transformedInvocationSet.add(mockedInvocation);
    bool shouldReturn = !(originalProcedure.function.returnType is VoidType);
    createPointcutStubProcedure(aopItemInfo,pointCutClass, AopUtils.createProcedureBodyWithExpression(mockedInvocation, !(originalProcedure.function.returnType is VoidType)), shouldReturn);
    return true;
  }

  //Will create stub and insert call branch in proceed.
  void createPointcutStubProcedure(AopItemInfo aopItemInfo, Class pointCutClass,Statement bodyStatements, bool shouldReturn) {
    String stubMethodName = '${AopUtils.kAopStubMethodPrefix}${AopUtils.kPrimaryKeyAopMethod}';
    aopItemInfo.stubKey = stubMethodName;
    Procedure procedure = AopUtils.createStubProcedure(Name(aopItemInfo.stubKey,AopUtils.pointCutProceedProcedure.name.library), aopItemInfo, AopUtils.pointCutProceedProcedure, bodyStatements, shouldReturn);
    pointCutClass.addMember(procedure);
    AopUtils.insertProceedBranch(procedure, shouldReturn);
    AopUtils.kPrimaryKeyAopMethod++;
  }
}

