
import 'package:kernel/ast.dart';
import 'package:front_end/src/fasta/kernel/kernel_ast_api.dart';
import '../utils.dart';

/// 注册信息
class RegisterInfo {
  /// 待注册的接口-importUri
  String interfaceLibrary = '';
  /// 待注册的接口-className
  String interfaceName = '';

  /// 代码注入的library-importUri
  String initLibrary = '';
  /// 代码注入的类-className，如果是顶级方法，该属性是空
  String initClassName = '';
  /// 代码注入的方法名
  String initMethodName = '';
  /// 生成的代码所调用的方法
  String registerToMethodName = '';

  RegisterInfo({
    this.interfaceLibrary, this.interfaceName, this.initLibrary,
      this.initClassName, this.initMethodName, this.registerToMethodName
  }) {
    initLibrary ??= interfaceLibrary;

    assert(interfaceLibrary?.isNotEmpty == true);
    assert(interfaceName?.isNotEmpty == true);
    assert(initMethodName?.isNotEmpty == true);
    assert(registerToMethodName?.isNotEmpty == true);
  }

  @override
  String toString() {
    return 'RegisterInfo{interfaceLibrary: $interfaceLibrary, interfaceName: $interfaceName, initLibrary: $initLibrary, initClassName: $initClassName, initMethodName: $initMethodName, registerToMethodName: $registerToMethodName}';
  }
}


class AutoRegisterTransformer extends Transformer {
  List<RegisterInfo> _registerInfoList;

  AutoRegisterTransformer();

  void initRegisterInfo(String registerFilePath) {
    _registerInfoList = List<RegisterInfo>();

    _registerInfoList.add(RegisterInfo(
        interfaceLibrary: 'package:example/register/component/component.dart',
        interfaceName: 'CCComponent',
        initLibrary: 'package:example/register/component/component.dart',
        initClassName: 'ComponentManager',
        initMethodName: 'init',
        registerToMethodName: 'registerComponent'));

    _registerInfoList.add(RegisterInfo(
        interfaceLibrary: 'package:example/register/router/router.dart',
        interfaceName: 'CCRouter',
        initMethodName: 'init',
        registerToMethodName: 'registerRouter'));
  }

  void aspectdTransform(List<Library> libraries) {
    if(libraries == null || libraries.isEmpty) {
      return;
    }

    final Map<String, Library> libraryMap = Map<String, Library>();
    // 接口的实现类, key是interfaceName
    final Map<RegisterInfo, List<Class>> interfaceImplMapList = Map<RegisterInfo, List<Class>>();

    String importUri;
    for (Library library in libraries.reversed) {
      if (library.isExternal) {
        continue;
      }

      importUri = library.importUri.toString();
      libraryMap.putIfAbsent(importUri, ()=>library);

      // 查找所有接口的实现类
      findInterfaceImpls(library, _registerInfoList, interfaceImplMapList);
    }
    print('===registerInfo: $interfaceImplMapList');

    interfaceImplMapList?.forEach((registerInfo, interfaceImplClsList) {
      Library library = libraryMap[registerInfo.initLibrary];
      if(library == null) {
        return;
      }

      // 1. 接口实现类构造函数调用，如组件componentA
      // 2. 注册实现类方法调用，如注册组件registerComponent(new ComponentA());
      // 3. 将上述调用注入到到init方法中
      if(registerInfo.initClassName?.isNotEmpty == true) {
        // 实例方法中注入代码
        for(var cls in library.classes) {
          if(cls.name == registerInfo.initClassName) {
            Procedure registerToMethodProcedure;
            Procedure initMethodProcedure;
            for(Procedure procedure in cls.procedures) {
              if(procedure.name.name == registerInfo.registerToMethodName && procedure.function.body != null) {
                registerToMethodProcedure = procedure;
              }
              if(procedure.name.name == registerInfo.initMethodName && procedure.function.body != null) {
                initMethodProcedure = procedure;
              }
            }

            // 如果class中没找到register方法，再去library中查找
            if(registerToMethodProcedure == null) {
              for(Procedure procedure in library.procedures) {
                if(procedure.name.name == registerInfo.registerToMethodName && procedure.function.body != null) {
                  registerToMethodProcedure = procedure;
                  break;
                }
              }
            }

            assert(registerToMethodProcedure != null && initMethodProcedure != null,
              'registerToMethodProcedure or initMethodProcedure is null');

            assert(initMethodProcedure.isStatic && registerToMethodProcedure.isStatic || !initMethodProcedure.isStatic,
              'registerToMethodProcedure and registerToMethodProcedure static flag error');

            for (var implCls in interfaceImplClsList) {
              if(!identical(library, implCls.parent)) {
                AspectdUtils.insertLibraryDependency(library, implCls.parent);
              }

              ConstructorInvocation constructorInvocation = ConstructorInvocation.byReference(implCls.constructors.first.reference, Arguments([]));
              Arguments arguments = Arguments([constructorInvocation]);
              Expression callExpression = null;
              if(registerToMethodProcedure.isStatic) {
                callExpression = StaticInvocation(registerToMethodProcedure, arguments);
              } else {
                callExpression = MethodInvocation(ThisExpression(), registerToMethodProcedure.name, arguments);
              }
              Block block = initMethodProcedure.function.body as Block;
              List<Statement> statements = block.statements;
              statements.add(ExpressionStatement(callExpression));
            }

            break;
          }
        }
      } else {
        // 顶级方法中注入代码
        Procedure registerToMethodProcedure;
        Procedure initMethodProcedure;
        for(Procedure procedure in library.procedures) {
          if(procedure.name.name == registerInfo.registerToMethodName && procedure.function.body != null) {
            registerToMethodProcedure = procedure;
          }
          if(procedure.name.name == registerInfo.initMethodName && procedure.function.body != null) {
            initMethodProcedure = procedure;
          }
        }

        assert(registerToMethodProcedure != null && initMethodProcedure != null,
        'registerToMethodProcedure or initMethodProcedure is null');

        for (var implCls in interfaceImplClsList) {
          if(!identical(library, implCls.parent)) {
            AspectdUtils.insertLibraryDependency(library, implCls.parent);
          }

          ConstructorInvocation constructorInvocation = ConstructorInvocation.byReference(implCls.constructors.first.reference, Arguments([]));
          Arguments arguments = Arguments([constructorInvocation]);
          Expression callExpression = StaticInvocation(registerToMethodProcedure, arguments);
          Block block = initMethodProcedure.function.body as Block;
          List<Statement> statements = block.statements;
          statements.add(ExpressionStatement(callExpression));
        }
      }
    });

  }

  /// 查找所有接口的实现类
  void findInterfaceImpls(Library library, List<RegisterInfo> registerInfoList,
      Map<RegisterInfo, List<Class>> interfaceImplMapList) {
    for (var registerInfo in registerInfoList) {
      for (Class cls in library.classes) {
        // 接口的包名和class名比较
        for(var superType in cls.implementedTypes) {
          if(superType.className.canonicalName.parent.reference.asLibrary.importUri.toString() == registerInfo.interfaceLibrary
            && superType.className.canonicalName.name == registerInfo.interfaceName) {
            List<Class> list = interfaceImplMapList[registerInfo];
            if(list == null) {
              list = List<Class>();
              interfaceImplMapList[registerInfo] = list;
            }
            list.add(cls);
            break;
          }
        }
      }
    }
  }
}