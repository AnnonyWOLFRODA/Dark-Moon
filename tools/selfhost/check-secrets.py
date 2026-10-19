#!/usr/bin/env python3
"""Heuristic token-signature check; report locations only, never token values."""
from pathlib import Path
import re
import subprocess
import sys

SIGNATURE = re.compile(r'(?:sk-(?:proj-|ant-)?[A-Za-z0-9_-]{24,}|gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{30,})')


def main():
    files = subprocess.check_output(['git', 'ls-files', '-z', '--cached', '--others', '--exclude-standard'])
    found = []
    for name in set(files.decode().split('\0')) - {''}:
        path = Path(name)
        if path.is_symlink() or not path.is_file():
            continue
        try:
            text = path.read_text()
        except (UnicodeError, OSError):
            continue
        for lineno, line in enumerate(text.splitlines(), 1):
            if SIGNATURE.search(line):
                found.append(f'{name}:{lineno}')
    if found:
        print('Potential token signatures (values withheld):', *sorted(found), sep='\n', file=sys.stderr)
        return 1
    print('No known token signatures found; heuristic check only')
    return 0


if __name__ == '__main__':
    sys.exit(main())
