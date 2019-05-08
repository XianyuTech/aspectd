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

class AspectdInjectImplTransformer extends Transformer{
  Map<String,AspectdItemInfo> _aspectdInfoMap;
  Map<String,Library> _libraryMap;
  Map<Uri, Source> _uriToSource;
  Set<VariableDeclaration> _mockedVariableDeclaration = Set();
  Map<String, VariableDeclaration> _originalVariableDeclaration = {};
  Class _curClass;
  Node _curMethodNode;
  Library _curAspectdLibrary;
  AspectdStatementsInsertInfo _curAspectdStatementsInsertInfo;

  AspectdInjectImplTransformer(this._aspectdInfoMap, this._libraryMap,this._uriToSource);

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
    if(_curAspectdLibrary != null) {
      if(interfaceTargetNode is Field) {
        if(interfaceTargetNode.fileUri == _curAspectdLibrary.fileUri) {
          List<String> keypaths = AspectdUtils.getPropertyKeyPaths(node.toString());
          String firstEle = keypaths[0];
          if(firstEle == 'this') {
            Class cls = AspectdUtils.findClassFromThisWithKeypath(_curClass,keypaths);
            Field field = AspectdUtils.findFieldForClassWithName(cls, node.name.name);
            return PropertyGet(node.receiver, field.name);
          } else {
            VariableDeclaration variableDeclaration = _originalVariableDeclaration[firstEle];
            if(variableDeclaration.type is InterfaceType) {
              InterfaceType interfaceType = variableDeclaration.type;
              Class cls = AspectdUtils.findClassFromThisWithKeypath(interfaceType.classNode,keypaths);
              Field field = AspectdUtils.findFieldForClassWithName(cls, node.name.name);
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
    if(_curAspectdStatementsInsertInfo != null) {
      Library library = _curAspectdStatementsInsertInfo.library;
      Source source = _curAspectdStatementsInsertInfo.source;
      AspectdItemInfo aspectdItemInfo = _curAspectdStatementsInsertInfo.aspectdItemInfo;
      List<Statement> aspectdInsertStatements = _curAspectdStatementsInsertInfo.aspectdInsertStatements;
      insertStatementsToBody(library,source,node,aspectdItemInfo,aspectdInsertStatements);
    }
    return node;
  }

  void aspectdTransform() {
    _aspectdInfoMap?.forEach((String uniqueKey, AspectdItemInfo aspectdItemInfo){
      Library aspectdAnnoLibrary = _libraryMap[aspectdItemInfo.importUri];
      String clsName = aspectdItemInfo.clsName;
      if (aspectdAnnoLibrary == null) {
        return;
      }
      //类静态/实例方法
      if (clsName != null && clsName.length>0) {
        Class expectedCls = null;
        for(Class cls in aspectdAnnoLibrary.classes) {
          if(cls.name == aspectdItemInfo.clsName) {
            expectedCls = cls;
            //Check Constructors
            if(aspectdItemInfo.methodName == aspectdItemInfo.clsName || aspectdItemInfo.methodName.startsWith(aspectdItemInfo.clsName+'.')) {
              for(Constructor constructor in cls.constructors) {
                if(cls.name+(constructor.name.name==''?'':'.'+constructor.name.name) == aspectdItemInfo.methodName && true == aspectdItemInfo.isStatic) {
                  _curClass = expectedCls;
                  transformConstructor(aspectdAnnoLibrary,_uriToSource[aspectdAnnoLibrary.fileUri], constructor, aspectdItemInfo);
                  return;
                }
              }
            }
            //Check Procedures
              for(Procedure procedure in cls.procedures) {
                if(procedure.name.name == aspectdItemInfo.methodName && procedure.isStatic == aspectdItemInfo.isStatic) {
                  _curClass = expectedCls;
                  transformMethodProcedure(aspectdAnnoLibrary,_uriToSource[aspectdAnnoLibrary.fileUri], procedure, aspectdItemInfo);
                  return;
                }
            }
            break;
          }
        }
        _libraryMap.forEach((importUri,lib){
          for(Class cls in lib.classes) {
            if(cls.name == aspectdItemInfo.clsName) {
              for(Procedure procedure in cls.procedures) {
                if(procedure.name.name == aspectdItemInfo.methodName && procedure.isStatic == aspectdItemInfo.isStatic) {
                  _curClass = cls;
                  transformMethodProcedure(lib, _uriToSource[aspectdAnnoLibrary.fileUri], procedure, aspectdItemInfo);
                }
              }
            }
          }
        });
      } else {
        for(Procedure procedure in aspectdAnnoLibrary.procedures) {
          if(procedure.name.name == aspectdItemInfo.methodName && procedure.isStatic == aspectdItemInfo.isStatic) {
            transformMethodProcedure(aspectdAnnoLibrary, _uriToSource[aspectdAnnoLibrary.fileUri], procedure, aspectdItemInfo);
          }
        }
      }
    });
  }

  void transformMethodProcedure(Library library, Source source, Procedure procedure, AspectdItemInfo aspectdItemInfo) {
    List<Statement> aspectdInsertStatements = onPrepareTransform(library, procedure,aspectdItemInfo);
    if(procedure.function.body is Block) {
      _curMethodNode = procedure;
      insertStatementsToBody(library, source, procedure.function, aspectdItemInfo, aspectdInsertStatements);
    }
    onPostTransform(aspectdItemInfo);
  }

  void transformConstructor(Library library, Source source, Constructor constructor, AspectdItemInfo aspectdItemInfo) {
    List<Statement> aspectdInsertStatements = onPrepareTransform(library, constructor,aspectdItemInfo);

    Statement body = constructor.function.body;
    bool canBeInitializers = true;
    aspectdInsertStatements.forEach((statement){
      if(!(statement is AssertStatement))
        canBeInitializers = false;
    });
    //Insert in body part
    if(!canBeInitializers ||
        ((body is Block) && body.statements.length>0 && aspectdItemInfo.lineNum>=AspectdUtils.getLineStartNumForStatement(source, body.statements.first))||
        (constructor.initializers.length>0 && aspectdItemInfo.lineNum>AspectdUtils.getLineStartNumForInitializer(source, constructor.initializers.last))) {
      _curMethodNode = constructor;
      insertStatementsToBody(library, source, constructor.function, aspectdItemInfo,aspectdInsertStatements);
    }
    //Insert in Initializers
    else {
      int len = constructor.initializers.length;
      for (int i = 0; i < len; i++) {
        Initializer initializer = constructor.initializers[i];
        int lineStart = AspectdUtils.getLineStartNumForInitializer(source, initializer);
        if(lineStart == -1)
          continue;
        int lineEnds = -1;
        if (i == len - 1) {
          lineEnds = AspectdUtils.getLineNumBySourceAndOffset(
              source, constructor.function.fileEndOffset) - 1;
        } else {
          lineEnds = AspectdUtils.getLineStartNumForInitializer(source, constructor.initializers[i + 1]) - 1;
        }
        int lineNum2Insert = aspectdItemInfo.lineNum;
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
            for(Statement statement in aspectdInsertStatements) {
              if(statement is AssertStatement)
                tmpInitializers.add(AssertInitializer(statement));
            }
            constructor.initializers.insertAll(statement2InsertPos, tmpInitializers);
          }
        }
      }
    }
    visitConstructor(constructor);
    onPostTransform(aspectdItemInfo);
  }

  List<Statement> onPrepareTransform(Library library,Node methodNode,AspectdItemInfo aspectdItemInfo) {
    Block block2Insert = aspectdItemInfo.aspectdProcedure.function.body as Block;
    Library aspectdLibrary = aspectdItemInfo.aspectdProcedure?.parent?.parent;
    List<Statement> tmpStatements = [];
    for(Statement statement in block2Insert.statements) {
      VariableDeclaration variableDeclaration = AspectdUtils.checkIfSkipableVarDeclaration(_uriToSource[aspectdLibrary.fileUri], statement);
      if(variableDeclaration != null) {
        _mockedVariableDeclaration.add(variableDeclaration);
      } else {
        tmpStatements.add(statement);
      }
    }
    for(LibraryDependency libraryDependency in aspectdLibrary.dependencies) {
      AspectdUtils.insertLibraryDependency(library, libraryDependency.importedLibraryReference.node);
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

  void onPostTransform(AspectdItemInfo aspectdItemInfo) {
    Block block2Insert = aspectdItemInfo.aspectdProcedure.function.body as Block;
    block2Insert.statements.clear();
    _mockedVariableDeclaration.clear();
    _originalVariableDeclaration.clear();
    _curAspectdLibrary = null;
  }

  void checkIfInsertInFunction(FunctionNode functionNode) {
    if(_curAspectdStatementsInsertInfo != null) {
      int lineFrom = AspectdUtils.getLineNumBySourceAndOffset(_curAspectdStatementsInsertInfo.source,functionNode.fileOffset);
      int lineTo = AspectdUtils.getLineNumBySourceAndOffset(_curAspectdStatementsInsertInfo.source,functionNode.fileEndOffset);
      int expectedLineNum = _curAspectdStatementsInsertInfo.aspectdItemInfo.lineNum;
      if(expectedLineNum>=lineFrom && expectedLineNum<=lineTo) {
        Library library = _curAspectdStatementsInsertInfo.library;
        Source source = _curAspectdStatementsInsertInfo.source;
        AspectdItemInfo aspectdItemInfo = _curAspectdStatementsInsertInfo.aspectdItemInfo;
        List<Statement> aspectdInsertStatements = _curAspectdStatementsInsertInfo.aspectdInsertStatements;
        _curAspectdStatementsInsertInfo = null;
        functionNode.body = insertStatementsToBody(library,source,functionNode,aspectdItemInfo,aspectdInsertStatements);
      }
    }
  }

  Statement insertStatementsToBody(Library library, Source source, Node node, AspectdItemInfo aspectdItemInfo,List<Statement> aspectdInsertStatements) {
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
        Node nodeToVisitRecursively = AspectdUtils.getNodeToVisitRecursively(statement);
        int lineStart = AspectdUtils.getLineStartNumForStatement(source, statement);
        int lineEnds = -1;
        int lineNum2Insert = aspectdItemInfo.lineNum;
        int statement2InsertPos = -1;
        if(i != len-1) {
          lineEnds = AspectdUtils.getLineStartNumForStatement(source, statements[i+1])-1;
        }
        if(lineStart < 0 || lineEnds <0) {
          if(node is FunctionNode) {
            if(lineStart <0) {
              lineStart = AspectdUtils.getLineNumBySourceAndOffset(
                  source, node.fileOffset);
            }
            if(lineEnds <0 && !AspectdUtils.isAsyncFunctionNode(node)) {
              lineEnds = AspectdUtils.getLineNumBySourceAndOffset(source, node.fileEndOffset)-1;
            }
          } else if(node is Block) {
            if(_curMethodNode is Procedure) {
              Procedure procedure = _curMethodNode;
              if(AspectdUtils.isAsyncFunctionNode(procedure.function)
                  && procedure == body?.parent?.parent?.parent?.parent?.parent?.parent?.parent?.parent) {
                if(lineEnds < 0 && i == len-1) {
                  lineEnds = lineNum2Insert;
                }
              } else {
                if(node.parent is FunctionNode) {
                  FunctionNode functionNode = node.parent;
                  if(lineStart<0)
                    lineStart = AspectdUtils.getLineNumBySourceAndOffset(source, functionNode.fileOffset);
                  if(lineEnds<0)
                    lineEnds = AspectdUtils.getLineNumBySourceAndOffset(source, functionNode.fileEndOffset);
                }
              }
            }
          }
        }

        if((lineNum2Insert>=lineStart && lineNum2Insert<lineEnds) || lineEnds<lineStart || lineStart == -1 || lineEnds == -1) {
          if(nodeToVisitRecursively != null) {
            _curAspectdStatementsInsertInfo = AspectdStatementsInsertInfo(library: library, source: source,constructor: null,procedure: null,node: nodeToVisitRecursively,aspectdItemInfo: aspectdItemInfo,aspectdInsertStatements: aspectdInsertStatements);
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
          _curAspectdStatementsInsertInfo = null;
          statements.insertAll(statement2InsertPos, aspectdInsertStatements);
          _curAspectdLibrary = aspectdItemInfo.aspectdProcedure?.parent?.parent;
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