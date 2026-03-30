
import csv
import sys

if len(sys.argv) != 2:
    print("Usage: python nav-gen.py <csv_file>")
    sys.exit(1)

csv_file = sys.argv[1]

data = []

with open(csv_file, mode='r', encoding='utf-8-sig') as file:
    reader = csv.DictReader(file)
    for row in reader:
        data.append(row)

# print(data)

distinct_module = set(item['模块'] for item in data)
distinct_module_list = (" ".join(['''"{}"'''] * len(distinct_module))).format(*distinct_module)

print("'(")
for item in data:
    record = """(地区 "{}" 模块 "{}" k8s "{}" monitor "{}" 流水线 "{}" 代码仓库 "{}" 七彩石 "{}" 日志 "{}")""" \
        .format(item['地区'], item['模块'], item['k8s'], item['monitor'], item['流水线'], item['代码仓库'], item['七彩石'], item['日志'])
    print(record)
print(")")
