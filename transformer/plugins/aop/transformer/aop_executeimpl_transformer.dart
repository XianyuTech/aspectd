// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:kernel/ast.dart';
import 'package:front_end/src/fasta/kernel/kernel_ast_api.dart';

import 'aop_iteminfo.dart';
import 'aop_utils.dart';

class AopStatementsInsertInfo {
  AopStatementsInsertInfo({this.library,this.source,this.constructor,this.procedure,this.node,this.aopItemInfo, this.aopInsertStatements});

  final Library library;
  final Source source;
  final Constructor constructor;
  final Procedure procedure;
  final Node node;
  final AopItemInfo aopItemInfo;
  final List<Statement> aopInsertStatements;
}

class AopExecuteImplTransformer extends Transformer{
  AopExecuteImplTransformer(this._aopItemInfoList, this._libraryMap);

  final List<AopItemInfo> _aopItemInfoList;
  final Map<String,Library> _libraryMap;

  Set<Library> _filterLibraryWithAopItemInfo (Map<String,Library> libraryMap, AopItemInfo aopItemInfo) {
    final Set<Library> filteredLibraries = <Library>{};
    if (aopItemInfo.isRegex) {
      for (String libraryName in libraryMap.keys) {
        if (RegExp(aopItemInfo.importUri).hasMatch(libraryName)) {
          filteredLibraries.add(libraryMap[libraryName]);
        }
      }
    } else {
      final Library library = libraryMap[aopItemInfo.importUri];
      if (library != null) {
        filteredLibraries.add(library);
      }
    }
    return filteredLibraries;
  }

  Member _filterFirstMatchPatchClassMember(Map<String,Library> libraryMap, Member expectMember, AopItemInfo aopItemInfo) {
    Member filteredMember;
    final Class expectedCls = expectMember.parent;
    for (String importUri in libraryMap.keys) {
      final Library lib = libraryMap[importUri];
      if (lib != expectedCls.parent) {
        continue;
      }
      for (Class mightPatchCls in lib.classes) {
        bool matches = false;
        if (mightPatchCls.name == aopItemInfo.clsName) {
          matches = true;
        } else {
          for (int i=0;i<mightPatchCls.implementedTypes.length && matches == false;i++) {
            final Supertype supertype = mightPatchCls.implementedTypes[i];
            if (supertype.className.node == expectedCls && mightPatchCls.parent == expectedCls.parent && mightPatchCls.name == '_'+expectedCls.name) {
              matches = true;
            }
          }
        }
        if (matches) {
          for (Member member in mightPatchCls.members) {
            //Here, the patch member's body must be non-empty.
            if (member.name.name == expectMember.name.name && member.function.body != null) {
              return member;
            }
          }
        }
      }
    }
    return filteredMember;
  }

  Set<Procedure> _filterLibraryProcedureWithAopItemInfo (Library library, AopItemInfo aopItemInfo) {
    final Set<Procedure> filteredProcedures = <Procedure>{};
    //Check Procedures
    for (Procedure procedure in library.procedures) {
      if (procedure.isStatic == aopItemInfo.isStatic && procedure.function.body != null) {
        if (aopItemInfo.isRegex) {
          if (RegExp(aopItemInfo.methodName).hasMatch(procedure.name.name)) {
            filteredProcedures.add(procedure);
          }
        } else {
          if (aopItemInfo.methodName == procedure.name.name) {
            filteredProcedures.add(procedure);
          }
        }
      }
    }
    return filteredProcedures;
  }

  Set<Class> _filterClassWithAopItemInfo (Library library, AopItemInfo aopItemInfo) {
    assert((aopItemInfo.clsName?.length ?? 0)>0);
    final Set<Class> filteredClasses = <Class>{};
    for (Class cls in library.classes) {
      if (aopItemInfo.isRegex) {
        if (RegExp(aopItemInfo.clsName).hasMatch(cls.name)) {
          filteredClasses.add(cls);
        }
      } else {
        if (aopItemInfo.clsName == cls.name) {
          filteredClasses.add(cls);
        }
      }
    }
    return filteredClasses;
  }

  Set<Member> _filterClassMemberWithAopItemInfo (Class cls, AopItemInfo aopItemInfo) {
    final Set<Member> filteredMembers = <Member>{};
    //Check Constructors
    for (Constructor constructor in cls.constructors) {
      final String functionName = AopUtils.nameForConstructor(constructor);
      if (true == aopItemInfo.isStatic) { //&& constructor.function.body != null
        if (aopItemInfo.isRegex) {
          if (RegExp(aopItemInfo.methodName).hasMatch(functionName)) {
            filteredMembers.add(constructor);
          }
        } else {
          if (aopItemInfo.methodName == functionName) {
            filteredMembers.add(constructor);
          }
        }
      }
    }
    //Check Procedures
    for (Procedure procedure in cls.procedures) {
      if (procedure.isStatic == aopItemInfo.isStatic) { //procedure.function.body != null
        if (aopItemInfo.isRegex) {
          if (RegExp(aopItemInfo.methodName).hasMatch(procedure.name.name)) {
            filteredMembers.add(procedure);
          }
        } else {
          if (aopItemInfo.methodName == procedure.name.name) {
            filteredMembers.add(procedure);
          }
        }
      }
    }
    return filteredMembers;
  }

  void aopTransform() {
    for (AopItemInfo aopItemInfo in _aopItemInfoList) {
      final Set<Library> filteredLibraries = _filterLibraryWithAopItemInfo(_libraryMap, aopItemInfo);
      for (Library filteredLibrary in filteredLibraries) {
        final String clsName = aopItemInfo.clsName;
        //库静态方法
        final bool isLibraryMethodNotRegex = (clsName?.length ?? 0) == 0 && !aopItemInfo.isRegex;
        final bool isLibraryMethodAndRegex = RegExp(clsName).hasMatch('') && aopItemInfo.isRegex;
        if (isLibraryMethodNotRegex || isLibraryMethodAndRegex) {
          final Set<Procedure> filteredProcedures = _filterLibraryProcedureWithAopItemInfo(filteredLibrary, aopItemInfo);
          for (Procedure procedure in filteredProcedures) {
            transformMethodProcedure(filteredLibrary, procedure, aopItemInfo);
          }
        }
        //类静态/实例方法
        if ((clsName?.length ?? 0) > 0) {
          final Set<Class> filteredLibraryClses = _filterClassWithAopItemInfo(filteredLibrary, aopItemInfo);
          for (Class filteredCls in filteredLibraryClses) {
            final Set<Member> filteredMembers = _filterClassMemberWithAopItemInfo(filteredCls, aopItemInfo);
            for (Member filteredMember in filteredMembers) {
              if (filteredMember is Constructor) {
                transformConstructor(filteredLibrary, filteredMember, aopItemInfo);
              } else if (filteredMember is Procedure) {
                if (filteredMember.function.body == null) {
                  filteredMember = _filterFirstMatchPatchClassMember(_libraryMap, filteredMember, aopItemInfo);
                }
                transformMethodProcedure(filteredLibrary, filteredMember, aopItemInfo);
              }
            }
          }
        }
      }
    }
  }

  void transformConstructor(Library originalLibrary, Constructor constructor, AopItemInfo aopItemInfo) {
    if (constructor?.function?.body == null) {
      return;
    }
    if (!AopUtils.canOperateLibrary(originalLibrary)) {
      return;
    }
    final FunctionNode functionNode = constructor.function;
    final Statement body = functionNode.body;
    final bool shouldReturn = !(constructor.function.returnType is VoidType);

    final String stubKey = '${AopUtils.kAopStubMethodPrefix}${AopUtils.kPrimaryKeyAopMethod}';
    AopUtils.kPrimaryKeyAopMethod++;

    final String constructorName = AopUtils.nameForConstructor(constructor);

    //目标新建stub函数，方便完成目标->aopstub->目标stub链路
    final Member originalStubConstructor = AopUtils.createStubConstructor(Name(constructorName+'_'+stubKey, constructor.parent.parent), aopItemInfo, constructor, body, shouldReturn);
    final Node parent = constructor.parent;
    if (parent is Library) {
      parent.addMember(originalStubConstructor);
    } else if (parent is Class) {
      parent.addMember(originalStubConstructor);
    }

    functionNode.body = createPointcutCallFromOriginal(originalLibrary,aopItemInfo, stubKey, StringLiteral(constructorName), constructor, AopUtils.argumentsFromFunctionNode(functionNode) ,shouldReturn);

    //Pointcut类中新增stub，并且添加调用
    final Library pointcutLibrary = AopUtils.pointCutProceedProcedure.parent.parent;
    final Class pointcutClass = AopUtils.pointCutProceedProcedure.parent;
    AopUtils.insertLibraryDependency(pointcutLibrary, originalLibrary);

    final ConstructorInvocation constructorInvocation = ConstructorInvocation(originalStubConstructor, AopUtils.concatArguments4PointcutStubCall(constructor), isConst: originalStubConstructor.isConst);
    final Procedure stubProcedureNew = AopUtils.createStubProcedure(Name(stubKey,AopUtils.pointCutProceedProcedure.name.library) ,aopItemInfo, AopUtils.pointCutProceedProcedure, AopUtils.createProcedureBodyWithExpression(constructorInvocation, shouldReturn), shouldReturn);
    pointcutClass.addMember(stubProcedureNew);
    AopUtils.insertProceedBranch(stubProcedureNew, shouldReturn);
  }

  void transformMethodProcedure(Library library, Procedure procedure, AopItemInfo aopItemInfo) {
    if (procedure?.function?.body == null) {
      return;
    }
    if (!AopUtils.canOperateLibrary(library)) {
      return;
    }
    if (procedure.parent is Class) {
        if (procedure.isStatic) {
          transformStaticMethodProcedure(library,aopItemInfo,procedure);
        } else {
          transformInstanceMethodProcedure(library,aopItemInfo,procedure);
        }
      } else if (procedure.parent is Library) {
        transformStaticMethodProcedure(library,aopItemInfo,procedure);
      }
  }

  void transformStaticMethodProcedure(Library originalLibrary,AopItemInfo aopItemInfo,Procedure originalProcedure) {
      final FunctionNode functionNode = originalProcedure.function;
      final Statement body = functionNode.body;
      final bool shouldReturn = !(originalProcedure.function.returnType is VoidType);

      final String stubKey = '${AopUtils.kAopStubMethodPrefix}${AopUtils.kPrimaryKeyAopMethod}';
      AopUtils.kPrimaryKeyAopMethod++;

      //目标新建stub函数，方便完成目标->aopstub->目标stub链路
      final Procedure originalStubProcedure = AopUtils.createStubProcedure(Name(originalProcedure.name.name+'_'+stubKey,originalProcedure.name.library), aopItemInfo, originalProcedure,body, shouldReturn);
      final Node parent = originalProcedure.parent;
      String parentIdentifier;
      if (parent is Library) {
        parent.addMember(originalStubProcedure);
        parentIdentifier = parent.importUri.toString();
      } else if (parent is Class) {
        parent.addMember(originalStubProcedure);
        parentIdentifier = parent.name;
      }
      functionNode.body = createPointcutCallFromOriginal(originalLibrary,aopItemInfo, stubKey, StringLiteral(parentIdentifier), originalProcedure, AopUtils.argumentsFromFunctionNode(functionNode) ,shouldReturn);

      //Pointcut类中新增stub，并且添加调用
      final Library pointcutLibrary = AopUtils.pointCutProceedProcedure.parent.parent;
      final Class pointcutClass = AopUtils.pointCutProceedProcedure.parent;
      AopUtils.insertLibraryDependency(pointcutLibrary, originalLibrary);

      final StaticInvocation staticInvocation = StaticInvocation(originalStubProcedure, AopUtils.concatArguments4PointcutStubCall(originalProcedure), isConst: originalStubProcedure.isConst);

      final Procedure stubProcedureNew = AopUtils.createStubProcedure(Name(stubKey, AopUtils.pointCutProceedProcedure.name.library) ,aopItemInfo, AopUtils.pointCutProceedProcedure, AopUtils.createProcedureBodyWithExpression(staticInvocation, shouldReturn), shouldReturn);
      pointcutClass.addMember(stubProcedureNew);
      AopUtils.insertProceedBranch(stubProcedureNew, shouldReturn);
  }

  void transformInstanceMethodProcedure(Library originalLibrary,AopItemInfo aopItemInfo,Procedure originalProcedure) {
    final FunctionNode functionNode = originalProcedure.function;
    final Class originalClass = originalProcedure.parent;
    final Statement body = functionNode.body;
    if (body == null) {
      return;
    }
    final bool shouldReturn = !(originalProcedure.function.returnType is VoidType);

    final String stubKey = '${AopUtils.kAopStubMethodPrefix}${AopUtils.kPrimaryKeyAopMethod}';
    AopUtils.kPrimaryKeyAopMethod++;

    //目标新建stub函数，方便完成目标->aopstub->目标stub链路
    final Procedure originalStubProcedure = AopUtils.createStubProcedure(Name(originalProcedure.name.name+'_'+stubKey,originalProcedure.name.library), aopItemInfo, originalProcedure,body, shouldReturn);
    originalClass.addMember(originalStubProcedure);
    functionNode.body = createPointcutCallFromOriginal(originalLibrary,aopItemInfo, stubKey, ThisExpression(), originalProcedure, AopUtils.argumentsFromFunctionNode(functionNode) ,shouldReturn);

    //Pointcut类中新增stub，并且添加调用
    final Library pointcutLibrary = AopUtils.pointCutProceedProcedure.parent.parent;
    final Class pointcutClass = AopUtils.pointCutProceedProcedure.parent;
    AopUtils.insertLibraryDependency(pointcutLibrary, originalLibrary);

    final DirectMethodInvocation mockedInvocation = DirectMethodInvocation(AsExpression(PropertyGet(ThisExpression(),Name('target')), InterfaceType(originalClass, Nullability.legacy)), originalStubProcedure, AopUtils.concatArguments4PointcutStubCall(originalProcedure));

    final Procedure stubProcedureNew = AopUtils.createStubProcedure(Name(stubKey,AopUtils.pointCutProceedProcedure.name.library) ,aopItemInfo, AopUtils.pointCutProceedProcedure, AopUtils.createProcedureBodyWithExpression(mockedInvocation, shouldReturn), shouldReturn);
    pointcutClass.addMember(stubProcedureNew);
    AopUtils.insertProceedBranch(stubProcedureNew, shouldReturn);
  }

  Block createPointcutCallFromOriginal(Library library, AopItemInfo aopItemInfo, String stubKey, Expression targetExpression, Member member, Arguments arguments,bool shouldReturn) {
    AopUtils.insertLibraryDependency(library, aopItemInfo.aopMember.parent.parent);
    final Arguments redirectArguments = Arguments.empty();
    AopUtils.concatArgumentsForAopMethod(null,redirectArguments, stubKey, targetExpression, member, arguments);
    Expression callExpression;
    if (aopItemInfo.aopMember is Procedure) {
      final Procedure procedure = aopItemInfo.aopMember;
      if (procedure.isStatic) {
        callExpression = StaticInvocation(aopItemInfo.aopMember, redirectArguments);
      } else {
        final Class aopItemMemberCls = aopItemInfo.aopMember.parent;
        final ConstructorInvocation redirectConstructorInvocation = ConstructorInvocation.byReference(aopItemMemberCls.constructors.first.reference, Arguments(<Expression>[]));
        callExpression = MethodInvocation(redirectConstructorInvocation, aopItemInfo.aopMember.name, redirectArguments);
      }
    }
    return AopUtils.createProcedureBodyWithExpression(callExpression, shouldReturn);
  }
}