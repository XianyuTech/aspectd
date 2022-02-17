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

class AopStatementsInsertInfo {
  AopStatementsInsertInfo(
      {this.library,
      this.source,
      this.constructor,
      this.procedure,
      this.node,
      this.aopItemInfo,
      this.aopInsertStatements});

  final Library library;
  final Source source;
  final Constructor constructor;
  final Procedure procedure;
  final Node node;
  final AopItemInfo aopItemInfo;
  final List<Statement> aopInsertStatements;
}

class AspectdAopInjectVisitor extends RecursiveVisitor<void> {
  /// The [packageUris] must not be null.
  AspectdAopInjectVisitor(this._aopItemInfoList, this._uriToSource);

  final List<AopItemInfo> _aopItemInfoList;
  final Map<Uri, Source> _uriToSource;
  final Set<VariableDeclaration> _mockedVariableDeclaration =
      <VariableDeclaration>{};
  final Map<String, VariableDeclaration> _originalVariableDeclaration =
      <String, VariableDeclaration>{};
  final Set<Member> _manipulatedMemberSet = {};
  Class _curClass;
  Node _curMethodNode;
  Library _curAopLibrary;
  AopStatementsInsertInfo _curAopStatementsInsertInfo;

  @override
  void visitLibrary(Library library) {
    final String importUri = library.importUri.toString();
    bool matches = false;
    final int aopItemInfoListLen = _aopItemInfoList.length;
    for (int i = 0; i < aopItemInfoListLen && !matches; i++) {
      final AopItemInfo aopItemInfo = _aopItemInfoList[i];
      if (!aopItemInfo.isRegex && importUri == aopItemInfo.importUri) {
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
    final String clsName = cls.name;
    bool matches = false;
    final int aopItemInfoListLen = _aopItemInfoList.length;
    for (int i = 0; i < aopItemInfoListLen && !matches; i++) {
      final AopItemInfo aopItemInfo = _aopItemInfoList[i];
      if (!aopItemInfo.isRegex && clsName == aopItemInfo.clsName) {
        matches = true;
        break;
      }
    }
    if (matches) {
      cls.visitChildren(this);
    }
  }

  @override
  void visitConstructor(Constructor constructor) {
    AopItemInfo matchedAopItemInfo;
    final int aopItemInfoListLen = _aopItemInfoList.length;
    final Class cls = constructor.parent;
    for (int i = 0; i < aopItemInfoListLen && matchedAopItemInfo == null; i++) {
      final AopItemInfo aopItemInfo = _aopItemInfoList[i];
      if (cls.name +
                  (constructor.name.name == ''
                      ? ''
                      : '.' + constructor.name.name) ==
              aopItemInfo.methodName &&
          true == aopItemInfo.isStatic) {
        matchedAopItemInfo = aopItemInfo;
        break;
      }
    }
    if (matchedAopItemInfo == null) {
      return;
    }
    final Library library = constructor.parent.parent;
    if (_manipulatedMemberSet.contains(constructor)) {
      return;
    }
    _manipulatedMemberSet.add(constructor);
    transformConstructor(library, _uriToSource[library.fileUri], constructor,
        matchedAopItemInfo);
    constructor.visitChildren(this);
  }

  @override
  void visitProcedure(Procedure node) {
    final String procedureName = node.name.name;
    AopItemInfo matchedAopItemInfo;
    final int aopItemInfoListLen = _aopItemInfoList.length;
    for (int i = 0; i < aopItemInfoListLen && matchedAopItemInfo == null; i++) {
      final AopItemInfo aopItemInfo = _aopItemInfoList[i];
      if (!aopItemInfo.isRegex &&
          procedureName == aopItemInfo.methodName &&
          aopItemInfo.isStatic == node.isStatic) {
        matchedAopItemInfo = aopItemInfo;
        break;
      }
    }
    if (matchedAopItemInfo == null) {
      return;
    }
    Library library;
    if (node.parent is Library) {
      library = node.parent;
    } else {
      library = node.parent.parent;
    }
    if (_manipulatedMemberSet.contains(node)) {
      return;
    }
    _manipulatedMemberSet.add(node);
    transformMethodProcedure(
        library, _uriToSource[library.fileUri], node, matchedAopItemInfo);
    node.visitChildren(this);
  }

  @override
  VariableDeclaration visitVariableDeclaration(VariableDeclaration node) {
    node.visitChildren(this);
    _originalVariableDeclaration.putIfAbsent(node.name, () => node);
    return node;
  }

  @override
  VariableGet visitVariableGet(VariableGet node) {
    node.visitChildren(this);
    if (_mockedVariableDeclaration.contains(node.variable)) {
      final VariableGet variableGet =
          VariableGet(_originalVariableDeclaration[node.variable.name]);
      return variableGet;
    }
    return node;
  }

  @override
  PropertyGet visitPropertyGet(PropertyGet node) {
    node.visitChildren(this);
    final Node interfaceTargetNode = node.interfaceTargetReference.node;
    if (_curAopLibrary != null) {
      if (interfaceTargetNode is Field) {
        if (interfaceTargetNode.fileUri == _curAopLibrary.fileUri) {
          final List<String> keypaths =
              AopUtils.getPropertyKeyPaths(node.toString());
          final String firstEle = keypaths[0];
          if (firstEle == 'this') {
            final Class cls =
                AopUtils.findClassFromThisWithKeypath(_curClass, keypaths);
            final Field field =
                AopUtils.findFieldForClassWithName(cls, node.name.name);
            return PropertyGet(node.receiver, field.name);
          } else {
            final VariableDeclaration variableDeclaration =
                _originalVariableDeclaration[firstEle];
            if (variableDeclaration.type is InterfaceType) {
              final InterfaceType interfaceType = variableDeclaration.type;
              final Class cls = AopUtils.findClassFromThisWithKeypath(
                  interfaceType.classNode, keypaths);
              final Field field =
                  AopUtils.findFieldForClassWithName(cls, node.name.name);
              return PropertyGet(node.receiver, field.name);
            }
          }
        }
      }
    }
    return node;
  }

  @override
  FunctionExpression visitFunctionExpression(FunctionExpression node) {
    node.visitChildren(this);
    checkIfInsertInFunction(node.function);
    return node;
  }

  @override
  FunctionDeclaration visitFunctionDeclaration(FunctionDeclaration node) {
    node.visitChildren(this);
    checkIfInsertInFunction(node.function);
    return node;
  }

  @override
  FunctionNode visitFunctionNode(FunctionNode node) {
    node.visitChildren(this);
    checkIfInsertInFunction(node);
    return node;
  }

  @override
  Block visitBlock(Block node) {
    node.visitChildren(this);
    final Library library = _curAopStatementsInsertInfo.library;
    final Source source = _curAopStatementsInsertInfo.source;
    final AopItemInfo aopItemInfo = _curAopStatementsInsertInfo.aopItemInfo;
    final List<Statement> aopInsertStatements =
        _curAopStatementsInsertInfo.aopInsertStatements;
    insertStatementsToBody(
        library, source, node, aopItemInfo, aopInsertStatements);
    return node;
  }

  void transformMethodProcedure(Library library, Source source,
      Procedure procedure, AopItemInfo aopItemInfo) {
    final List<Statement> aopInsertStatements =
        onPrepareTransform(library, procedure, aopItemInfo);
    if (procedure.function.body is Block) {
      _curMethodNode = procedure;
      insertStatementsToBody(library, source, procedure.function, aopItemInfo,
          aopInsertStatements);
    }
    onPostTransform(aopItemInfo);
  }

  void transformConstructor(Library library, Source source,
      Constructor constructor, AopItemInfo aopItemInfo) {
    final List<Statement> aopInsertStatements =
        onPrepareTransform(library, constructor, aopItemInfo);

    final Statement body = constructor.function.body;
    bool canBeInitializers = true;
    for (Statement statement in aopInsertStatements) {
      if (!(statement is AssertStatement)) {
        canBeInitializers = false;
      }
    }
    //Insert in body part
    if (!canBeInitializers ||
        ((body is Block) &&
            body.statements.isNotEmpty &&
            aopItemInfo.lineNum >=
                AopUtils.getLineStartNumForStatement(
                    source, body.statements.first)) ||
        (constructor.initializers.isNotEmpty &&
            aopItemInfo.lineNum >
                AopUtils.getLineStartNumForInitializer(
                    source, constructor.initializers.last))) {
      _curMethodNode = constructor;
      insertStatementsToBody(library, source, constructor.function, aopItemInfo,
          aopInsertStatements);
    }
    //Insert in Initializers
    else {
      final int len = constructor.initializers.length;
      for (int i = 0; i < len; i++) {
        final Initializer initializer = constructor.initializers[i];
        final int lineStart =
            AopUtils.getLineStartNumForInitializer(source, initializer);
        if (lineStart == -1) {
          continue;
        }
        int lineEnds = -1;
        if (i == len - 1) {
          lineEnds = AopUtils.getLineNumBySourceAndOffset(
                  source, constructor.function.fileEndOffset) -
              1;
        } else {
          lineEnds = AopUtils.getLineStartNumForInitializer(
                  source, constructor.initializers[i + 1]) -
              1;
        }
        final int lineNum2Insert = aopItemInfo.lineNum;
        if (lineNum2Insert > lineStart && lineNum2Insert <= lineEnds) {
          assert(false);
          break;
        } else {
          int statement2InsertPos = -1;
          if (lineNum2Insert <= lineStart) {
            statement2InsertPos = i;
          } else if (lineNum2Insert > lineEnds && i == len - 1) {
            statement2InsertPos = len;
          }
          if (statement2InsertPos != -1) {
            final List<Initializer> tmpInitializers = <Initializer>[];
            for (Statement statement in aopInsertStatements) {
              if (statement is AssertStatement) {
                tmpInitializers.add(AssertInitializer(statement));
              }
            }
            constructor.initializers
                .insertAll(statement2InsertPos, tmpInitializers);
          }
        }
      }
    }
    visitConstructor(constructor);
    onPostTransform(aopItemInfo);
  }

  List<Statement> onPrepareTransform(
      Library library, Node methodNode, AopItemInfo aopItemInfo) {
    final Block block2Insert = aopItemInfo.aopMember.function.body;
    final Library aopLibrary = aopItemInfo.aopMember?.parent?.parent;
    final List<Statement> tmpStatements = <Statement>[];
    for (Statement statement in block2Insert.statements) {
      final VariableDeclaration variableDeclaration =
          AopUtils.checkIfSkipableVarDeclaration(
              _uriToSource[aopLibrary.fileUri], statement);
      if (variableDeclaration != null) {
        _mockedVariableDeclaration.add(variableDeclaration);
      } else {
        tmpStatements.add(statement);
      }
    }
    for (LibraryDependency libraryDependency in aopLibrary.dependencies) {
      AopUtils.insertLibraryDependency(
          library, libraryDependency.importedLibraryReference.node);
    }
    if (methodNode is Procedure) {
      for (VariableDeclaration variableDeclaration
          in methodNode.function.namedParameters) {
        _originalVariableDeclaration.putIfAbsent(
            variableDeclaration.name, () => variableDeclaration);
      }
      for (VariableDeclaration variableDeclaration
          in methodNode.function.positionalParameters) {
        _originalVariableDeclaration.putIfAbsent(
            variableDeclaration.name, () => variableDeclaration);
      }
    } else if (methodNode is Constructor) {
      for (VariableDeclaration variableDeclaration
          in methodNode.function.namedParameters) {
        _originalVariableDeclaration.putIfAbsent(
            variableDeclaration.name, () => variableDeclaration);
      }
      for (VariableDeclaration variableDeclaration
          in methodNode.function.positionalParameters) {
        _originalVariableDeclaration.putIfAbsent(
            variableDeclaration.name, () => variableDeclaration);
      }
    }
    return tmpStatements;
  }

  void onPostTransform(AopItemInfo aopItemInfo) {
    final Block block2Insert = aopItemInfo.aopMember.function.body;
    block2Insert.statements.clear();
    _mockedVariableDeclaration.clear();
    _originalVariableDeclaration.clear();
    _curAopLibrary = null;
  }

  void checkIfInsertInFunction(FunctionNode functionNode) {
    final int lineFrom = AopUtils.getLineNumBySourceAndOffset(
        _curAopStatementsInsertInfo.source, functionNode.fileOffset);
    final int lineTo = AopUtils.getLineNumBySourceAndOffset(
        _curAopStatementsInsertInfo.source, functionNode.fileEndOffset);
    final int expectedLineNum =
        _curAopStatementsInsertInfo.aopItemInfo.lineNum;
    if (expectedLineNum >= lineFrom && expectedLineNum <= lineTo) {
      final Library library = _curAopStatementsInsertInfo.library;
      final Source source = _curAopStatementsInsertInfo.source;
      final AopItemInfo aopItemInfo = _curAopStatementsInsertInfo.aopItemInfo;
      final List<Statement> aopInsertStatements =
          _curAopStatementsInsertInfo.aopInsertStatements;
      _curAopStatementsInsertInfo = null;
      functionNode.body = insertStatementsToBody(
          library, source, functionNode, aopItemInfo, aopInsertStatements);
    }
  }

  Statement insertStatementsToBody(Library library, Source source, Node node,
      AopItemInfo aopItemInfo, List<Statement> aopInsertStatements) {
    Statement body;
    if (node is FunctionNode) {
      body = node.body;
      if (body is EmptyStatement) {
        final List<Statement> statements = <Statement>[body];
        body = Block(statements);
        node.body = body;
      }
    } else if (node is Block) {
      body = node;
    }
    if (body is TryCatch && body.fileOffset == -1) {
      final TryCatch tryCatch = body;
      body = tryCatch.body;
    }
    if (body is Block) {
      final List<Statement> statements = body.statements;
      final int len = statements.length;
      if (len == 0) {
        body.addStatement(Block(aopInsertStatements));
      } else {
        for (int i = 0; i < len; i++) {
          final Statement statement = statements[i];
          final Node nodeToVisitRecursively =
              AopUtils.getNodeToVisitRecursively(statement);
          int lineStart =
              AopUtils.getLineStartNumForStatement(source, statement);
          int lineEnds = -1;
          final int lineNum2Insert = aopItemInfo.lineNum;
          int statement2InsertPos = -1;
          if (i != len - 1) {
            lineEnds = AopUtils.getLineStartNumForStatement(
                    source, statements[i + 1]) -
                1;
          }
          if (lineStart < 0 || lineEnds < 0) {
            if (node is FunctionNode) {
              if (lineStart < 0) {
                lineStart = AopUtils.getLineNumBySourceAndOffset(
                    source, node.fileOffset);
              }
              if (lineEnds < 0 && !AopUtils.isAsyncFunctionNode(node)) {
                lineEnds = AopUtils.getLineNumBySourceAndOffset(
                        source, node.fileEndOffset) -
                    1;
              }
            } else if (node is Block) {
              if (_curMethodNode is Procedure) {
                final Procedure procedure = _curMethodNode;
                if (AopUtils.isAsyncFunctionNode(procedure.function) &&
                    procedure ==
                        body?.parent?.parent?.parent?.parent?.parent?.parent
                            ?.parent?.parent) {
                  if (lineEnds < 0 && i == len - 1) {
                    lineEnds = lineNum2Insert;
                  }
                } else {
                  if (node.parent is FunctionNode) {
                    final FunctionNode functionNode = node.parent;
                    if (lineStart < 0)
                      lineStart = AopUtils.getLineNumBySourceAndOffset(
                          source, functionNode.fileOffset);
                    if (lineEnds < 0)
                      lineEnds = AopUtils.getLineNumBySourceAndOffset(
                          source, functionNode.fileEndOffset);
                  }
                }
              }
            }
          }

          if ((lineNum2Insert >= lineStart && lineNum2Insert < lineEnds) ||
              (lineEnds < lineStart && lineEnds != -1) ||
              lineStart == -1) {
            if (nodeToVisitRecursively != null) {
              _curAopStatementsInsertInfo = AopStatementsInsertInfo(
                  library: library,
                  source: source,
                  constructor: null,
                  procedure: null,
                  node: nodeToVisitRecursively,
                  aopItemInfo: aopItemInfo,
                  aopInsertStatements: aopInsertStatements);
              visitNode(nodeToVisitRecursively);
            }
            continue;
          }
          if (lineNum2Insert == lineStart - 1 || lineNum2Insert == lineStart) {
            statement2InsertPos = i;
          } else if (lineEnds != -1 && lineNum2Insert == lineEnds + 1) {
            statement2InsertPos = i + 1;
          } else if (lineNum2Insert >= lineEnds && i == len - 1) {
            statement2InsertPos = len;
          }
          if (statement2InsertPos != -1) {
            _curAopStatementsInsertInfo = null;
            statements.insertAll(statement2InsertPos, aopInsertStatements);
            _curAopLibrary = aopItemInfo.aopMember?.parent?.parent;
            visitNode(node);
            break;
          }
        }
      }
    } else {
      assert(false);
    }
    return body;
  }

  void visitNode(Object node) {
    if (node is Constructor) {
      visitConstructor(node);
    } else if (node is Procedure) {
      visitProcedure(node);
    } else if (node is LabeledStatement) {
      visitLabeledStatement(node);
    } else if (node is FunctionNode) {
      visitFunctionNode(node);
    } else if (node is Block) {
      visitBlock(node);
    }
  }
}
