#!/usr/bin/env python3
"""standard-index.py maintains the SQL standard index in docs/standard/.

The index has a row for every Subclause and every numbered rule of the parts of
the SQL standard that vsql implements, so each one can be marked as
implemented, not applicable, etc. See docs/standard-index.rst.

The standard is copyrighted, so the index only has the numbers and titles of
Subclauses (and our own notes), never the text. The text is read from the PDFs
in standard_docs/ (which are not committed) and needs pypdf:

  scripts/standard-index.py generate
    (Re)creates docs/standard/ from the PDFs. The status, code, tests and note
    of each existing row are kept. Rows that no longer exist (because a newer
    edition renumbered them) are printed so they can be moved by hand.

  scripts/standard-index.py show 2 8.8
    Prints the rows of Part 2, 8.8 alongside the text of each rule and every
    citation of it in the code. This is everything needed to review a
    Subclause, and is only ever printed locally.

  scripts/standard-index.py report [PART]
    Prints how much of each part (or, for one part, each clause) has been
    reviewed and implemented, followed by the rows that need attention: the
    missing, partial, untested, deviating and unclear ones. This doesn't need
    the PDFs.

  scripts/standard-index.py set 2 8.8/GR/2.a implemented CODE TESTS [NOTE]
    Sets the status, code, tests (each "-" or files separated by commas) and
    note of a row. An ID ending with "*" (such as 8.2/GR/1.b.ii*) sets the row
    and every rule within it. This doesn't need the PDFs.

The index is checked (without the PDFs) by scripts/check-standard-index.vsh.
"""

import glob
import hashlib
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
INDEX = os.path.join(ROOT, 'docs', 'standard')
EDITIONS = os.path.join(INDEX, 'editions.txt')
CACHE = os.path.join(ROOT, 'standard_docs', '.text')

# The sections of a Subclause that have numbered rules, and the abbreviations
# used in row IDs. Part 11 describes its views and base tables with numbered
# "Description" items.
SECTIONS = {
    'Syntax Rules': 'SR',
    'Access Rules': 'AR',
    'General Rules': 'GR',
    'Conformance Rules': 'CR',
    'Description': 'DE',
}

# Headings that end a rules section without starting another one.
OTHER_HEADINGS = {'Function', 'Format', 'Definition'}

def roman(n):
    out = ''
    for value, numeral in [(40, 'xl'), (10, 'x'), (9, 'ix'), (5, 'v'), (4, 'iv'), (1, 'i')]:
        while n >= value:
            out += numeral
            n -= value
    return out


ROMAN = [roman(n) for n in range(1, 50)]

# A rule is labeled at each depth as 1), a), i), 1), A), I), and then again
# from 1).
LEVELS = ['digit', 'lower', 'roman', 'digit', 'upper', 'ROMAN']

STATUSES = ['todo', 'implemented', 'untested', 'partial', 'missing', 'deviates',
            'n/a', 'definition', 'container', 'impl-defined', 'untestable',
            'unclear']


def read_editions():
    editions = {}
    for line in open(EDITIONS):
        if line.startswith('#') or not line.strip():
            continue
        part, citation, sha256, source = line.rstrip('\n').split('\t')
        editions[part] = {'citation': citation, 'sha256': sha256,
                          'source': source}
    return editions


def standard_text(edition):
    """The text of a part, extracted from its PDF (and cached)."""
    path = os.path.join(ROOT, 'standard_docs', edition['source'])
    digest = hashlib.sha256(open(path, 'rb').read()).hexdigest()
    if digest != edition['sha256']:
        sys.exit(f'{path} is not the edition in {EDITIONS}')

    # The layout mode keeps the indentation, which is the only way to tell
    # which rule a label like "7)" belongs to.
    cache = os.path.join(CACHE, digest + '-layout.txt')
    if not os.path.exists(cache):
        import pypdf
        os.makedirs(CACHE, exist_ok=True)
        pages = [page_text(p) for p in pypdf.PdfReader(path).pages]
        with open(cache, 'w') as f:
            f.write('\f'.join(pages))

    return open(cache).read()


def page_text(page):
    # A blank page may have no content at all.
    if '/Contents' not in page:
        return ''
    return page.extract_text(extraction_mode='layout') or ''


def squash(s):
    """Removes the spaces (that pypdf sometimes puts inside words) and
    ligatures, so titles can be compared."""
    s = s.replace('ﬁ', 'fi').replace('ﬂ', 'fl').replace('’', "'")
    return re.sub(r'\s+', '', s).lower()


def clean_lines(text):
    """The lines of the text without page headers and footers. The running
    head (the Subclause at the top of each page) is kept, since it can't be
    told apart from a heading at the top of a page. It never looks like a
    rule."""
    pages = []
    for page in text.split('\f'):
        lines = []
        for line in page.split('\n'):
            line = line.replace('ﬁ', 'fi').replace('ﬂ', 'fl').rstrip()
            if not line.strip():
                continue
            if re.fullmatch(r'ISO/IEC (CD )?9075-\d+:\S+\(E\)', line.strip()):
                continue
            if '©ISO/IEC' in line or 'All rights reserved' in line:
                continue
            lines.append(line)
        pages.append(lines)

    # Odd and even pages have different margins, so the indentation is made
    # relative to the left margin. A page may not have any line at the margin
    # (when it's all nested rules), so the margin is the most common one of the
    # pages with the same parity. A change bar (a number in the margin) isn't
    # the margin.
    def page_margin(lines):
        return min((len(line) - len(line.lstrip()) for line in lines
                    if not re.match(r'^\s*\d+\s{2,}\S', line)), default=None)

    margins = {}
    for parity in (0, 1):
        found = [page_margin(lines) for lines in pages[parity::2]]
        found = [m for m in found if m is not None]
        margins[parity] = max(set(found), key=found.count) if found else 0

    out = []
    for n, lines in enumerate(pages):
        margin = margins[n % 2]
        out.extend(line[margin:] if len(line) - len(line.lstrip()) >= margin
                   else line.lstrip() for line in lines)
    return out


def contents(lines):
    """The numbered Subclauses from the table of contents, in order. Annexes
    are not included."""
    toc = []
    seen = set()
    for line in lines:
        # The lists of tables and figures follow the Subclauses.
        if toc and line.strip() in ('Tables', 'Figures'):
            break
        # The dots are ". . ." or "...".
        m = re.match(r'^(\d+(?:\.\d+)*) +(.*?)[ .]*(\. \. |\.\.\.).*?\d+$', line.strip())
        if m and m.group(1) not in seen:
            seen.add(m.group(1))
            toc.append((m.group(1), m.group(2).strip()))
    return toc


def subclauses(lines):
    """Yields (number, title, body lines) for each Subclause, found in the body
    by its heading."""
    toc = contents(lines)
    # The body starts after the last line of the table of contents.
    start = max(i for i, line in enumerate(lines)
                if re.search(r'(\. \. \. |\.\.\.\.).*\d+$', line)) + 1
    found = []
    pos = start
    for number, title in toc:
        want = squash(number + title)
        for i in range(pos, len(lines)):
            if squash(lines[i]) == want:
                found.append((i, number, lines[i].strip()[len(number):].strip()))
                pos = i + 1
                break
        else:
            # Some headings wrap onto a second line.
            for i in range(pos, len(lines) - 1):
                if squash(lines[i] + lines[i + 1]) == want:
                    heading = lines[i].strip() + ' ' + lines[i + 1].strip()
                    found.append((i, number, heading[len(number):].strip()))
                    pos = i + 2
                    break
            else:
                print(f'warning: heading not found: {number} {title}',
                      file=sys.stderr)

    for n, (i, number, title) in enumerate(found):
        end = found[n + 1][0] if n + 1 < len(found) else len(lines)
        # The annexes follow the last Subclause.
        for j in range(i, end):
            if re.match(r'^Annex [A-Z]\b', lines[j]) and j > i:
                end = j
                break
        yield number, re.sub(r'\s+', ' ', title), lines[i + 1:end]


def label_matches(label, level):
    kind = LEVELS[level % len(LEVELS)]
    if kind == 'digit':
        return label.isdigit()
    if kind == 'lower':
        return re.fullmatch(r'[a-z]{1,2}', label) is not None
    if kind == 'upper':
        return re.fullmatch(r'[A-Z]', label) is not None
    if kind == 'roman':
        return label in ROMAN
    return label.lower() in ROMAN and label.isupper()


def first_label(level):
    return ['1', 'a', 'i', '1', 'A', 'I'][level % len(LEVELS)]


def next_label(label, level):
    kind = LEVELS[level % len(LEVELS)]
    if kind == 'digit':
        return str(int(label) + 1)
    if kind in ('roman', 'ROMAN'):
        i = ROMAN.index(label.lower())
        if i + 1 == len(ROMAN):
            return None
        return ROMAN[i + 1].upper() if kind == 'ROMAN' else ROMAN[i + 1]
    # After z) is aa), ab), etc.
    if label == 'z':
        return 'aa'
    if len(label) == 2:
        return label[0] + chr(ord(label[1]) + 1)
    return chr(ord(label) + 1)


def expected_indent(stack, depth):
    """The indentation of a rule at depth, from the rules before it. A new
    depth is indented more than the one before it."""
    if depth < len(stack):
        return stack[depth][0]
    if not stack:
        return 0
    return stack[-1][0] + 6


def rules(body):
    """Yields (section, dotted rule number, text) for each numbered rule. The
    depth of a rule comes from its indentation. A label is only accepted when
    it's the next one at its depth, or the first one of a new depth, so that
    text that happens to look like a label is ignored."""
    section = None
    # stack is the (indent, label) at each depth.
    stack = []
    current = None
    for line in body:
        s = re.sub(r'\s+', ' ', line.strip())
        indent = len(line) - len(line.lstrip())
        if s in SECTIONS:
            if current:
                yield current
                current = None
            section = SECTIONS[s]
            stack = []
            continue
        if s in OTHER_HEADINGS:
            if current:
                yield current
                current = None
            section = None
            continue
        if not section:
            continue

        m = re.match(r'^(\d+|[a-zA-Z]+)\) (.*)', s)
        depth = None
        if m:
            label = m.group(1)
            # The label could be the next one at some depth, or the first one
            # of a new depth. The indentation (which varies a little between
            # pages) decides which: the closest one.
            candidates = [d for d in range(len(stack))
                          if label_matches(label, d) and next_label(stack[d][1], d) == label]
            if label == first_label(len(stack)):
                candidates.append(len(stack))
            if candidates:
                depth = min(candidates, key=lambda d: abs(expected_indent(stack, d) - indent))

        if depth is None:
            if current:
                current = (current[0], current[1], current[2] + ' ' + s)
            continue

        if current:
            yield current
        stack = stack[:depth] + [(indent, label)]
        current = (section, '.'.join(label for _, label in stack), m.group(2))

    if current:
        yield current


def file_for(number):
    """Each clause (like 8) has a file, with the rows of every Subclause within
    it (like 8.8 and 8.8.1)."""
    return number.split('.')[0].zfill(2) + '.txt'


def index_rows(edition, text):
    """Yields (file, number, title, [(id, rule text)]) for each Subclause."""
    for number, title, body in subclauses(clean_lines(text)):
        rows = [(number, None)]
        for section, rule, rule_text in rules(body):
            rows.append((f'{number}/{section}/{rule}', rule_text))
        yield file_for(number), number, title, rows


def read_index_file(path):
    """The existing rows of an index file as {id: [status, code, tests,
    note]}."""
    rows = {}
    if not os.path.exists(path):
        return rows
    for line in open(path):
        if line.startswith('#') or not line.strip():
            continue
        fields = line.rstrip('\n').split(None, 4)
        while len(fields) < 5:
            fields.append('')
        rows[fields[0]] = fields[1:]
    return rows


def generate():
    editions = read_editions()
    for part, edition in editions.items():
        directory = os.path.join(INDEX, f'part{part}')
        os.makedirs(directory, exist_ok=True)
        old = {}
        for name in os.listdir(directory):
            for id, fields in read_index_file(os.path.join(directory, name)).items():
                old[id] = fields

        files = {}
        for name, number, title, rows in index_rows(edition, standard_text(edition)):
            out = files.setdefault(name, [])
            out.append(f'# {number}, {title}')
            for id, rule_text in rows:
                fields = old.pop(id, None) or ['todo', '-', '-', '']
                if fields[0] == 'todo' and rule_text is not None and \
                        rule_text.strip() in ('Case:', 'Otherwise:'):
                    fields[0] = 'container'
                out.append(row(id, fields))

        for name in os.listdir(directory):
            if name not in files:
                os.remove(os.path.join(directory, name))
        for name, out in files.items():
            with open(os.path.join(directory, name), 'w') as f:
                f.write(f'# {edition["citation"]}\n')
                f.write('# id status code tests note '
                        '(see docs/standard-index.rst)\n')
                f.write('\n'.join(out) + '\n')

        for id, fields in old.items():
            if fields[0] != 'todo':
                print(f'removed: part {part}: {row(id, fields)}')


def row(id, fields):
    status, code, tests, note = fields
    return f'{id:<24} {status:<12} {code or "-"} {tests or "-"} {note}'.rstrip()


def show(part, number):
    editions = read_editions()
    edition = editions[part]
    existing = read_index_file(os.path.join(INDEX, f'part{part}', file_for(number)))
    citations = code_citations(edition['citation'])
    for name, n, title, rows in index_rows(edition, standard_text(edition)):
        if n != number and not n.startswith(number + '.'):
            continue
        print(f'== {edition["citation"]}, {n}, {title}')
        for id, rule_text in rows:
            print(row(id, existing.get(id, ['todo', '-', '-', ''])))
            if rule_text:
                print('    | ' + rule_text)
            for location in citations.get(id, []):
                print('    > ' + location)


def code_citations(citation):
    """{id: [file:line]} for every citation of the edition in the code, using
    the checker so that both agree on what a citation is."""
    out = subprocess.run(['v', 'run', os.path.join(ROOT, 'scripts', 'check-standard-index.vsh'),
                          '--citations'], capture_output=True, text=True, cwd=ROOT).stdout
    result = {}
    for line in out.split('\n'):
        if '\t' in line:
            location, cited, id = line.split('\t')
            if cited == citation:
                result.setdefault(id, []).append(location)
    return result


# The statuses of rows that are reviewed and apply to vsql, and so count towards
# how much is implemented.
APPLICABLE = ['implemented', 'untested', 'partial', 'missing', 'deviates']

# The statuses that are listed by the report, since they need attention.
ATTENTION = ['missing', 'partial', 'untested', 'deviates', 'unclear']


def report(only_part=None):
    editions = read_editions()
    attention = []
    print(f'{"":<28} {"rows":>6} {"reviewed":>9} {"implemented":>12} {"missing":>8} '
          f'{"n/a":>6} {"unclear":>8}')
    for part, edition in editions.items():
        if only_part and part != only_part:
            continue
        groups = {}
        for path in sorted(glob.glob(os.path.join(INDEX, f'part{part}', '*.txt'))):
            for id, (status, code, tests, note) in read_index_file(path).items():
                clause = id.split('/')[0].split('.')[0]
                key = f'Part {part}, clause {clause}' if only_part else f'Part {part}'
                groups.setdefault(key, []).append(status)
                if status in ATTENTION:
                    attention.append((part, id, status, note))
        for key, found in groups.items():
            print(report_line(key, found))
        if not only_part:
            continue
        print(report_line(f'Part {part}', [s for found in groups.values() for s in found]))

    for status in ATTENTION:
        rows = [a for a in attention if a[2] == status]
        if rows:
            print(f'\n{status} ({len(rows)}):')
            for part, id, _, note in rows:
                print(f'  Part {part}, {id:<24} {note}')


def report_line(name, statuses):
    """A line of the report. Reviewed is the percentage of rows that aren't
    todo (containers don't need a review). Implemented is the percentage of the
    reviewed rows that apply to vsql that are implemented (a partial row counts
    as half)."""
    count = {s: statuses.count(s) for s in STATUSES}
    to_review = len(statuses) - count['container']
    reviewed = to_review - count['todo']
    applicable = sum(count[s] for s in APPLICABLE)
    implemented = count['implemented'] + count['untested'] + count['partial'] / 2
    return (f'{name:<28} {len(statuses):>6} {percent(reviewed, to_review):>9} '
            f'{percent(implemented, applicable):>12} {count["missing"]:>8} '
            f'{count["n/a"]:>6} {count["unclear"]:>8}')


def percent(n, total):
    return f'{100 * n / total:.1f}%' if total else '-'


def set_rows(part, pattern, status, code, tests, note):
    if status not in STATUSES:
        sys.exit(f'unknown status: {status}')
    prefix = pattern.rstrip('*')
    path = os.path.join(INDEX, f'part{part}', file_for(prefix.split('/')[0]))
    lines = open(path).read().split('\n')
    changed = 0
    for i, line in enumerate(lines):
        if line.startswith('#') or not line.strip():
            continue
        id = line.split()[0]
        if id == prefix or (pattern.endswith('*') and
                            (id.startswith(prefix + '.') or id.startswith(prefix + '/'))):
            lines[i] = row(id, [status, code, tests, note])
            changed += 1
    if not changed:
        sys.exit(f'no rows match {pattern} in {path}')
    with open(path, 'w') as f:
        f.write('\n'.join(lines))


if __name__ == '__main__':
    if len(sys.argv) == 2 and sys.argv[1] == 'generate':
        generate()
    elif len(sys.argv) == 4 and sys.argv[1] == 'show':
        show(sys.argv[2], sys.argv[3])
    elif len(sys.argv) in (2, 3) and sys.argv[1] == 'report':
        report(sys.argv[2] if len(sys.argv) == 3 else None)
    elif len(sys.argv) in (7, 8) and sys.argv[1] == 'set':
        set_rows(*sys.argv[2:7], sys.argv[7] if len(sys.argv) == 8 else '')
    else:
        sys.exit(__doc__)
