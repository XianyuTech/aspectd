// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:kernel/ast.dart';
import 'package:front_end/src/fasta/kernel/kernel_ast_api.dart';
import 'utils.dart';

class AopStatementsInsertInfo {
  final Library library;
  final Source source;
  final Constructor constructor;
  final Procedure procedure;
  final Node node;
  final AopItemInfo aopItemInfo;
  final List<Statement> aopInsertStatements;
  AopStatementsInsertInfo({this.library,this.source,this.constructor,this.procedure,this.node,this.aopItemInfo, this.aopInsertStatements});
}

class AopExecuteImplTransformer extends Transformer{
  Map<String,AopItemInfo> _aopInfoMap;
  Map<String,Library> _libraryMap;

  AopExecuteImplTransformer(this._aopInfoMap, this._libraryMap);

  void aopTransform() {
    _aopInfoMap?.forEach((String uniqueKey, AopItemInfo aopItemInfo){
      Library aopAnnoLibrary = _libraryMap[aopItemInfo.importUri];
      String clsName = aopItemInfo.clsName;
      //类静态/实例方法
      if(clsName != null && clsName.length>0) {
        Class expectedCls = null;
        for(Class cls in aopAnnoLibrary.classes) {
          if(cls.name == aopItemInfo.clsName) {
            expectedCls = cls;
            //Check Procedures
            for(Procedure procedure in cls.procedures) {
              if(procedure.name.name == aopItemInfo.methodName && procedure.isStatic == aopItemInfo.isStatic && procedure.function.body != null) {
                transformMethodProcedure(aopAnnoLibrary, procedure, aopItemInfo);
                return;
              }
            }
            break;
          }
        }
        _libraryMap.forEach((importUri,lib){
          for(Class cls in lib.classes) {
            bool matches = false;
            if(cls.name == aopItemInfo.clsName) {
              matches = true;
            } else {
              for(int i=0;i<cls.implementedTypes.length && matches == false;i++){
                Supertype supertype = cls.implementedTypes[i];
                if(supertype.className.node == expectedCls && cls.parent == expectedCls.parent && cls.name == '_'+expectedCls.name) {
                  matches = true;
                }
              }
            }
            if(!matches)
              continue;
            for(int i=0;i<cls.procedures.length;i++) {
              Procedure procedure = cls.procedures[i];
              if(procedure.name.name == aopItemInfo.methodName && procedure.isStatic == aopItemInfo.isStatic) {
                transformMethodProcedure(lib, procedure, aopItemInfo);
                return;
              }
            }
          }
        });
      } else {
        for(int i=0;i<aopAnnoLibrary.procedures.length;i++) {
          Procedure procedure = aopAnnoLibrary.procedures[i];
          if(procedure.name.name == aopItemInfo.methodName && procedure.isStatic == aopItemInfo.isStatic) {
            transformMethodProcedure(aopAnnoLibrary, procedure, aopItemInfo);
          }
        }
      }
    });
  }

  void transformMethodProcedure(Library library, Procedure procedure, AopItemInfo aopItemInfo) {
    if(!AopUtils.canOperateLibrary(library))
      return;
    if(procedure.parent is Class) {
        if(procedure.isStatic) {
          transformStaticMethodProcedure(library,aopItemInfo,procedure);
        } else {
          transformInstanceMethodProcedure(library,aopItemInfo,procedure);
        }
      } else if(procedure.parent is Library) {
        transformStaticMethodProcedure(library,aopItemInfo,procedure);
      }
  }

  void transformStaticMethodProcedure(Library originalLibrary,AopItemInfo aopItemInfo,Procedure originalProcedure) {
      FunctionNode functionNode = originalProcedure.function;
      Statement body = functionNode.body;
      bool shouldReturn = !(originalProcedure.function.returnType is VoidType);

      String stubMethodName = '${AopUtils.kAopStubMethodPrefix}${AopUtils.kPrimaryKeyAopMethod}';
      aopItemInfo.stubKey = stubMethodName;
      AopUtils.kPrimaryKeyAopMethod++;

      //目标新建stub函数，方便完成目标->aopstub->目标stub链路
      Procedure originalStubProcedure = AopUtils.createStubProcedure(Name(originalProcedure.name.name+'_'+aopItemInfo.stubKey,originalProcedure.name.library), aopItemInfo, originalProcedure,body, shouldReturn);
      Node parent = originalProcedure.parent;
      if(parent is Library) {
        parent.addMember(originalStubProcedure);
      } else if(parent is Class) {
        parent.addMember(originalStubProcedure);
      }
      functionNode.body = createPointcutCallFromOriginal(originalLibrary,aopItemInfo, NullLiteral(), originalProcedure, AopUtils.argumentsFromFunctionNode(functionNode) ,shouldReturn);

      //Pointcut类中新增stub，并且添加调用
      Library pointcutLibrary = AopUtils.pointCutProceedProcedure.parent.parent as Library;
      Class pointcutClass = AopUtils.pointCutProceedProcedure.parent as Class;
      AopUtils.insertLibraryDependency(pointcutLibrary, originalLibrary);

      StaticInvocation staticInvocation = StaticInvocation(originalStubProcedure, AopUtils.concatArguments4PointcutStubCall(originalProcedure), isConst: originalStubProcedure.isConst);

      Procedure stubProcedure2 = AopUtils.createStubProcedure(Name(aopItemInfo.stubKey,AopUtils.pointCutProceedProcedure.name.library) ,aopItemInfo, AopUtils.pointCutProceedProcedure, AopUtils.createProcedureBodyWithExpression(staticInvocation, shouldReturn), shouldReturn);
      pointcutClass.addMember(stubProcedure2);
      AopUtils.insertProceedBranch(stubProcedure2, shouldReturn);
  }

  void transformInstanceMethodProcedure(Library originalLibrary,AopItemInfo aopItemInfo,Procedure originalProcedure) {
    FunctionNode functionNode = originalProcedure.function;
    Class originalClass = (originalProcedure.parent as Class);
    Statement body = functionNode.body;
    if(body == null) {
      return;
    }
    bool shouldReturn = !(originalProcedure.function.returnType is VoidType);

    String stubMethodName = '${AopUtils.kAopStubMethodPrefix}${AopUtils.kPrimaryKeyAopMethod}';
    aopItemInfo.stubKey = stubMethodName;
    AopUtils.kPrimaryKeyAopMethod++;

    //目标新建stub函数，方便完成目标->aopstub->目标stub链路
    Procedure originalStubProcedure = AopUtils.createStubProcedure(Name(originalProcedure.name.name+'_'+aopItemInfo.stubKey,originalProcedure.name.library), aopItemInfo, originalProcedure,body, shouldReturn);
    originalClass.addMember(originalStubProcedure);
    functionNode.body = createPointcutCallFromOriginal(originalLibrary,aopItemInfo, ThisExpression(), originalProcedure, AopUtils.argumentsFromFunctionNode(functionNode) ,shouldReturn);

    //Pointcut类中新增stub，并且添加调用
    Library pointcutLibrary = AopUtils.pointCutProceedProcedure.parent.parent as Library;
    Class pointcutClass = AopUtils.pointCutProceedProcedure.parent as Class;
    AopUtils.insertLibraryDependency(pointcutLibrary, originalLibrary);

    DirectMethodInvocation mockedInvocation = DirectMethodInvocation(AsExpression(PropertyGet(ThisExpression(),Name('target')), InterfaceType(originalClass)), originalStubProcedure, AopUtils.concatArguments4PointcutStubCall(originalProcedure));

    Procedure stubProcedure2 = AopUtils.createStubProcedure(Name(aopItemInfo.stubKey,AopUtils.pointCutProceedProcedure.name.library) ,aopItemInfo, AopUtils.pointCutProceedProcedure, AopUtils.createProcedureBodyWithExpression(mockedInvocation, shouldReturn), shouldReturn);
    pointcutClass.addMember(stubProcedure2);
    AopUtils.insertProceedBranch(stubProcedure2, shouldReturn);
  }

  Block createPointcutCallFromOriginal(Library library, AopItemInfo aopItemInfo,Expression targetExpression, Procedure procedure,Arguments arguments,bool shouldReturn) {
    AopUtils.insertLibraryDependency(library, aopItemInfo.aopProcedure.parent.parent);
    Arguments redirectArguments = Arguments.empty();
    AopUtils.concatArgumentsForAopMethod(null,redirectArguments, aopItemInfo, targetExpression, procedure,arguments);
    Expression callExpression = null;
    if(aopItemInfo.aopProcedure.isStatic) {
      callExpression = StaticInvocation(aopItemInfo.aopProcedure, redirectArguments);
    } else {
      ConstructorInvocation redirectConstructorInvocation = ConstructorInvocation.byReference((aopItemInfo.aopProcedure.parent as Class).constructors.first.reference, Arguments([]));
      callExpression = MethodInvocation(redirectConstructorInvocation, aopItemInfo.aopProcedure.name, redirectArguments);
    }
    return AopUtils.createProcedureBodyWithExpression(callExpression, shouldReturn);
  }
}