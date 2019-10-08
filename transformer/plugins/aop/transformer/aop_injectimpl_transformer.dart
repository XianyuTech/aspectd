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

class AopInjectImplTransformer extends Transformer{
  Map<String,AopItemInfo> _aopInfoMap;
  Map<String,Library> _libraryMap;
  Map<Uri, Source> _uriToSource;
  Set<VariableDeclaration> _mockedVariableDeclaration = Set();
  Map<String, VariableDeclaration> _originalVariableDeclaration = {};
  Class _curClass;
  Node _curMethodNode;
  Library _curAopLibrary;
  AopStatementsInsertInfo _curAopStatementsInsertInfo;

  AopInjectImplTransformer(this._aopInfoMap, this._libraryMap,this._uriToSource);

  @override
  VariableDeclaration visitVariableDeclaration(VariableDeclaration node){
    node.transformChildren(this);
    _originalVariableDeclaration.putIfAbsent(node.name, ()=>node);
    return node;
  }

  @override
  VariableGet visitVariableGet(VariableGet node){
    node.transformChildren(this);
    if(_mockedVariableDeclaration.contains(node.variable)) {
      VariableGet variableGet = VariableGet(_originalVariableDeclaration[node.variable.name]);
      return variableGet;
    }
    return node;
  }

  @override
  PropertyGet visitPropertyGet(PropertyGet node){
    node.transformChildren(this);
    Node interfaceTargetNode = node.interfaceTargetReference.node;
    if(_curAopLibrary != null) {
      if(interfaceTargetNode is Field) {
        if(interfaceTargetNode.fileUri == _curAopLibrary.fileUri) {
          List<String> keypaths = AopUtils.getPropertyKeyPaths(node.toString());
          String firstEle = keypaths[0];
          if(firstEle == 'this') {
            Class cls = AopUtils.findClassFromThisWithKeypath(_curClass,keypaths);
            Field field = AopUtils.findFieldForClassWithName(cls, node.name.name);
            return PropertyGet(node.receiver, field.name);
          } else {
            VariableDeclaration variableDeclaration = _originalVariableDeclaration[firstEle];
            if(variableDeclaration.type is InterfaceType) {
              InterfaceType interfaceType = variableDeclaration.type;
              Class cls = AopUtils.findClassFromThisWithKeypath(interfaceType.classNode,keypaths);
              Field field = AopUtils.findFieldForClassWithName(cls, node.name.name);
              return PropertyGet(node.receiver, field.name);
            }
          }
        }
      }
    }
    return node;
  }

  @override
  FunctionExpression visitFunctionExpression(FunctionExpression node){
    node.transformChildren(this);
    checkIfInsertInFunction(node.function);
    return node;
  }

  @override
  FunctionDeclaration visitFunctionDeclaration(FunctionDeclaration node){
    node.transformChildren(this);
    checkIfInsertInFunction(node.function);
    return node;
  }

  @override
  FunctionNode visitFunctionNode(FunctionNode node){
    node.transformChildren(this);
    checkIfInsertInFunction(node);
    return node;
  }

  @override
  Block visitBlock(Block node){
    node.transformChildren(this);
    if(_curAopStatementsInsertInfo != null) {
      Library library = _curAopStatementsInsertInfo.library;
      Source source = _curAopStatementsInsertInfo.source;
      AopItemInfo aopItemInfo = _curAopStatementsInsertInfo.aopItemInfo;
      List<Statement> aopInsertStatements = _curAopStatementsInsertInfo.aopInsertStatements;
      insertStatementsToBody(library,source,node, aopItemInfo, aopInsertStatements);
    }
    return node;
  }

  void aopTransform() {
    _aopInfoMap?.forEach((String uniqueKey, AopItemInfo aopItemInfo){
      Library aopAnnoLibrary = _libraryMap[aopItemInfo.importUri];
      String clsName = aopItemInfo.clsName;
      if (aopAnnoLibrary == null) {
        return;
      }
      //类静态/实例方法
      if (clsName != null && clsName.length>0) {
        Class expectedCls = null;
        for(Class cls in aopAnnoLibrary.classes) {
          if(cls.name == aopItemInfo.clsName) {
            expectedCls = cls;
            //Check Constructors
            if(aopItemInfo.methodName == aopItemInfo.clsName || aopItemInfo.methodName.startsWith(aopItemInfo.clsName+'.')) {
              for(Constructor constructor in cls.constructors) {
                if(cls.name+(constructor.name.name==''?'':'.'+constructor.name.name) == aopItemInfo.methodName && true == aopItemInfo.isStatic) {
                  _curClass = expectedCls;
                  transformConstructor(aopAnnoLibrary,_uriToSource[aopAnnoLibrary.fileUri], constructor, aopItemInfo);
                  return;
                }
              }
            }
            //Check Procedures
              for(Procedure procedure in cls.procedures) {
                if(procedure.name.name == aopItemInfo.methodName && procedure.isStatic == aopItemInfo.isStatic) {
                  _curClass = expectedCls;
                  transformMethodProcedure(aopAnnoLibrary,_uriToSource[aopAnnoLibrary.fileUri], procedure, aopItemInfo);
                  return;
                }
            }
            break;
          }
        }
        _libraryMap.forEach((importUri,lib){
          for(Class cls in lib.classes) {
            if(cls.name == aopItemInfo.clsName) {
              for(Procedure procedure in cls.procedures) {
                if(procedure.name.name == aopItemInfo.methodName && procedure.isStatic == aopItemInfo.isStatic) {
                  _curClass = cls;
                  transformMethodProcedure(lib, _uriToSource[aopAnnoLibrary.fileUri], procedure, aopItemInfo);
                }
              }
            }
          }
        });
      } else {
        for(Procedure procedure in aopAnnoLibrary.procedures) {
          if(procedure.name.name == aopItemInfo.methodName && procedure.isStatic == aopItemInfo.isStatic) {
            transformMethodProcedure(aopAnnoLibrary, _uriToSource[aopAnnoLibrary.fileUri], procedure, aopItemInfo);
          }
        }
      }
    });
  }

  void transformMethodProcedure(Library library, Source source, Procedure procedure, AopItemInfo aopItemInfo) {
    List<Statement> aopInsertStatements = onPrepareTransform(library, procedure,aopItemInfo);
    if(procedure.function.body is Block) {
      _curMethodNode = procedure;
      insertStatementsToBody(library, source, procedure.function, aopItemInfo, aopInsertStatements);
    }
    onPostTransform(aopItemInfo);
  }

  void transformConstructor(Library library, Source source, Constructor constructor, AopItemInfo aopItemInfo) {
    List<Statement> aopInsertStatements = onPrepareTransform(library, constructor,aopItemInfo);

    Statement body = constructor.function.body;
    bool canBeInitializers = true;
    aopInsertStatements.forEach((statement){
      if(!(statement is AssertStatement))
        canBeInitializers = false;
    });
    //Insert in body part
    if(!canBeInitializers ||
        ((body is Block) && body.statements.length>0 && aopItemInfo.lineNum>=AopUtils.getLineStartNumForStatement(source, body.statements.first))||
        (constructor.initializers.length>0 && aopItemInfo.lineNum>AopUtils.getLineStartNumForInitializer(source, constructor.initializers.last))) {
      _curMethodNode = constructor;
      insertStatementsToBody(library, source, constructor.function, aopItemInfo, aopInsertStatements);
    }
    //Insert in Initializers
    else {
      int len = constructor.initializers.length;
      for (int i = 0; i < len; i++) {
        Initializer initializer = constructor.initializers[i];
        int lineStart = AopUtils.getLineStartNumForInitializer(source, initializer);
        if(lineStart == -1)
          continue;
        int lineEnds = -1;
        if (i == len - 1) {
          lineEnds = AopUtils.getLineNumBySourceAndOffset(
              source, constructor.function.fileEndOffset) - 1;
        } else {
          lineEnds = AopUtils.getLineStartNumForInitializer(source, constructor.initializers[i + 1]) - 1;
        }
        int lineNum2Insert = aopItemInfo.lineNum;
        if(lineNum2Insert>lineStart && lineNum2Insert<=lineEnds) {
          assert(false);
          break;
        } else {
          int statement2InsertPos = -1;
          if(lineNum2Insert<=lineStart) {
            statement2InsertPos = i;
          } else if(lineNum2Insert>lineEnds && i==len-1) {
            statement2InsertPos = len;
          }
          if(statement2InsertPos != -1) {
            List<Initializer> tmpInitializers = [];
            for(Statement statement in aopInsertStatements) {
              if(statement is AssertStatement)
                tmpInitializers.add(AssertInitializer(statement));
            }
            constructor.initializers.insertAll(statement2InsertPos, tmpInitializers);
          }
        }
      }
    }
    visitConstructor(constructor);
    onPostTransform(aopItemInfo);
  }

  List<Statement> onPrepareTransform(Library library,Node methodNode,AopItemInfo aopItemInfo) {
    Block block2Insert = aopItemInfo.aopMember.function.body as Block;
    Library aopLibrary = aopItemInfo.aopMember?.parent?.parent;
    List<Statement> tmpStatements = [];
    for(Statement statement in block2Insert.statements) {
      VariableDeclaration variableDeclaration = AopUtils.checkIfSkipableVarDeclaration(_uriToSource[aopLibrary.fileUri], statement);
      if(variableDeclaration != null) {
        _mockedVariableDeclaration.add(variableDeclaration);
      } else {
        tmpStatements.add(statement);
      }
    }
    for(LibraryDependency libraryDependency in aopLibrary.dependencies) {
      AopUtils.insertLibraryDependency(library, libraryDependency.importedLibraryReference.node);
    }
    if(methodNode is Procedure) {
      for(VariableDeclaration variableDeclaration in methodNode.function.namedParameters) {
        _originalVariableDeclaration.putIfAbsent(variableDeclaration.name, ()=>variableDeclaration);
      }
      for(VariableDeclaration variableDeclaration in methodNode.function.positionalParameters) {
        _originalVariableDeclaration.putIfAbsent(variableDeclaration.name, ()=>variableDeclaration);
      }
    } else if(methodNode is Constructor) {
      for(VariableDeclaration variableDeclaration in methodNode.function.namedParameters) {
        _originalVariableDeclaration.putIfAbsent(variableDeclaration.name, ()=>variableDeclaration);
      }
      for(VariableDeclaration variableDeclaration in methodNode.function.positionalParameters) {
        _originalVariableDeclaration.putIfAbsent(variableDeclaration.name, ()=>variableDeclaration);
      }
    }
    return tmpStatements;
  }

  void onPostTransform(AopItemInfo aopItemInfo) {
    Block block2Insert = aopItemInfo.aopMember.function.body as Block;
    block2Insert.statements.clear();
    _mockedVariableDeclaration.clear();
    _originalVariableDeclaration.clear();
    _curAopLibrary = null;
  }

  void checkIfInsertInFunction(FunctionNode functionNode) {
    if(_curAopStatementsInsertInfo != null) {
      int lineFrom = AopUtils.getLineNumBySourceAndOffset(_curAopStatementsInsertInfo.source,functionNode.fileOffset);
      int lineTo = AopUtils.getLineNumBySourceAndOffset(_curAopStatementsInsertInfo.source,functionNode.fileEndOffset);
      int expectedLineNum = _curAopStatementsInsertInfo.aopItemInfo.lineNum;
      if(expectedLineNum>=lineFrom && expectedLineNum<=lineTo) {
        Library library = _curAopStatementsInsertInfo.library;
        Source source = _curAopStatementsInsertInfo.source;
        AopItemInfo aopItemInfo = _curAopStatementsInsertInfo.aopItemInfo;
        List<Statement> aopInsertStatements = _curAopStatementsInsertInfo.aopInsertStatements;
        _curAopStatementsInsertInfo = null;
        functionNode.body = insertStatementsToBody(library,source,functionNode,aopItemInfo, aopInsertStatements);
      }
    }
  }

  Statement insertStatementsToBody(Library library, Source source, Node node, AopItemInfo aopItemInfo,List<Statement> aopInsertStatements) {
    Statement body = null;
    if(node is FunctionNode) {
      body = node.body;
      if(body is EmptyStatement) {
        List<Statement> statements = [body];
        body = Block(statements);
        node.body = body;
      }
    } else if(node is Block) {
      body = node;
    }
    if(body is TryCatch && body.fileOffset == -1) {
      body = (body as TryCatch).body;
    }
    if(body is Block) {
      List<Statement> statements = body.statements;
      int len = statements.length;
      for(int i=0;i<len;i++){
        Statement statement = statements[i];
        Node nodeToVisitRecursively = AopUtils.getNodeToVisitRecursively(statement);
        int lineStart = AopUtils.getLineStartNumForStatement(source, statement);
        int lineEnds = -1;
        int lineNum2Insert = aopItemInfo.lineNum;
        int statement2InsertPos = -1;
        if(i != len-1) {
          lineEnds = AopUtils.getLineStartNumForStatement(source, statements[i+1])-1;
        }
        if(lineStart < 0 || lineEnds <0) {
          if(node is FunctionNode) {
            if(lineStart <0) {
              lineStart = AopUtils.getLineNumBySourceAndOffset(
                  source, node.fileOffset);
            }
            if(lineEnds <0 && !AopUtils.isAsyncFunctionNode(node)) {
              lineEnds = AopUtils.getLineNumBySourceAndOffset(source, node.fileEndOffset)-1;
            }
          } else if(node is Block) {
            if(_curMethodNode is Procedure) {
              Procedure procedure = _curMethodNode;
              if(AopUtils.isAsyncFunctionNode(procedure.function)
                  && procedure == body?.parent?.parent?.parent?.parent?.parent?.parent?.parent?.parent) {
                if(lineEnds < 0 && i == len-1) {
                  lineEnds = lineNum2Insert;
                }
              } else {
                if(node.parent is FunctionNode) {
                  FunctionNode functionNode = node.parent;
                  if(lineStart<0)
                    lineStart = AopUtils.getLineNumBySourceAndOffset(source, functionNode.fileOffset);
                  if(lineEnds<0)
                    lineEnds = AopUtils.getLineNumBySourceAndOffset(source, functionNode.fileEndOffset);
                }
              }
            }
          }
        }

        if((lineNum2Insert>=lineStart && lineNum2Insert<lineEnds) || lineEnds<lineStart || lineStart == -1 || lineEnds == -1) {
          if(nodeToVisitRecursively != null) {
            _curAopStatementsInsertInfo = AopStatementsInsertInfo(library: library, source: source,constructor: null,procedure: null,node: nodeToVisitRecursively, aopItemInfo: aopItemInfo, aopInsertStatements: aopInsertStatements);
            visitNode(nodeToVisitRecursively);
          }
          continue;
        }
        if(lineNum2Insert==lineStart) {
          statement2InsertPos = i;
        } else if(lineNum2Insert>=lineEnds && i==len-1) {
          statement2InsertPos = len;
        }
        if(statement2InsertPos != -1) {
          _curAopStatementsInsertInfo = null;
          statements.insertAll(statement2InsertPos, aopInsertStatements);
          _curAopLibrary = aopItemInfo.aopMember?.parent?.parent;
          visitNode(node);
          break;
        }
      }
    } else {
      assert(false);
    }
    return body;
  }

  void visitNode(Object node) {
    if(node is Constructor) {
      visitConstructor(node);
    } else if(node is Procedure) {
      visitProcedure(node);
    } else if(node is LabeledStatement) {
      visitLabeledStatement(node);
    } else if(node is FunctionNode) {
      visitFunctionNode(node);
    } else if(node is Block) {
      visitBlock(node);
    }
  }
}