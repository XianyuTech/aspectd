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
            //Check Constructors
            for(Constructor constructor in cls.constructors) {
              String functionName = '${cls.name}';
              if (constructor.name.name.isNotEmpty) {
                functionName += '.${constructor.name.name}';
              }
              if(functionName == aopItemInfo.methodName && true == aopItemInfo.isStatic && constructor.function.body != null) {
                transformConstructor(aopAnnoLibrary, constructor, aopItemInfo);
                return;
              }
            }
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
        //一些被系统操控的特殊类，如_Random等
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
            //Check Constructors
            for(Constructor constructor in cls.constructors) {
              String functionName = '${cls.name}';
              if (constructor.name.name.isNotEmpty) {
                functionName += '.${constructor.name.name}';
              }
              if(functionName == aopItemInfo.methodName && true == aopItemInfo.isStatic && constructor.function.body != null) {
                transformConstructor(aopAnnoLibrary, constructor, aopItemInfo);
                return;
              }
            }
            for(int i=0;i<cls.procedures.length;i++) {
              Procedure procedure = cls.procedures[i];
              if(procedure.name.name == aopItemInfo.methodName && procedure.isStatic == aopItemInfo.isStatic) {
                transformMethodProcedure(lib, procedure, aopItemInfo);
                return;
              }
            }
          }
        });
      }
      // 库静态方法
      else {
        for(int i=0;i<aopAnnoLibrary.procedures.length;i++) {
          Procedure procedure = aopAnnoLibrary.procedures[i];
          if(procedure.name.name == aopItemInfo.methodName && procedure.isStatic == aopItemInfo.isStatic) {
            transformMethodProcedure(aopAnnoLibrary, procedure, aopItemInfo);
          }
        }
      }
    });
  }

  void transformConstructor(Library originalLibrary, Constructor constructor, AopItemInfo aopItemInfo) {
    if(!AopUtils.canOperateLibrary(originalLibrary))
      return;
    FunctionNode functionNode = constructor.function;
    Statement body = functionNode.body;
    bool shouldReturn = !(constructor.function.returnType is VoidType);

    String stubMethodName = '${AopUtils.kAopStubMethodPrefix}${AopUtils.kPrimaryKeyAopMethod}';
    aopItemInfo.stubKey = stubMethodName;
    AopUtils.kPrimaryKeyAopMethod++;

    //目标新建stub函数，方便完成目标->aopstub->目标stub链路
    Member originalStubConstructor = AopUtils.createStubConstructor(Name(constructor.name.name+'_'+aopItemInfo.stubKey, constructor.parent.parent), aopItemInfo, constructor, body, shouldReturn);
    Node parent = constructor.parent;
    if(parent is Library) {
      parent.addMember(originalStubConstructor);
    } else if(parent is Class) {
      parent.addMember(originalStubConstructor);
    }
    functionNode.body = createPointcutCallFromOriginal(originalLibrary,aopItemInfo, NullLiteral(), constructor, AopUtils.argumentsFromFunctionNode(functionNode) ,shouldReturn);

    //Pointcut类中新增stub，并且添加调用
    Library pointcutLibrary = AopUtils.pointCutProceedProcedure.parent.parent as Library;
    Class pointcutClass = AopUtils.pointCutProceedProcedure.parent as Class;
    AopUtils.insertLibraryDependency(pointcutLibrary, originalLibrary);

    ConstructorInvocation constructorInvocation = ConstructorInvocation(originalStubConstructor, AopUtils.concatArguments4PointcutStubCall(constructor), isConst: originalStubConstructor.isConst);
    Procedure stubProcedureNew = AopUtils.createStubProcedure(Name(aopItemInfo.stubKey,AopUtils.pointCutProceedProcedure.name.library) ,aopItemInfo, AopUtils.pointCutProceedProcedure, AopUtils.createProcedureBodyWithExpression(constructorInvocation, shouldReturn), shouldReturn);
    pointcutClass.addMember(stubProcedureNew);
    AopUtils.insertProceedBranch(stubProcedureNew, shouldReturn);
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

      Procedure stubProcedureNew = AopUtils.createStubProcedure(Name(aopItemInfo.stubKey,AopUtils.pointCutProceedProcedure.name.library) ,aopItemInfo, AopUtils.pointCutProceedProcedure, AopUtils.createProcedureBodyWithExpression(staticInvocation, shouldReturn), shouldReturn);
      pointcutClass.addMember(stubProcedureNew);
      AopUtils.insertProceedBranch(stubProcedureNew, shouldReturn);
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

    Procedure stubProcedureNew = AopUtils.createStubProcedure(Name(aopItemInfo.stubKey,AopUtils.pointCutProceedProcedure.name.library) ,aopItemInfo, AopUtils.pointCutProceedProcedure, AopUtils.createProcedureBodyWithExpression(mockedInvocation, shouldReturn), shouldReturn);
    pointcutClass.addMember(stubProcedureNew);
    AopUtils.insertProceedBranch(stubProcedureNew, shouldReturn);
  }

  Block createPointcutCallFromOriginal(Library library, AopItemInfo aopItemInfo,Expression targetExpression, Member member, Arguments arguments,bool shouldReturn) {
    AopUtils.insertLibraryDependency(library, aopItemInfo.aopMember.parent.parent);
    Arguments redirectArguments = Arguments.empty();
    AopUtils.concatArgumentsForAopMethod(null,redirectArguments, aopItemInfo, targetExpression, member, arguments);
    Expression callExpression = null;
    if (aopItemInfo.aopMember is Procedure) {
      Procedure procedure = aopItemInfo.aopMember;
      if(procedure.isStatic) {
        callExpression = StaticInvocation(aopItemInfo.aopMember, redirectArguments);
      } else {
        ConstructorInvocation redirectConstructorInvocation = ConstructorInvocation.byReference((aopItemInfo.aopMember.parent as Class).constructors.first.reference, Arguments([]));
        callExpression = MethodInvocation(redirectConstructorInvocation, aopItemInfo.aopMember.name, redirectArguments);
      }
    }
    return AopUtils.createProcedureBodyWithExpression(callExpression, shouldReturn);
  }
}