# coding=utf-8

import os
import subprocess


def get_parent_path(child_path_str, count):
    result_path = os.path.realpath(child_path_str)
    for i in range(count):
        result_path = os.path.dirname(result_path)
    return result_path


def get_sdk_path():
    with open('.packages', 'r') as package_reader:
        config_list = package_reader.readlines()
        for config in config_list:
            data_list = config.split(":")
            if len(data_list) == 3 and data_list[0] == 'kernel':
                kernel_path_str = data_list[2].replace('///', '/')
                return get_parent_path(kernel_path_str, 4)

        return None


def get_config():
    with open('package_config.json', 'r') as config_reader:
        return config_reader.read()


def create_tmp_config(config, root_sdk):
    result_file = 'tmp_config.json'
    new_config = config.replace('../../../third_party/dart', root_sdk)
    with open(result_file, 'w') as config_writer:
        config_writer.write(new_config)
    return result_file


def generate_frontend_snapshot(packages, entry_point, output_file):
    cmd = f'dart' \
          f' --deterministic' \
          f' --packages={packages}' \
          f' --snapshot={output_file}' \
          f' --snapshot-kind=kernel' \
          f' {entry_point}'
    process = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True)
    (success, error) = process.communicate()
    return_code = process.wait()
    if return_code != 0:
        raise SystemError(error)


if __name__ == '__main__':
    sdk_path = get_sdk_path()
    if sdk_path is None:
        raise SystemError('sdk path is not exist')
    config_content = get_config()
    tmp_config_file = create_tmp_config(config_content, sdk_path)
    generate_frontend_snapshot(tmp_config_file, 'lib/starter.dart', '../frontend_server.dart.snapshot')
    os.remove(tmp_config_file)
    print('generate frontend_server.dart.snapshot success')
