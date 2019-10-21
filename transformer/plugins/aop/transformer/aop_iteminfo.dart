import 'package:kernel/ast.dart';

import 'aop_mode.dart';
import 'aop_utils.dart';

class AopItemInfo {
  final AopMode mode;
  final String importUri;
  final String clsName;
  final String methodName;
  final bool isStatic;
  final bool isRegex;
  final Member aopMember;
  final int lineNum;
  String stubKey;
  static String uniqueKeyForMethod(String importUri, String clsName, String methodName, bool isStatic, int lineNum) {
    return (importUri??"")+AopUtils.kAopUniqueKeySeperator
        +(clsName??"")+AopUtils.kAopUniqueKeySeperator
        +(methodName??"")+AopUtils.kAopUniqueKeySeperator
        +(isStatic==true?"+":"-")
        +(lineNum!=null?(AopUtils.kAopUniqueKeySeperator+"$lineNum"):"");
  }
  AopItemInfo({this.mode,this.importUri,this.clsName,this.methodName,this.isStatic,this.aopMember,this.isRegex,this.lineNum});
}