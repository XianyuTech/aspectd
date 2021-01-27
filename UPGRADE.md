This document describes how to upgrade aspectd in order to compatible with various flutter new versions.

Let's take flutter 1.23.0-7.0.pre (FLT_VER below) as an example.

# Update flutter and dependency(engine,dart) to FLT_VER
## Create branch stable/FLT_VER for flutter repo
```shell
kylewong@KyleWongs-Work-MBP aspectd % flutter --version
Flutter 1.23.0-7.0.pre • channel unknown • unknown source
Framework • revision db6e2d8aa5 (2 weeks ago) • 2020-09-25 06:47:03 -0400
Engine • revision 3a73d073c8
Tools • Dart 2.11.0 (build 2.11.0-161.0.dev)
```
## Fetch flutter engine dependency
See [Setting up the Engine development environment](https://github.com/flutter/flutter/wiki/Setting-up-the-Engine-development-environment) for more.

## Create branch stable/FLT_VER for engine repo
```shell
kylewong@KyleWongs-Work-MBP flutter % pwd
/Users/kylewong/Codes/Flutter/alibaba-flutter/engine/src/flutter
kylewong@KyleWongs-Work-MBP flutter % git branch stable/v1.23.0-7.0.pre 3a73d073c8 && git checkout stable/v1.23.0-7.0.pre
Switched to branch 'stable/v1.23.0-7.0.pre'
```
## Fetch dart dependency
```shell
kylewong@KyleWongs-Work-MBP flutter % pwd
/Users/kylewong/Codes/Flutter/alibaba-flutter/engine/src/flutter
kylewong@KyleWongs-Work-MBP flutter % gclient sync
Syncing projects: 100% (104/104), done.                                                                                        
Running hooks: 100% ( 9/ 9) dart package config   
________ running 'vpython src/flutter/tools/run_third_party_dart.py' in '/Users/kylewong/Codes/Flutter/alibaba-flutter/engine'
Resolving dependencies... 
Got dependencies!
Package generate_package_config is currently active at path "/Users/kylewong/Codes/Flutter/alibaba-flutter/engine/src/flutter/tools/generate_package_config".
Activated generate_package_config 0.0.0 at path "/Users/kylewong/Codes/Flutter/alibaba-flutter/engine/src/flutter/tools/generate_package_config".
Running hooks: 100% (9/9), done.  
```
# Modify dart repo
## Create branch stable/FLT_VER for dart repo with HEAD commit
```shell
kylewong@KyleWongs-Work-MBP dart % pwd
/Users/kylewong/Codes/Flutter/alibaba-flutter/engine/src/third_party/dart
kylewong@KyleWongs-Work-MBP dart % git branch stable/v1.23.0-7.0.pre HEAD && git checkout stable/v1.23.0-7.0.pre
Switched to branch 'stable/v1.23.0-7.0.pre'
```
Notice the head commit for dart above, it can be found in flutter_engine_repo/DEPS file as below:
```DEPS
  'dart_revision': 'eb8e6232da023cddd3326e13c9a4f9ace0acc346',
```
## Add dart_repo/third_party/pkg and dart_repo/third_party/pkg_tested under source control
### Edit .gitignore under dart_repo/third_party
Remove  *, !pkg, and !pkg_tested 
```shell
# ignore everything
*
# except for items in the pkg directory and self.
# except for our files in boringssl.  The checkout is in boringssl/src.
!.gitignore
!pkg
!pkg_tested
!/tcmalloc
!d8
!7zip.tar.gz.sha1
!firefox_jsshell
!clang.tar.gz.sha1
!unittest.tar.gz.sha1
!update.sh
!/wasmer
# but ignore a subfolder of tcmalloc (some client ignores /tcmalloc/.gitignore)
/tcmalloc/gperftools
```
### Remove all .git repos under pkg and pkg_tested
```shell
kylewong@KyleWongs-Work-MBP third_party % pwd
/Users/kylewong/Codes/Flutter/alibaba-flutter/engine/src/third_party/dart/third_party
kylewong@KyleWongs-Work-MBP third_party % rm -rf pkg/*/.git pkg_tested/*/.git
kylewong@KyleWongs-Work-MBP third_party % 
```
### Commit all the files under source control now.
```shell
kylewong@KyleWongs-Work-MBP dart % pwd
/Users/kylewong/Codes/Flutter/alibaba-flutter/engine/src/third_party/dart
kylewong@KyleWongs-Work-MBP dart % git add -A && git commit -m "Add pkg/pkg_tested under source control."
warning: CRLF will be replaced by LF in third_party/pkg/linter/README.md.
The file will have its original line endings in your working directory
warning: CRLF will be replaced by LF in third_party/pkg/mustache/lib/src/template.dart.
The file will have its original line endings in your working directory
[stable/v1.23.0-7.0.pre 9fa5ae49522] Add pkg/pkg_tested under source control.
 4522 files changed, 742202 insertions(+), 3 deletions(-)
 create mode 100644 third_party/pkg/args/.gitignore
```
So that the dart sdk and all its dependencies can be fetched in single git repo using flutter packages get.
### Modify dart repo and push it to remote
```shell
kylewong@KyleWongs-Work-MBP dart % pwd
/Users/kylewong/Codes/Flutter/alibaba-flutter/engine/src/third_party/dart
kylewong@KyleWongs-Work-MBP dart % git remote add alf_upstream git@github.com:alibaba-flutter/sdk.git
kylewong@KyleWongs-Work-MBP dart % git fetch alf_upstream
remote: Enumerating objects: 3274, done.
remote: Counting objects: 100% (3274/3274), done.
remote: Compressing objects: 100% (2225/2225), done.
remote: Total 7473 (delta 1422), reused 2834 (delta 995), pack-reused 4199
Receiving objects: 100% (7473/7473), 14.80 MiB | 2.06 MiB/s, done.
Resolving deltas: 100% (2041/2041), completed with 650 local objects.
From github.com:alibaba-flutter/sdk
 * [new branch]              master                             -> alf_upstream/master
 * [new branch]              stable/v1.22.1                     -> alf_upstream/stable/v1.22.1
```

Cherry-pick commit at [Support customized transformer for developers.](https://github.com/alibaba-flutter/sdk/commit/6106808f20068c7d180c9b897e0dcaef52a8af63) and resolve the conflicts if occurs.
```shell
kylewong@KyleWongs-Work-MBP dart % git cherry-pick 6106808f20068c7d180c9b897e0dcaef52a8af63
[stable/v1.23.0-7.0.pre 8ea36b47942] Support customized transformer for developers.
 Date: Thu Oct 8 18:19:04 2020 +0800
 1 file changed, 13 insertions(+)
```

### Push it to github
```shell
kylewong@KyleWongs-Work-MBP dart % git push alf_upstream stable/v1.23.0-7.0.pre 
Enumerating objects: 4980, done.
Counting objects: 100% (4980/4980), done.
Delta compression using up to 12 threads
Compressing objects: 100% (4005/4005), done.
Writing objects: 100% (4971/4971), 11.96 MiB | 1.52 MiB/s, done.
Total 4971 (delta 795), reused 4255 (delta 753)
remote: Resolving deltas: 100% (795/795), completed with 8 local objects.
remote: 
remote: Create a pull request for 'stable/v1.23.0-7.0.pre' on GitHub by visiting:
remote:      https://github.com/alibaba-flutter/sdk/pull/new/stable/v1.23.0-7.0.pre
remote: 
To github.com:alibaba-flutter/sdk.git
 * [new branch]              stable/v1.23.0-7.0.pre -> stable/v1.23.0-7.0.pre
```
If you don't have permission, file a pull request.
# Modify aspectd
## Edit sdk dependency in pubspec.yaml
```yaml
dependency_overrides:
  kernel:
    git:
      url: git@github.com:alibaba-flutter/sdk.git
      ref: stable/v1.23.0-7.0.pre
      path: pkg/kernel
```
## Fetch dependency for aspectd
```shell
kylewong@KyleWongs-Work-MBP aspectd % pwd                                 
/Users/kylewong/Codes/Flutter/alibaba-flutter/aspectd
kylewong@KyleWongs-Work-MBP aspectd % flutter packages upgrade
```
# Modify flutter_tools
```shell
kylewong@KyleWongs-Work-MBP flutter % git apply --3way /Users/kylewong/Codes/Flutter/alibaba-flutter/aspectd/0001-aspectd.patch 
kylewong@KyleWongs-Work-MBP flutter % rm /Users/kylewong/Codes/Flutter/alibaba-flutter/flutter/bin/cache/flutter_tools.stamp && flutter --version
```
If there's any errors(conflicts) occurs when running commands above, resolve it, commit it and recreate the patch:
```shell
kylewong@KyleWongs-Work-MBP flutter % git format-patch -1 xxxxxx
0001-aspectd.patch
```
Then replace the original patch under aspectd repo using the newly created one.

# Modify flutter_frontend_server folder
1. Replace aspectd/lib/src/flutter_frontend_server/package_config.json with engine/src/flutter/flutter_frontend_server/.dart_tool/package_config.json
2. Replace aspectd/lib/src/flutter_frontend_server/server.dart with engine/src/flutter/flutter_frontend_server/lib/server.dart
3. Replace aspectd/lib/src/flutter_frontend_server/starter.dart  with engine/src/flutter/flutter_frontend_server/bin/starter.dart

For changes happens for server.dart and starter.dart from git's angle of view, you should make sure that only contents below should use our changes(make sure there is also no compilation error), otherwise, using the engine provide content.
![start.dart](http://gw.alicdn.com/mt/TB1_lKwYuL2gK0jSZFmXXc7iXXa-3292-610.png)
![server.dart](http://gw.alicdn.com/mt/TB1j7ybYpY7gK0jSZKzXXaikpXa-3292-1416.png)

# Verify it
## Modify aspectd_impl/pubspec.yaml with contents below:
```yaml
dependencies:
  flutter:
    sdk: flutter
  aspectd:
    path: ../
  example:
    path: ../example
```
## Run commands below for aspectd, example, aspectd_impl.
```shell
flutter clean && rm .packages pubspec.lock && flutter packages upgrade
```
## Check the cases given in aop_impl.dart
Check RegularCallDemo, RegexCallDemo, RegularExecuteDemo, RegexExecuteDemo, InjectDemo one by one.
## Run the example using commands below to verify it.
```shell
flutter run --release --verbose
flutter run --debug --verbose
```
If it works fine, the upgrade will be completed.