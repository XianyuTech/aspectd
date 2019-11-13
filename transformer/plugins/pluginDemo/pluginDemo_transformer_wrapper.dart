import 'package:kernel/ast.dart';

class PluginDemoWrapperTransformer {
  PluginDemoWrapperTransformer({this.platformStrongComponent});

  Component platformStrongComponent;

  void transform(Component program) {
    for (Library library in program.libraries) {
      final String libraryName = library.canonicalName.name;
      if (libraryName != 'package:example/main.dart') {
        continue;
      }
      for (Class cls in library.classes) {
        final String clsName = cls.name;
        if (clsName != '_MyHomePageState') {
          continue;
        }
        for (Procedure procedure in cls.procedures) {
          final String procedureName = procedure.name.name;
          if (procedureName != 'onPluginDemo') {
            continue;
          }
//          procedure.function.body = Block([]);
        }
      }
    }
  }
}
