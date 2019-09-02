import 'package:kernel/ast.dart';
import 'package:aspectd/src/plugins/aop/aop_transformer_wrapper.dart';

class TransformerWrapper{
  Component platformStrongComponent;
  TransformerWrapper(this.platformStrongComponent);
  bool transform(Component component){
    AopWrapperTransformer aopWrapperTransformer = new AopWrapperTransformer(platformStrongComponent: this.platformStrongComponent);
    aopWrapperTransformer.transform(component);
    
    return true;
  }
}