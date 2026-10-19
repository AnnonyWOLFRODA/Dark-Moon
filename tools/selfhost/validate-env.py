#!/usr/bin/env python3
"""Validate raw Compose env_file without shell execution or interpolation."""
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile

def parse(path):
    result = {}
    for line in Path(path).read_text().splitlines():
        if not line.strip() or line.lstrip().startswith('#'):
            continue
        key, sep, value = line.partition('=')
        if not sep or not re.fullmatch(r'[A-Z][A-Z0-9_]*', key) or key in result:
            raise ValueError('Invalid or duplicate dotenv name')
        # The lab uses Compose format: raw. Values, including quotes and $, are literal.
        if any(ord(c) < 32 for c in value):
            raise ValueError('Invalid dotenv value')
        if not (key.startswith(('OPENCODE_', 'OPENROUTER_', 'ANTHROPIC_'))):
            raise ValueError('Unsupported dotenv name')
        if key in ('OPENCODE_CONFIG_DIR', 'OPENCODE_AUTH_DIR'):
            raise ValueError('Path overrides are not supported in provider env files')
        result[key] = value
    return result

def main():
    values = parse(sys.argv[1])
    with tempfile.TemporaryDirectory() as tmp:
        env = {'PATH': os.environ['PATH'], **values,
               'OPENCODE_CONFIG_DIR': tmp + '/config', 'OPENCODE_AUTH_DIR': tmp + '/auth'}
        subprocess.run(['bash', str(Path(__file__).resolve().parents[2] / 'conf/apply-settings.sh')],
                       env=env, check=True)

if __name__ == '__main__':
    try:
        main()
    except (ValueError, OSError, subprocess.CalledProcessError):
        sys.exit('Invalid provider file; values withheld')
