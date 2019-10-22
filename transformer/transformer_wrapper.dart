import 'package:kernel/ast.dart';
import 'plugins/aop/aop_transformer_wrapper.dart';
import 'plugins/pluginDemo/pluginDemo_transformer_wrapper.dart';

class TransformerWrapper{
  Component platformStrongComponent;
  
  TransformerWrapper(this.platformStrongComponent);
  
  bool transform(Component component) {
    AopWrapperTransformer aopWrapperTransformer = AopWrapperTransformer(platformStrongComponent: this.platformStrongComponent);
    aopWrapperTransformer.transform(component);

    PluginDemoWrapperTransformer pluginDemoWrapperTransformer = PluginDemoWrapperTransformer(platformStrongComponent: this.platformStrongComponent);
    pluginDemoWrapperTransformer.transform(component);

    return true;
  }
}