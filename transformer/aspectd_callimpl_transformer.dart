// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:kernel/ast.dart';
import 'package:front_end/src/fasta/kernel/kernel_ast_api.dart';
import 'utils.dart';

class AspectdCallImplTransformer extends Transformer {
  Map<String,AspectdItemInfo> _aspectdInfoMap;
  Map<String,Library> _libraryMap;
  Set<Object> _transformedInvocationSet = new Set<Object>();
  Library _curLibrary;
  Map<Uri, Source> _uriToSource;

  AspectdCallImplTransformer(
      this._aspectdInfoMap, this._libraryMap, this._uriToSource);

  @override
  Library visitLibrary(Library node){
    _curLibrary = node;
    node.transformChildren(this);
    return node;
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
      uniqueKeyForMethod = AspectdItemInfo.uniqueKeyForMethod(
          procedureImportUri, cls.name, methodInvocation.name.name, false, null);
    }
    else if(node == null) {
      String importUri = methodInvocation?.interfaceTargetReference?.canonicalName?.reference?.canonicalName?.nonRootTop?.name;
      String clsName = methodInvocation?.interfaceTargetReference?.canonicalName?.parent?.parent?.name;
      String methodName = methodInvocation?.interfaceTargetReference?.canonicalName?.name;
      uniqueKeyForMethod = AspectdItemInfo.uniqueKeyForMethod(
          importUri, clsName, methodName, false, null);
    }
    if(uniqueKeyForMethod != null) {
      AspectdItemInfo aspectdItemInfo = _aspectdInfoMap[uniqueKeyForMethod];
      if (aspectdItemInfo?.mode == AspectdMode.Call &&
          !_transformedInvocationSet.contains(methodInvocation) && AspectdUtils.checkIfSkipAOP(aspectdItemInfo, _curLibrary) == false) {
        return transformInstanceMethodInvocation(
            methodInvocation, aspectdItemInfo);
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
        String uniqueKeyForMethod = AspectdItemInfo.uniqueKeyForMethod(libraryImportUri, '', procedure.name.name, true,null);
        AspectdItemInfo aspectdItemInfo = _aspectdInfoMap[uniqueKeyForMethod];
        if(aspectdItemInfo?.mode == AspectdMode.Call && !_transformedInvocationSet.contains(staticInvocation) && AspectdUtils.checkIfSkipAOP(aspectdItemInfo, _curLibrary) == false) {
          return transformLibraryStaticMethodInvocation(staticInvocation, procedure, aspectdItemInfo);
        }
      } else if(treeNode is Class) {
        Class cls = treeNode;
        String procedureImportUri = cls.reference.canonicalName.parent.name;
        String uniqueKeyForMethod = AspectdItemInfo.uniqueKeyForMethod(procedureImportUri, cls.name, procedure.name.name, true,null);
        AspectdItemInfo aspectdItemInfo = _aspectdInfoMap[uniqueKeyForMethod];
        if(aspectdItemInfo?.mode == AspectdMode.Call && !_transformedInvocationSet.contains(staticInvocation) && AspectdUtils.checkIfSkipAOP(aspectdItemInfo, _curLibrary) == false) {
          return transformClassStaticMethodInvocation(staticInvocation, aspectdItemInfo);
        }
      }
    } else {
      assert(false);
    }
    return staticInvocation;
  }

  //Library Static Method Invocation
  StaticInvocation transformLibraryStaticMethodInvocation(StaticInvocation staticInvocation, Procedure procedure, AspectdItemInfo aspectdItemInfo) {
    assert(aspectdItemInfo.mode!=null);
    Library procedureLibrary = procedure.parent as Library;

    //更改原始调用
    Arguments redirectArguments = Arguments.empty();
    Map<String, String> sourceInfo = AspectdUtils.calcSourceInfo(_uriToSource,_curLibrary, staticInvocation.fileOffset);
    AspectdUtils.concatArgumentsForAspectdMethod(sourceInfo,redirectArguments, aspectdItemInfo, StringLiteral(procedureLibrary.importUri.toString()),procedure,staticInvocation.arguments);

    StaticInvocation staticInvocation2 = StaticInvocation(aspectdItemInfo.aspectdProcedure, redirectArguments);
    if(aspectdItemInfo.stubKey != null){
      return staticInvocation2;
    }

    insertStaticMethod4Pointcut(aspectdItemInfo, AspectdUtils.pointCutProceedProcedure.parent as Class, staticInvocation, procedureLibrary,procedure);
    return staticInvocation2;
  }

  //Class Static Method Invocation
  StaticInvocation transformClassStaticMethodInvocation(StaticInvocation staticInvocation, AspectdItemInfo aspectdItemInfo) {
    assert(aspectdItemInfo.mode!=null);
    Procedure procedure = staticInvocation.targetReference.node as Procedure;
    Class procedureClass = procedure.parent as Class;

    //更改原始调用
    Arguments redirectArguments = Arguments.empty();
    Map<String, String>  sourceInfo = AspectdUtils.calcSourceInfo(_uriToSource,_curLibrary, staticInvocation.fileOffset);
    AspectdUtils.concatArgumentsForAspectdMethod(sourceInfo,redirectArguments, aspectdItemInfo, StringLiteral(procedureClass.name),procedure,staticInvocation.arguments);

    StaticInvocation staticInvocation2 = StaticInvocation(aspectdItemInfo.aspectdProcedure, redirectArguments);
    if(aspectdItemInfo.stubKey != null){
      return staticInvocation2;
    }

    insertStaticMethod4Pointcut(aspectdItemInfo, AspectdUtils.pointCutProceedProcedure.parent as Class, staticInvocation, staticInvocation.targetReference.node.parent.parent as Library, procedure);
    return staticInvocation2;
  }

  //Instance Method Invocation
  MethodInvocation transformInstanceMethodInvocation(MethodInvocation methodInvocation, AspectdItemInfo aspectdItemInfo) {
    assert(aspectdItemInfo.mode!=null);

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
    Map<String, String>  sourceInfo = AspectdUtils.calcSourceInfo(_uriToSource,_curLibrary, methodInvocation.fileOffset);
    AspectdUtils.concatArgumentsForAspectdMethod(sourceInfo,redirectArguments, aspectdItemInfo, methodInvocation.receiver,methodProcedure,methodInvocation.arguments);

    Class cls = aspectdItemInfo.aspectdProcedure.parent as Class;
    ConstructorInvocation redirectConstructorInvocation = ConstructorInvocation.byReference(cls.constructors.first.reference, Arguments([]));
    MethodInvocation methodInvocation2 = MethodInvocation(redirectConstructorInvocation, aspectdItemInfo.aspectdProcedure.name, redirectArguments);
    AspectdUtils.insertLibraryDependency(_curLibrary, aspectdItemInfo.aspectdProcedure.parent.parent);
    if(aspectdItemInfo.stubKey != null){
      return methodInvocation2;
    }

    insertInstanceMethod4Pointcut(aspectdItemInfo, AspectdUtils.pointCutProceedProcedure.parent as Class,methodImplClass, methodProcedure);
    return methodInvocation2;
  }

  bool insertStaticMethod4Pointcut(AspectdItemInfo aspectdItemInfo, Class pointCutClass, StaticInvocation originalStaticInvocation, Library originalLibrary,Procedure originalProcedure) {
    //Add library dependency
    AspectdUtils.insertLibraryDependency(pointCutClass.parent as Library, originalLibrary);
    //Add new Procedure
    StaticInvocation staticInvocation = StaticInvocation(originalProcedure, AspectdUtils.concatArguments4PointcutStubCall(originalProcedure), isConst: originalProcedure.isConst);
    _transformedInvocationSet.add(staticInvocation);
    bool shouldReturn = !(originalProcedure.function.returnType is VoidType);
    createPointcutStubProcedure(aspectdItemInfo,pointCutClass,AspectdUtils.createProcedureBodyWithExpression(staticInvocation, shouldReturn),shouldReturn);
    return true;
  }

  bool insertInstanceMethod4Pointcut(AspectdItemInfo aspectdItemInfo,Class pointCutClass, Class procedureImpl, Procedure originalProcedure) {
    //Add library dependency
    //Add new Procedure
    DirectMethodInvocation mockedInvocation = DirectMethodInvocation(AsExpression(PropertyGet(ThisExpression(),Name('target')), InterfaceType(procedureImpl)), originalProcedure, AspectdUtils.concatArguments4PointcutStubCall(originalProcedure));
    _transformedInvocationSet.add(mockedInvocation);
    bool shouldReturn = !(originalProcedure.function.returnType is VoidType);
    createPointcutStubProcedure(aspectdItemInfo,pointCutClass, AspectdUtils.createProcedureBodyWithExpression(mockedInvocation, !(originalProcedure.function.returnType is VoidType)), shouldReturn);
    return true;
  }

  //Will create stub and insert call branch in proceed.
  void createPointcutStubProcedure(AspectdItemInfo aspectdItemInfo,Class pointCutClass,Statement bodyStatements, bool shouldReturn) {
    String stubMethodName = '${AspectdUtils.kAspectdStubMethodPrefix}${AspectdUtils.kPrimaryKeyAspectdMethod}';
    aspectdItemInfo.stubKey = stubMethodName;
    Procedure procedure = AspectdUtils.createStubProcedure(Name(aspectdItemInfo.stubKey,AspectdUtils.pointCutProceedProcedure.name.library), aspectdItemInfo, AspectdUtils.pointCutProceedProcedure, bodyStatements, shouldReturn);
    pointCutClass.addMember(procedure);
    AspectdUtils.insertProceedBranch(procedure, shouldReturn);
    AspectdUtils.kPrimaryKeyAspectdMethod++;
  }
}

