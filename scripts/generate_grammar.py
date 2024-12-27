from os import listdir
from os.path import isfile, join
import sys

path = 'vsql'
files = [path + '/' + f for f in listdir(path) if isfile(join(path, f)) and f.endswith('.y')]

top = ""
middle = ""
bottom = ""

for file_path in sorted(files):
  with open(file_path) as f:
    parts = f.read().split('%%')
    if len(parts) != 3:
      sys.exit(path + ': wrong number of parts (' + str(len(parts)) + ')')
    top += parts[0]
    middle += parts[1]
    bottom += parts[2]

with open(path + '/' + 'y.y', 'w') as f:
  f.write(top.strip())
  f.write('\n%%\n')
  f.write(middle.strip())
  f.write('\n%%\n')
  f.write(bottom.strip())
