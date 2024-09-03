# -*- coding: utf-8 -*-

import os
import json
import re
import time

reghClass = re.compile('@implementation (.*?)')

def get_unused_class_fromipa(ipa_path=''):
    command = '../bin/unused -class -path %s' % ipa_path
    result = os.popen(command).read()
    return result.split('\n')

def exists_in_private_modules(modules_dir='', classes=None):
    if classes is None:
        return []
    temp = []
    for cls in classes:
        exist = False
        command = 'ag -G ".+\.(m|mm)$" --ignore Pods --ignore *.framework "@implementation %s" %s' % (cls, modules_dir)
        result = os.popen(command).read().strip()
        lines = result.split('\n')
        for line in lines:
            if line == '':
                continue
            matched_line = line.strip()
            result_finditer1 = matched_line.startswith('@implementation %s' % cls)
            if result_finditer1:
                exist = True
                break
        if exist:
            temp.append(cls)
        print(cls, '存在' if exist else '不存在')
    return temp


def check_result_with_xml(modules_dir='', classes=None):
    if classes is None:
        return []
    temp = []
    for cls in classes:
        unused = True
        command = 'ag -G ".+\.xml" --vimgrep "<%s " %s' % (cls, modules_dir)
        result = os.popen(command).read().strip()
        lines = result.split('\n')
        for line in lines:
            if line == '':
                continue
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
    for cls in classes:
        command = 'ag -c -G ".+\.plist" -w "%s" %s' % (cls, modules_dir)
        result = os.popen(command).read().strip()
        # 如果 result 为空，说明在plist中未找到类名，认为该类未使用
        if not result:
            temp.append(cls)
    return temp


def check_unuse_class_new(project_dir='', modules_dir='', scheme_name='', ipa_path=''):
    start_time = time.time()

    classes = get_unused_class_fromipa(ipa_path)
    for cls in classes:
        print(cls)
    print(len(classes))
    print("duration：", time.time() - start_time)

    classes = exists_in_private_modules(modules_dir, classes)
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