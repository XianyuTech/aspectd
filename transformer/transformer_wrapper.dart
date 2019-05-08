import 'package:kernel/ast.dart';
import 'aspectd_wrapper_transformer.dart';

class TransformerWrapper{
  Component platformStrongComponent;
  TransformerWrapper(this.platformStrongComponent);
  bool transform(Component component){
    AspectdWrapperTransformer transformer = new AspectdWrapperTransformer(platformStrongComponent: this.platformStrongComponent);
    transformer.transform(component);
    return true;
  }
}