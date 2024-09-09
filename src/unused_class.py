# -*- coding: utf-8 -*-

import os
import json
import re
import time

reghClass = re.compile('@implementation (.*?)')

# 分隔数组
def split_array(arr, chunk_size=800):
    """
    将数组按指定的大小进行分隔。

    Args:
        arr (list): 要分隔的数组。
        chunk_size (int): 每个子数组的最大元素个数。

    Returns:
        list: 包含子数组的列表，每个子数组最多包含 chunk_size 个元素。
    """
    # 使用列表切片将数组按chunk_size大小分隔
    return [arr[i:i + chunk_size] for i in range(0, len(arr), chunk_size)]

def get_unused_class_fromipa(ipa_path=''):
    command = '../bin/unused -class -path %s' % ipa_path
    result = os.popen(command).read()
    return result.split('\n')

def chunk_exists_in_private_modules(search_word_list, search_dir_list, chunk_size=800):
    used_class_list = []
    chunks = split_array(search_word_list, chunk_size)
    for i, chunk in enumerate(chunks):
        used_list = exists_in_private_modules(chunk, search_dir_list)
        used_class_list.extend(used_list)
    return used_class_list

def exists_in_private_modules(search_word_list, search_dir_list):
    if len(search_word_list) <= 0 or len(search_dir_list) <= 0:
        return []
    print("find class count: %s in %s" % (len(search_word_list), search_dir_list))
    command = 'ag -G ".+\.(m|mm)$" --ignore Pods --ignore *.framework -w "%s" %s' % ('|'.join(search_word_list), ' '.join(search_dir_list))
    lines = []
    try:
        result = os.popen(command).read().strip()
        lines = result.split('\n')
    except:
        print(command)
    result_list = []
    for line in lines:
        if line == '':
            continue
        for className in search_word_list:
            if className in line:
                result_finditer2 = line.find('@implementation ' + className)
                temp = line.split(':')
                content = line
                if len(temp) >= 3:
                    content = temp[2]
                if (result_finditer2 >= 0 and
                    content.startswith('//') == False):
                    if not className in result_list:
                        result_list.append(className)
                    break
    return result_list

def check_result_with_xml(modules_dir='', classes=None):
    if classes is None:
        return []
    temp = []
    command = 'ag -G ".+\.xml" --vimgrep -w "%s" %s' % ('|'.join(classes), modules_dir)
    lines = []
    try:
        result = os.popen(command).read().strip()
        lines = result.split('\n')
    except:
        print(command)
    for line in lines:
        if line == '':
            continue
        unused = True
        for cls in classes:
            if cls in line:
                # 输出格式: 文件路径:行号:列号:匹配内容
                parts = line.split(':', 3)
                if len(parts) < 4:
                    continue
                # file_path: 文件路径、
                # line_number: 行号、
                # column_number: 列号
                # matched_line: 具体匹配内容
                file_path, line_number, column_number, matched_line = parts
                if matched_line.strip().startswith("<%s " % cls):
                    # FlexXmlBaseView。根view类型和类名一致
                    # 如果不是FlexXmlBaseView类型，可以认为此cls在xml中是有用的，所以需要从无用列表内过滤掉
                    filename_without_extension = os.path.splitext(os.path.basename(file_path))[0]
                    if filename_without_extension != cls:
                        unused = False
                        break
                if unused:
                    temp.append(cls)
    return temp


def check_result_with_plist(modules_dir='', classes=None):
    if classes is None:
        return []
    temp = []
    command = 'ag -G ".+\.plist" -w "%s" %s' % ('|'.join(classes), modules_dir)
    lines = []
    try:
        result = os.popen(command).read().strip()
        lines = result.split('\n')
    except:
        print(command)
    for line in lines:
        if line == '':
            continue
        for cls in classes:
            if cls in line:
                if not cls in temp:
                    temp.append(cls)
    return temp

def check_unuse_class_new(project_dir='', modules_dir='', scheme_name='', ipa_path=''):
    start_time = time.time()

    classes = get_unused_class_fromipa(ipa_path)
    for cls in classes:
        print(cls)
    print(len(classes))
    print("duration：", time.time() - start_time)

    classes = chunk_exists_in_private_modules(classes, [modules_dir])
    for cls in classes:
        print(cls)
    print(len(classes))
    print("duration：", time.time() - start_time)

    print("从xml内检测")
    classes = check_result_with_xml(modules_dir, classes)
    for cls in classes:
        print(cls)
    print(len(classes))
    print("duration：", time.time() - start_time)

    print("从plist内检测")
    classes = check_result_with_plist(modules_dir, classes)
    for cls in classes:
        print(cls)
    print(len(classes))
    print("duration：", time.time() - start_time)
    return


if __name__ == '__main__':
    class CheckInfo:
        project_id: int
        item_id: int
        task_id: int
        branch: str
        scheme_name: str

        def __init__(self, project_id, task_id, item_id, logger, branch, scheme_name):
            self.project_id = project_id
            self.task_id = task_id
            self.item_id = item_id
            self.branch = branch
            self.scheme_name = scheme_name

    # check_unuse_class_new('/Users/gaoyu/Desktop/techwolf/o2-2.9.3', '/Users/gaoyu/Desktop/techwolf/o2-2.9.3/Modules', 'Orange', '/Users/gaoyu/Desktop/Orange-RD.app')
    check_unuse_class_new('/Users/gaoyu/Desktop/techwolf/boss/Project', '/Users/gaoyu/Desktop/techwolf/boss', 'BossZP', '/Users/gaoyu/Desktop/BossZP-RD.app')