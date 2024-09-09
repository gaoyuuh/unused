# This is a sample Python script.

import os
import subprocess
from datetime import datetime

def print_hi(name):
    # Use a breakpoint in the code line below to debug your script.
    print(f'Hi, {name}')  # Press ⌘F8 to toggle the breakpoint.


def split_array(arr, chunk_size=500):
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


# Press the green button in the gutter to run the script.
if __name__ == '__main__':
    start_time = datetime.now()

    array = [f"UIViewControllerController{i}" for i in range(1, 20000)]
    chunks = split_array(array, chunk_size=500)  # 将数组按 500 个元素进行分隔

    # 打印结果
    for i, chunk in enumerate(chunks):
        print(f"Chunk {i + 1}: {chunk[:5]}... (共 {len(chunk)} 个元素)")

        command = 'ag -G ".+\.(h|m|mm|xml|xib)$" --ignore Pods --ignore *.framework -w "%s" %s' % (
            '|'.join(chunk), "/Users/gaoyu/AppFatless/BossZP/Code/Project")
        print(command)
        lines = []
        matched_classes = []
        try:
            r = os.popen(command).read()
            lines = r.split('\n')
        except:
            print(command)

    print(datetime.now() - start_time)


# See PyCharm help at https://www.jetbrains.com/help/pycharm/

    # # command = 'ag -G ".+[.h|.m|.mm|.xml|.xib]" --ignore *.framework -w "%s" %s'%(className, cdir)
    # # --ignore Example --ignore *.framework
    # # -G ".+\.(h|m|mm|xml|xib)$"
    # command = 'ag -G ".+[.h|.m|.mm|.xml|.xib]" --ignore *.framework "@implementation %s" %s' % (className, cdir)
    #
    # lines = []
    # try:
    #     result = os.popen(command).read().strip()