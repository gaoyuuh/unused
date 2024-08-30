# -*- coding: utf-8 -*-

import os
import json
import re


def get_unused_class_fromipa(ipa_path=''):
    command = '../bin/unused -class -path %s' % ipa_path
    result = os.popen(command).read()
    return result.split('\n')

def exists_in_private_modules(modules_dir='', classes=None):
    if classes is None:
        return False
    results = []
    count = 0
    for cls in classes:
        command = 'ag -G ".+[.h|.m|.mm|.xml|.xib]" --ignore *.framework -w "%s" %s' % (cls, modules_dir)
        result = os.popen(command).read()
        lines = result.split('\n')
        for line in lines:
            if line == '':
                continue
            result_finditer1 = line.find('@interface ' + cls)
            result_finditer2 = line.find('@implementation ' + cls)
            result_finditer3 = line.find('.framework')
            result_finditer4 = line.find('customClass="' + cls)
            result_finditer5 = line.find(cls + '.m')
            temp = line.split(':')
            content = line
            if len(temp) >= 3:
                content = temp[2]

            if result_finditer1 == -1 and result_finditer2 == -1 and result_finditer3 == -1 and result_finditer4 == -1 and result_finditer5 == -1 and content.startswith(
                    '//') == False and content.startswith('#import') == False and content.find('IMP_BLOCK_SELF') == -1:
                count += 1

            if count > 0:
                break

        if count == 0:
            command1 = 'ag -c -G ".+\.plist" -w "%s" %s' % (cls, modules_dir)
            result1 = os.popen(command1).read()
            if result1 != '':
                count += 1
        print(cls, count)
    return True if count > 0 else False


def check_unuse_class_new(dir='', scheme_name='', ipa_path=''):
    modules_dir = os.path.join(dir, "Modules")
    classes = get_unused_class_fromipa(ipa_path)
    exists_in_private_modules(modules_dir, classes)
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

    check_unuse_class_new('/Users/gaoyu/Desktop/techwolf/o2-2.9.3', 'Orange', '/Users/gaoyu/Desktop/Orange-RD.app')