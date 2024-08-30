# This is a sample Python script.

import os
import subprocess


def print_hi(name):
    # Use a breakpoint in the code line below to debug your script.
    print(f'Hi, {name}')  # Press ⌘F8 to toggle the breakpoint.


# Press the green button in the gutter to run the script.
if __name__ == '__main__':
    command = '/Users/gaoyu/Desktop/unused/bin/unused -class -path /Users/gaoyu/Desktop/Orange-RD.app'
    result = os.popen(command).read()
    lines = result.split('\n')
    # result = subprocess.run(command, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)

    # # 输出标准输出和标准错误
    # print("Standard Output:", result.stdout)
    # print("Standard Error:", result.stderr)

    print(result)


# See PyCharm help at https://www.jetbrains.com/help/pycharm/
