#!/usr/bin/env python

import sys
from io import StringIO

def peek(sio, size=1):
    """模拟peek操作，查看当前位置后的内容但不移动指针"""
    # 记录当前位置
    pos = sio.tell()
    # 读取内容
    data = sio.read(size)
    # 重置指针位置
    sio.seek(pos)
    return data

def format_proto(text):
    stream = StringIO(text)
    level = 0
    result = []
    char = stream.read(1)
    in_str = False
    while char != '':
        if in_str and char == '\\':
            result.append('\\' + stream.read(1))
        elif char == '"':
            result.append(char)
            in_str = not in_str
        elif not in_str:
            if char == '{':
                result.append(char + '\n' + '  ' * (level + 1))
                level += 1
            elif char == ':':
                result.append(char + ' ')
            elif char == '}':
                while peek(stream, 1) == ' ':
                    stream.read(1)
                level -= 1
                result.append('\n' + '  ' * level + char)
                if peek(stream, 1) != '}':
                    result.append('\n' + '  ' * level)
            elif char == ' ':
                while peek(stream, 1) == ' ':
                    stream.read(1)
                result.append('\n' + '  ' * level)
            else:
                result.append(char)
        else:
            result.append(char)
        char = stream.read(1)
    return ''.join(result)


def main():
    # 从标准输入读取所有内容
    input_text = sys.stdin.read()
    
    # 格式化并输出到标准输出
    formatted_text = format_proto(input_text)
    sys.stdout.write(formatted_text)

if __name__ == '__main__':
    main()
