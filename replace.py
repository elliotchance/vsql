import re

# def my_replace(match):
#   match = match.group()
#   return match + str(match.index('e'))

file = open("grammar.bnf", "r")
content = file.read()
content = content.replace('::=', ':')
content = re.sub('<.*?>', lambda m: m.group().lower()[1:-1].replace(' ', '_').replace('-', '_'), content)
content = re.sub('->(.*)', lambda m: '{ ' + m.group(1) + '() }', content)

print(content)
