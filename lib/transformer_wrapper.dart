import 'package:kernel/ast.dart';
import 'package:aspectd/src/plugins/aop/aop_transformer_wrapper.dart';
import 'package:aspectd/src/plugins/pluginDemo/pluginDemo_transformer_wrapper.dart';
import 'package:aspectd/src/plugins/autoRegister/autoRegister_transformer_wrapper.dart';

class TransformerWrapper{
  Component platformStrongComponent;
  
  TransformerWrapper(this.platformStrongComponent);
  
  bool transform(Component component){
    AopWrapperTransformer aopWrapperTransformer = new AopWrapperTransformer(platformStrongComponent: this.platformStrongComponent);
    aopWrapperTransformer.transform(component);

    PluginDemoWrapperTransformer pluginDemoWrapperTransformer = new PluginDemoWrapperTransformer(platformStrongComponent: this.platformStrongComponent);
    pluginDemoWrapperTransformer.transform(component);

    AutoRegisterWrapperTransformer autoRegisterWrapperTransformer = new AutoRegisterWrapperTransformer(platformStrongComponent: this.platformStrongComponent);
    autoRegisterWrapperTransformer.transform(component);

    return true;
  }
}