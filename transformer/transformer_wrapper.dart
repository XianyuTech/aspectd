import 'package:kernel/ast.dart';
import 'plugins/aop/aop_transformer_wrapper.dart';
import 'plugins/pluginDemo/pluginDemo_transformer_wrapper.dart';

class TransformerWrapper{
  TransformerWrapper(this.platformStrongComponent);

  Component platformStrongComponent;
  
  bool transform(Component component) {
    final AopWrapperTransformer aopWrapperTransformer = AopWrapperTransformer(platformStrongComponent: platformStrongComponent);
    aopWrapperTransformer.transform(component);

    final PluginDemoWrapperTransformer pluginDemoWrapperTransformer = PluginDemoWrapperTransformer(platformStrongComponent: platformStrongComponent);
    pluginDemoWrapperTransformer.transform(component);

    return true;
  }
}