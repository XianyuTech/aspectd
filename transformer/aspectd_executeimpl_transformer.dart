// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:kernel/ast.dart';
import 'package:front_end/src/fasta/kernel/kernel_ast_api.dart';
import 'utils.dart';

class AspectdStatementsInsertInfo {
  final Library library;
  final Source source;
  final Constructor constructor;
  final Procedure procedure;
  final Node node;
  final AspectdItemInfo aspectdItemInfo;
  final List<Statement> aspectdInsertStatements;
  AspectdStatementsInsertInfo({this.library,this.source,this.constructor,this.procedure,this.node,this.aspectdItemInfo, this.aspectdInsertStatements});
}

class AspectdExecuteImplTransformer extends Transformer{
  Map<String,AspectdItemInfo> _aspectdInfoMap;
  Map<String,Library> _libraryMap;

  AspectdExecuteImplTransformer(this._aspectdInfoMap, this._libraryMap);

  void aspectdTransform() {
    _aspectdInfoMap?.forEach((String uniqueKey, AspectdItemInfo aspectdItemInfo){
      Library aspectdAnnoLibrary = _libraryMap[aspectdItemInfo.importUri];
      String clsName = aspectdItemInfo.clsName;
      //类静态/实例方法
      if(clsName != null && clsName.length>0) {
        Class expectedCls = null;
        for(Class cls in aspectdAnnoLibrary.classes) {
          if(cls.name == aspectdItemInfo.clsName) {
            expectedCls = cls;
            //Check Procedures
            for(Procedure procedure in cls.procedures) {
              if(procedure.name.name == aspectdItemInfo.methodName && procedure.isStatic == aspectdItemInfo.isStatic && procedure.function.body != null) {
                transformMethodProcedure(aspectdAnnoLibrary, procedure, aspectdItemInfo);
                return;
              }
            }
            break;
          }
        }
        _libraryMap.forEach((importUri,lib){
          for(Class cls in lib.classes) {
            bool matches = false;
            if(cls.name == aspectdItemInfo.clsName) {
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
              if(procedure.name.name == aspectdItemInfo.methodName && procedure.isStatic == aspectdItemInfo.isStatic) {
                transformMethodProcedure(lib, procedure, aspectdItemInfo);
                return;
              }
            }
          }
        });
      } else {
        for(int i=0;i<aspectdAnnoLibrary.procedures.length;i++) {
          Procedure procedure = aspectdAnnoLibrary.procedures[i];
          if(procedure.name.name == aspectdItemInfo.methodName && procedure.isStatic == aspectdItemInfo.isStatic) {
            transformMethodProcedure(aspectdAnnoLibrary, procedure, aspectdItemInfo);
          }
        }
      }
    });
  }

  void transformMethodProcedure(Library library, Procedure procedure, AspectdItemInfo aspectdItemInfo) {
    if(!AspectdUtils.canOperateLibrary(library))
      return;
    if(procedure.parent is Class) {
        if(procedure.isStatic) {
          transformStaticMethodProcedure(library,aspectdItemInfo,procedure);
        } else {
          transformInstanceMethodProcedure(library,aspectdItemInfo,procedure);
        }
      } else if(procedure.parent is Library) {
        transformStaticMethodProcedure(library,aspectdItemInfo,procedure);
      }
  }

  void transformStaticMethodProcedure(Library originalLibrary,AspectdItemInfo aspectdItemInfo,Procedure originalProcedure) {
      FunctionNode functionNode = originalProcedure.function;
      Statement body = functionNode.body;
      bool shouldReturn = !(originalProcedure.function.returnType is VoidType);

      String stubMethodName = '${AspectdUtils.kAspectdStubMethodPrefix}${AspectdUtils.kPrimaryKeyAspectdMethod}';
      aspectdItemInfo.stubKey = stubMethodName;
      AspectdUtils.kPrimaryKeyAspectdMethod++;

      //目标新建stub函数，方便完成目标->aopstub->目标stub链路
      Procedure originalStubProcedure = AspectdUtils.createStubProcedure(Name(originalProcedure.name.name+'_'+aspectdItemInfo.stubKey,originalProcedure.name.library), aspectdItemInfo, originalProcedure,body, shouldReturn);
      Node parent = originalProcedure.parent;
      if(parent is Library) {
        parent.addMember(originalStubProcedure);
      } else if(parent is Class) {
        parent.addMember(originalStubProcedure);
      }
      functionNode.body = createPointcutCallFromOriginal(originalLibrary,aspectdItemInfo, NullLiteral(), originalProcedure, AspectdUtils.argumentsFromFunctionNode(functionNode) ,shouldReturn);

      //Pointcut类中新增stub，并且添加调用
      Library pointcutLibrary = AspectdUtils.pointCutProceedProcedure.parent.parent as Library;
      Class pointcutClass = AspectdUtils.pointCutProceedProcedure.parent as Class;
      AspectdUtils.insertLibraryDependency(pointcutLibrary, originalLibrary);

      StaticInvocation staticInvocation = StaticInvocation(originalStubProcedure, AspectdUtils.concatArguments4PointcutStubCall(originalProcedure), isConst: originalStubProcedure.isConst);

      Procedure stubProcedure2 = AspectdUtils.createStubProcedure(Name(aspectdItemInfo.stubKey,AspectdUtils.pointCutProceedProcedure.name.library) ,aspectdItemInfo, AspectdUtils.pointCutProceedProcedure, AspectdUtils.createProcedureBodyWithExpression(staticInvocation, shouldReturn), shouldReturn);
      pointcutClass.addMember(stubProcedure2);
      AspectdUtils.insertProceedBranch(stubProcedure2, shouldReturn);
  }

  void transformInstanceMethodProcedure(Library originalLibrary,AspectdItemInfo aspectdItemInfo,Procedure originalProcedure) {
    FunctionNode functionNode = originalProcedure.function;
    Class originalClass = (originalProcedure.parent as Class);
    Statement body = functionNode.body;
    if(body == null) {
      return;
    }
    bool shouldReturn = !(originalProcedure.function.returnType is VoidType);

    String stubMethodName = '${AspectdUtils.kAspectdStubMethodPrefix}${AspectdUtils.kPrimaryKeyAspectdMethod}';
    aspectdItemInfo.stubKey = stubMethodName;
    AspectdUtils.kPrimaryKeyAspectdMethod++;

    //目标新建stub函数，方便完成目标->aopstub->目标stub链路
    Procedure originalStubProcedure = AspectdUtils.createStubProcedure(Name(originalProcedure.name.name+'_'+aspectdItemInfo.stubKey,originalProcedure.name.library), aspectdItemInfo, originalProcedure,body, shouldReturn);
    originalClass.addMember(originalStubProcedure);
    functionNode.body = createPointcutCallFromOriginal(originalLibrary,aspectdItemInfo, ThisExpression(), originalProcedure, AspectdUtils.argumentsFromFunctionNode(functionNode) ,shouldReturn);

    //Pointcut类中新增stub，并且添加调用
    Library pointcutLibrary = AspectdUtils.pointCutProceedProcedure.parent.parent as Library;
    Class pointcutClass = AspectdUtils.pointCutProceedProcedure.parent as Class;
    AspectdUtils.insertLibraryDependency(pointcutLibrary, originalLibrary);

    DirectMethodInvocation mockedInvocation = DirectMethodInvocation(AsExpression(PropertyGet(ThisExpression(),Name('target')), InterfaceType(originalClass)), originalStubProcedure, AspectdUtils.concatArguments4PointcutStubCall(originalProcedure));

    Procedure stubProcedure2 = AspectdUtils.createStubProcedure(Name(aspectdItemInfo.stubKey,AspectdUtils.pointCutProceedProcedure.name.library) ,aspectdItemInfo, AspectdUtils.pointCutProceedProcedure, AspectdUtils.createProcedureBodyWithExpression(mockedInvocation, shouldReturn), shouldReturn);
    pointcutClass.addMember(stubProcedure2);
    AspectdUtils.insertProceedBranch(stubProcedure2, shouldReturn);
  }

  Block createPointcutCallFromOriginal(Library library,AspectdItemInfo aspectdItemInfo,Expression targetExpression, Procedure procedure,Arguments arguments,bool shouldReturn) {
    AspectdUtils.insertLibraryDependency(library, aspectdItemInfo.aspectdProcedure.parent.parent);
    Arguments redirectArguments = Arguments.empty();
    AspectdUtils.concatArgumentsForAspectdMethod(null,redirectArguments, aspectdItemInfo, targetExpression, procedure,arguments);
    Expression callExpression = null;
    if(aspectdItemInfo.aspectdProcedure.isStatic) {
      callExpression = StaticInvocation(aspectdItemInfo.aspectdProcedure, redirectArguments);
    } else {
      ConstructorInvocation redirectConstructorInvocation = ConstructorInvocation.byReference((aspectdItemInfo.aspectdProcedure.parent as Class).constructors.first.reference, Arguments([]));
      callExpression = MethodInvocation(redirectConstructorInvocation, aspectdItemInfo.aspectdProcedure.name, redirectArguments);
    }
    return AspectdUtils.createProcedureBodyWithExpression(callExpression, shouldReturn);
  }
}