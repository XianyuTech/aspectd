// @dart=2.8
library frontend_server;

import 'dart:io';

import 'server.dart';

void main(List<String> args) async {
  if (args.length == 1) {
    args = ['--sdk-root',
      '/Users/kylewong/Codes/Flutter/Stable/flutter/bin/cache/artifacts/engine/common/flutter_patched_sdk_product/',
      '--target=flutter',
      '-Ddart.developer.causal_async_stacks=false',
      '-Ddart.vm.profile=false',
      '-Ddart.vm.product=true',
      '--bytecode-options=source-positions',
      '--aot',
      '--tfa',
      '--packages',
      '/Users/kylewong/Desktop/AOP/aspectd_impl/.packages',
      '--output-dill',
      '/Users/kylewong/Desktop/AOP/aspectd_impl/.dart_tool/flutter_build/813e97f9a7f8724ada936471b01d5cea/app.dill',
      '--depfile',
      '/Users/kylewong/Desktop/AOP/aspectd_impl/.dart_tool/flutter_build/813e97f9a7f8724ada936471b01d5cea/kernel_snapshot.d',
      'package:aspectd_impl/aspectd_impl.dart'];
  }
  final int exitCode = await starter(args);
  if (exitCode != 0) {
    exit(exitCode);
  }
}
