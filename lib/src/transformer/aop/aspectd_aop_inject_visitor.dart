import 'dart:async';
import 'dart:io' hide FileSystemEntity;

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

/// A [RecursiveVisitor] that replaces [Object.toString] overrides with
/// `super.toString()`.
class AspectdAopInjectVisitor extends RecursiveVisitor<void> {
  /// The [packageUris] must not be null.
  AspectdAopInjectVisitor(/*this._packageUris) : assert(_packageUris != null*/);

  // /// A set of package URIs to apply this transformer to, e.g. 'dart:ui' and
  // /// 'package:flutter/foundation.dart'.
  // final Set<String> _packageUris;
  //
  // /// Turn 'dart:ui' into 'dart:ui', or
  // /// 'package:flutter/src/semantics_event.dart' into 'package:flutter'.
  // String _importUriToPackage(Uri importUri) => '${importUri.scheme}:${importUri.pathSegments.first}';
  //
  // bool _isInTargetPackage(Procedure node) {
  //   return _packageUris.contains(_importUriToPackage(node.enclosingLibrary.importUri));
  // }
  //
  // bool _hasKeepAnnotation(Procedure node) {
  //   for (ConstantExpression expression in node.annotations.whereType<ConstantExpression>()) {
  //     if (expression.constant is! InstanceConstant) {
  //       continue;
  //     }
  //     final InstanceConstant constant = expression.constant as InstanceConstant;
  //     if (constant.classNode.name == '_KeepToString' && constant.classNode.enclosingLibrary.importUri.toString() == 'dart:ui') {
  //       return true;
  //     }
  //   }
  //   return false;
  // }

  @override
  void visitProcedure(Procedure node) {
    print('KKKK: Inject');
    // if (
    // node.name.name        == 'toString' &&
    //     node.enclosingClass   != null       &&
    //     node.enclosingLibrary != null       &&
    //     !node.isStatic                      &&
    //     !node.isAbstract                    &&
    //     !node.enclosingClass.isEnum         &&
    //     _isInTargetPackage(node)            &&
    //     !_hasKeepAnnotation(node)
    // ) {
    //   node.function.body.replaceWith(
    //     ReturnStatement(
    //       SuperMethodInvocation(
    //         node.name,
    //         Arguments(<Expression>[]),
    //       ),
    //     ),
    //   );
    // }
  }

  @override
  void defaultMember(Member node) {}
}