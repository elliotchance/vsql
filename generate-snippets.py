from os import listdir
from os.path import isfile, join

src = 'vsql'

v_files = [join(src, f) for f in listdir(src) if isfile(join(src, f)) and f.endswith('.v')]
snippets = {
    'br': """.. |br| raw:: html

   <br>
"""
}


for v_file in sorted(v_files):
    with open(v_file) as f:
        snippet = []
        for line in [line.rstrip() for line in f]:
            if line.strip().startswith('//'):
                snippet.append(line.strip()[2:].strip())
            else:
                if len(snippet) > 0:
                    if snippet[-1].startswith('snippet:'):
                        snippet_name = snippet[-1].split(':')[1].strip()
                        block = '   ' + '\n   '.join([element or '|br| |br|' for element in snippet[:-2]]) + '\n'
                        snippets[snippet_name] = f'.. |{snippet_name}| replace::\n{block}'
                    snippet = []

for snippet_name in sorted(snippets):
    print(snippets[snippet_name])
