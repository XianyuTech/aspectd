import 'package:kernel/ast.dart';

import 'aop_mode.dart';
import 'aop_utils.dart';

class AopItemInfo {
  AopItemInfo(
      { required this.mode,
        required this.importUri,
        required this.clsName,
        required this.methodName,
        required this.isStatic,
        required this.aopMember,
        required this.isRegex,
        required this.lineNum});

  final AopMode mode;
  final String importUri;
  final String clsName;
  final String methodName;
  final bool isStatic;
  final bool isRegex;
  final Member aopMember;
  final int lineNum;
  static String uniqueKeyForMethod(
      String importUri, String clsName, String methodName, bool isStatic,
      { required int lineNum}) {
    return (importUri ?? '') +
        AopUtils.kAopUniqueKeySeperator +
        (clsName ?? '') +
        AopUtils.kAopUniqueKeySeperator +
        (methodName ?? '') +
        AopUtils.kAopUniqueKeySeperator +
        (isStatic == true ? '+' : '-') +
        (lineNum != null ? (AopUtils.kAopUniqueKeySeperator + '$lineNum') : '');
  }
}
