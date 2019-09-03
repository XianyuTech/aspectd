

/// date: 2019-09-01 16:28
/// author: bruce.zhang
/// description: 自动注册组件
/// 多业务场景，涉及到路由、组件统一注册时，往往需要手动在初始化是统一注册，这对各业务开发耦合度比较高，
/// 该功能就是解决这种耦合场景
///
/// modification history:


import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path;

import 'package:kernel/ast.dart';
import 'package:front_end/src/fasta/kernel/kernel_ast_api.dart';
import '../utils.dart';

/// register.json file' path is lib/config/register.json
const String REGISTER_INFO_FILE_NAME = "config/register.json";

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
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is RegisterInfo &&
              runtimeType == other.runtimeType &&
              interfaceLibrary == other.interfaceLibrary &&
              interfaceName == other.interfaceName &&
              initLibrary == other.initLibrary &&
              initClassName == other.initClassName &&
              initMethodName == other.initMethodName &&
              registerToMethodName == other.registerToMethodName;

  @override
  int get hashCode =>
      interfaceLibrary.hashCode ^
      interfaceName.hashCode ^
      initLibrary.hashCode ^
      initClassName.hashCode ^
      initMethodName.hashCode ^
      registerToMethodName.hashCode;

  @override
  String toString() {
    return 'RegisterInfo{interfaceLibrary: $interfaceLibrary, interfaceName: $interfaceName, initLibrary: $initLibrary, initClassName: $initClassName, initMethodName: $initMethodName, registerToMethodName: $registerToMethodName}';
  }
}


class AutoRegisterTransformer extends Transformer {
  List<RegisterInfo> _registerInfoList;

  AutoRegisterTransformer();

  void initRegisterInfo(Reference mainMethodNameRef) {
    _registerInfoList = _parseRegisterInfo(mainMethodNameRef);
  }

  void aspectdTransform(List<Library> libraries) {
    if(libraries == null || libraries.isEmpty) {
      return;
    }

    if(_registerInfoList == null || _registerInfoList.isEmpty) {
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
    print('===registerInfo: ${interfaceImplMapList?.length} : $interfaceImplMapList');

    interfaceImplMapList?.forEach((registerInfo, interfaceImplClsList) {
      Library library = libraryMap[registerInfo.initLibrary];
      if(library == null) {
        return;
      }

      // 1. 接口实现类构造函数调用，如组件componentA
      // 2. 注册实现类方法调用，如注册组件registerComponent(new ComponentA());
      // 3. 将上述调用注入到到init方法中
      if(registerInfo.initClassName?.isNotEmpty == true) {
        // insert code to instance method
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

            if(registerToMethodProcedure == null || initMethodProcedure == null) {
              break;
            }

            // if initMethod is static, registerToMethod must be static
            if(initMethodProcedure.isStatic && !registerToMethodProcedure.isStatic) {
              break;
            }

            for (var implCls in interfaceImplClsList) {
              if(!identical(library, implCls.parent)) {
                AspectdUtils.insertLibraryDependency(library, implCls.parent);
              }

              if(implCls.constructors.isNotEmpty) {
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

                print('===insert ConstructorInvocation: ${implCls.canonicalName.name}');
              }
            }

            break;
          }
        }
      } else {
        // insert code to top level method
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

        if(registerToMethodProcedure == null || initMethodProcedure == null) {
          return;
        }

        for (var implCls in interfaceImplClsList) {
          if(!identical(library, implCls.parent)) {
            AspectdUtils.insertLibraryDependency(library, implCls.parent);
          }

          if(implCls.constructors.isNotEmpty) {
            ConstructorInvocation constructorInvocation = ConstructorInvocation.byReference(implCls.constructors.first.reference, Arguments([]));
            Arguments arguments = Arguments([constructorInvocation]);
            Expression callExpression = StaticInvocation(registerToMethodProcedure, arguments);
            Block block = initMethodProcedure.function.body as Block;
            List<Statement> statements = block.statements;
            statements.add(ExpressionStatement(callExpression));

            print('===insert ConstructorInvocation: ${implCls.canonicalName.name}');
          }
        }
      }
    });

  }

  /// 查找所有接口的实现类
  void findInterfaceImpls(Library library, List<RegisterInfo> registerInfoList,
      Map<RegisterInfo, List<Class>> interfaceImplMapList) {
    for (var registerInfo in registerInfoList) {
      for (Class cls in library.classes) {
        if(!cls.isAbstract) {
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

  /// date: 2019-09-01 15:03
  /// author: bruce.zhang
  /// description: get the path of file register.json
  static File _getRegisterInfoFile(Reference mainMethodNameRef) {
    var node = mainMethodNameRef.node;
    while(node is! Library) {
      node = node.parent;
    }
    String aopFilePath = (node as Library).fileUri.path;
    FileSystemEntity libDir = new File(aopFilePath);
    while(path.basename(libDir.path) != 'lib') {
      libDir = libDir.parent;
    }
    return File(path.join(libDir.path, REGISTER_INFO_FILE_NAME));
  }

  /// 解析regsiter.json文件
  static List<RegisterInfo> _parseRegisterInfo(Reference mainMethodNameRef) {
    File registerInfoFile = _getRegisterInfoFile(mainMethodNameRef);

    if(registerInfoFile.existsSync() == true) {
      String registerContent = registerInfoFile.readAsStringSync();
      List<RegisterInfo> list = <RegisterInfo>[];

      var jsonData = json.decode(registerContent);
      if (jsonData is List) {
        for (var map in jsonData) {
          list.add(RegisterInfo(
              interfaceLibrary: map['interfaceLibrary'],
              interfaceName: map['interfaceName'],
              initLibrary: map['initLibrary'],
              initClassName: map['initClassName'],
              initMethodName: map['initMethodName'],
              registerToMethodName: map['registerToMethodName']));
        }
      }

      return list;
    } else {
      return null;
    }
  }
}