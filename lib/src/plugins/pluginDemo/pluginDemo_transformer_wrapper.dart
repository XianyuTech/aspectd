import 'package:kernel/ast.dart';

class PluginDemoWrapperTransformer {
  Component platformStrongComponent;

  PluginDemoWrapperTransformer({this.platformStrongComponent});

  void transform(Component program) {
    for(Library library in program.libraries) {
      String libraryName = library.canonicalName.name;
      if(libraryName != 'package:example/main.dart')
        continue;
      for(Class cls in library.classes) {
        String clsName = cls.name;
        if(clsName != '_MyHomePageState')
          continue;
        for(Procedure procedure in cls.procedures) {
          String procedureName = procedure.name.name;
          if(procedureName != 'onPluginDemo')
            continue;
          procedure.function.body = Block([]);
        }
      }
    }
  }
}
