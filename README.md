# AspectD for GrowingIO Autotracker

<a href="https://github.com/Solido/awesome-flutter">
   <img alt="Awesome Flutter" src="https://img.shields.io/badge/Awesome-Flutter-blue.svg?longCache=true&style=flat-square" />
</a>

 GrowingIO Flutter 无埋点插件 [flutter-growingio-sdk-autotracker-plugin](https://github.com/growingio/flutter-growingio-sdk-autotracker-plugin.git)  的AspectD依赖版本，基于 [AspectD](https://github.com/XianyuTech/aspectd)  修改，添加了对点击，内容改变，以及页面推出的AOP逻辑，如果需要查看AspectD原理，可以去原地址 [AspectD](https://github.com/XianyuTech/aspectd)  查看。

# 版本信息

```c
    • Flutter version 2.2.2 at /Users/sheng/GrowIO/flutter
    • Framework revision d79295af24 (4 months ago), 2021-06-11 08:56:01 -0700
    • Engine revision 91c9fc8fe0
    • Dart version 2.13.3
    • Pub download mirror https://pub.flutter-io.cn
    • Flutter download mirror https://storage.flutter-io.cn
```
在 AspectD 基础上适配了null-safety

并请在已完成  [flutter-growingio-sdk-autotracker-plugin](https://github.com/growingio/flutter-growingio-sdk-autotracker-plugin.git)  集成步骤的情况下开始。

# 如何使用

例如你的工程为 `hf_dir/example` , cd 到 `hr_dir/`

## 1. 创建一个名为aspectd_impl的dart package

```
flutter create --template=package aspectd_impl
```

## 2. 给aspectd_impl package添加aspectd&example依赖

```
dependencies:
  flutter:
    sdk: flutter
  aspectd:
    git:
      url: git@github.com:growingio/aspectd.git
      ref: master
  example:
    path: ../example
```

>  git@github.com:growingio/aspectd.git 仅修改了master分支，暂时仅支持最新master分支

然后执行

```
flutter packages get
```

## 3. 复制文件到 aspectd_impl

将 https://github.com/growingio/aspectd/tree/master/aspectd_impl/lib 下文件全部拷贝至你新建的 `aspectd_impl/lib` 并替换。

共5个文件：

```
aop_impl.dart		
growing_aop_impl.dart	
growing_impl.dart
aspectd_impl.dart	
growing_event.dart
```

修改 aspectd_impl.dart 文件中的

```
import 'package:example/main.dart' as app;
```

为你自己的项目名

```
import 'package:yourproject/main.dart' as app;
```

## 4. 修改 flutter_tool

```c
cd path-for-flutter-git-repo //进入flutter仓库目录
git apply --3way path-for-aspectd-package/0001-aspectd.patch //应用 patch 
rm bin/cache/flutter_tools.stamp // 删除flutter_tools.stamp
```

这样会变动 common.dart 以及新增 aspectd.dart 文件

``````
modified:   packages/flutter_tools/lib/src/build_system/targets/common.dart

Untracked files:
  (use "git add <file>..." to include in what will be committed)
	packages/flutter_tools/lib/src/aspectd.dart
``````

## 5. flutter pub get 并运行 example



# 常见问题

- Q1:Cannot open file, path = '/Users/xxx/.pub-cache/global_packages/aspectd/pubspec.lock

  ```c
  Target kernel_snapshot failed: Exception: Aspectd unexpected error: Warning: You are using these overridden dependencies:
             ! kernel 0.0.0 from git git@github.com:XianyuTech/sdk.git at c9f1a5 in pkg/kernel
             ! meta 1.3.0 from git git@github.com:XianyuTech/sdk.git at c9f1a5 in pkg/meta
             Cannot open file, path = '/Users/xxx/.pub-cache/global_packages/aspectd/pubspec.lock' (OS Error: No such file or directory, errno = 2)
  
  ```

  A:由于编译 aspectd 时，会下拉kernel以及meta两个库，同时默认会写入到 `/Users/xxx/.pub-cache/global_packages/aspectd/pubspec.lock`文件中，此时可能`/Users/xxx/.pub-cache/global_packages/`下无aspectd目录导致此问题，在路径下新建一个空的 aspectd 目录即可

- Q2: 紧接Q1,出现.packages does not exist.

  ```c
  /Users/xxx/.pub-cache/git/aspectd-fb05b5a4e1bbe7d7dc9ba53c8d2ff42e6a5103d9/.packages does not exist.
              Did you run "flutter pub get" in this directory?
  ```

  A:将`/Users/xxx/.pub-cache/global_packages/aspectd/.dart_tool` Copy到    `/Users/xxx/.pub-cache/git/aspectd-fb05b5a4e1bbe7d7dc9ba53c8d2ff42e6a5103d9/.dart_tool` ，然后执行 flutter pub get

# 感谢

Thanks  [AspectD](https://github.com/XianyuTech/aspectd)  
