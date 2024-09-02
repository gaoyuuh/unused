# -*- coding: utf-8 -*-

import os
import json
import re
import time


def get_unused_class_fromipa(ipa_path=''):
    command = '../bin/unused -class -path %s' % ipa_path
    result = os.popen(command).read()
    return result.split('\n')

def exists_in_private_modules(modules_dir='', classes=None):
    if classes is None:
        return []
    results = []
    for cls in classes:
        exist = False
        command = 'ag -G ".+[.h|.m|.mm|.xml|.xib]" --ignore Pods --ignore *.framework -w %s %s' % (cls, modules_dir)
        result = os.popen(command).read()
        lines = result.split('\n')
        print(lines)
        if len(lines) > 0:
            exist = True
        # for line in lines:
        #     if line == '':
        #         continue
            # result_finditer2 = line.find('@implementation ' + cls)
            # temp = line.split(':')
            # content = line
            # if len(temp) >= 3:
            #     content = temp[2]
            #
            # if result_finditer2 == 0 and content.startswith('//') == False:
            #     exist = True
            #     break

        if not exist:
            command1 = 'ag -c -G ".+\.plist" -w "%s" %s' % (cls, modules_dir)
            result1 = os.popen(command1).read()
            if result1 != '':
                exist = True
        if exist:
            results.append(cls)
        print(cls, '存在' if exist else '不存在')
    return results


def check_unuse_class_new(dir='', scheme_name='', ipa_path=''):
    # modules_dir = os.path.join(dir, "Modules")
    modules_dir = os.path.join(dir, "../")
    classes = get_unused_class_fromipa(ipa_path)
    start_time = time.time()
    real_results = exists_in_private_modules(modules_dir, classes)
    print(real_results, len(real_results))
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

    # check_unuse_class_new('/Users/gaoyu/Desktop/techwolf/o2-2.9.3', 'Orange', '/Users/gaoyu/Desktop/BossZP-RD.app')
    check_unuse_class_new('/Users/gaoyu/Desktop/techwolf/boss_1107/bossproject', 'Orange', '/Users/gaoyu/Desktop/BossZP-RD.app')