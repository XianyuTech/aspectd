How to debug aspectd?

# Prepare

Make sure that you've read README.md and can run the example embedded.

Let's take android as an example.

```shell
flutter run -d xxxxx --verbose --release
```

# Flutter Command Parameters

## Modify flutter_tools/bin/flutter_tools.dart
```dart
import 'package:flutter_tools/executable.dart' as executable;

void main(List<String> args) {
  print("[KWLM]:${args.join(' ')}");
  executable.main(args);
}
```
## Remove cache to rebuild flutter command
```shell
kylewong@KyleWongs-Work-MBP aspectd % which flutter                                      
/Users/kylewong/Codes/Flutter/alibaba-flutter/StableV1.22.x/taobao/flutter/bin/flutter
kylewong@KyleWongs-Work-MBP aspectd % rm /Users/kylewong/Codes/Flutter/alibaba-flutter/StableV1.22.x/taobao/flutter/bin/cache/flutter_tools.stamp 
```
## Rerun flutter command to get parameters to build dill
```shell
kylewong@KyleWongs-Work-MBP example % flutter run -d PQY0220C11037930 --verbose --release
[KWLM]:run -d PQY0220C11037930 --verbose --release
*******
 [KWLM]:--verbose assemble --depfile
/Users/kylewong/Codes/Flutter/alibaba-flutter/Middleware/aspectd/example/build/app/intermediates/flutter/release/flutter_build.d --output /Users/kylewong/Codes/Flutter/alibaba-flutter/Middleware/aspectd/example/build/app/intermediates/flutter/release -dTargetFile=/Users/kylewong/Codes/Flutter/alibaba-flutter/Middleware/aspectd/example/lib/main.dart -dTargetPlatform=android -dBuildMode=release -dTrackWidgetCreation=true android_aot_bundle_release_android-arm64
```
# Frontend_server parameters
## Debug flutter command with parameters get above
![Debug flutter_tools](https://user-images.githubusercontent.com/817851/114263158-89fdc600-9a16-11eb-8d14-ce144faad830.png)

## Set breakpoint for KernelCompiler.compile to get parameters for frontend_server.dart.snapshot

Notice that the breakpoint would enter twice as one for example project and another for aspectd_impl. We want to know what parameters are passed to frontend_server.dart.snapshot when building dill for aspectd_impl project.

![frontend_server.dart.snapshot](https://user-images.githubusercontent.com/817851/114263264-1314fd00-9a17-11eb-972d-416551e20ae5.png)

Evaluate command.join(" ") to get the parameters like below:
```shell
/Users/kylewong/Codes/Flutter/alibaba-flutter/StableV1.22.x/taobao/flutter/bin/cache/dart-sdk/bin/dart --disable-dart-dev /Users/kylewong/Codes/Flutter/alibaba-flutter/StableV1.22.x/taobao/flutter/bin/cache/artifacts/engine/darwin-x64/frontend_server.dart.snapshot --sdk-root /Users/kylewong/Codes/Flutter/alibaba-flutter/StableV1.22.x/taobao/flutter/bin/cache/artifacts/engine/common/flutter_patched_sdk_product/ --target=flutter -Ddart.developer.causal_async_stacks=false -Ddart.vm.profile=false -Ddart.vm.product=true --bytecode-options=source-positions --aot --tfa --packages /Users/kylewong/Codes/Flutter/alibaba-flutter/Middleware/aspectd/example/.packages --output-dill /Users/kylewong/Codes/Flutter/alibaba-flutter/Middleware/aspectd/example/.dart_tool/flutter_build/aaf5bbafc04eaf18a1287f2e90c38b60/app.dill --depfile /Users/kylewong/Codes/Flutter/alibaba-flutter/Middleware/aspectd/example/.dart_tool/flutter_build/aaf5bbafc04eaf18a1287f2e90c38b60/kernel_snapshot.d package:example/main.dart
```

# Debug frontend_server.dart.snapshot
## Prepare package dependencies for aspectd package
```shell
kylewong@KyleWongs-Work-MBP flutter_tools % pwd
/Users/kylewong/Codes/Flutter/alibaba-flutter/StableV1.22.x/taobao/flutter/packages/flutter_tools
kylewong@KyleWongs-Work-MBP flutter_tools % mkdir .dart_tool
```

In order to debug aspectd package, I mean the dill manipulating logic, a lot of dart sdk dependency is needed. You can copy the package_config.json (aspectd/lib/src/flutter_frontend_server/package_config.json) to aspectd/.dart_tool.
Remember to modify package_config.json with absolute path. For example, modify ""../../../third_party/dart/pkg/_fe_analyzer_shared"," to ""rootUri": "file:///Users/kylewong/.pub-cache/git/sdk-e0932796a56a8de60c77923a69b98fdafd0d8db1/pkg/_fe_analyzer_shared",".

## Launch the aspectd/starter.dart as entrypoint
In aspectd, we compile the frontend_server.dart.snapshot with starter.dart, so you can launch it in source mode with parameters above for frontend_server.dart.snapshot.
![Starter.dart](https://user-images.githubusercontent.com/817851/114263646-76079380-9a19-11eb-8284-7ad9ac6adbff.png)

Now you can debug the transformer logic, enjoy.