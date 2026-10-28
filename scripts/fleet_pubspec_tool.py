#!/usr/bin/env python3
"""fleet_pubspec_tool.py — one idempotent pass over a fleet pubspec.

Usage:
  fleet_pubspec_tool.py <pubspec.yaml> --version 7.2.0 \
      --constraint <pkgname> [...pkgname...] \
      --xml 7.1.0 \
      [--sibling <dep>=<relpath> ...]

Operations (all inside this one file, preserving comments and key order):
  1. `version:` -> --version
  2. every single-line `<pkg>: ^x.y.z` constraint for the named fleet
     packages -> `^--version` (path blocks `pkg:` + `path:` are untouched)
  3. ensure `xml: <value>` inside dependency_overrides (creating the
     section at EOF when the pubspec has none)
  4. ensure `dep: path: relpath` for each --sibling, INSIDE the overrides
     section — never appended at EOF, where the lines would parse as part
     of whatever top-level mapping follows the section.

Idempotent: running twice produces a byte-identical file.
"""
import argparse
import os
import re
import sys


def section_span(lines):
    """Index of `dependency_overrides:` and its exclusive end, or (None, None)."""
    start = None
    for i, line in enumerate(lines):
        if re.match(r'^dependency_overrides:\s*$', line):
            start = i
            break
    if start is None:
        return None, None
    end = len(lines)
    for i in range(start + 1, len(lines)):
        if lines[i] and not lines[i].startswith((' ', '\t', '#')):
            end = i
            break
    return start, end


def section_keys(lines, start, end):
    keys = set()
    for line in lines[start + 1:end]:
        m = re.match(r'^  ([\w][\w-]*):\s*$', line)
        if m:
            keys.add(m.group(1))
    return keys


def update_xml(lines, start, end, value):
    for i in range(start + 1, end):
        if re.match(r'^  xml\s*:.*$', lines[i]):
            lines[i] = f'  xml: {value}'
            return
    lines.insert(end, f'  xml: {value}')


def insert_entry(lines, start, end, key, body_lines):
    """Insert `key:` + body_lines at the end of the overrides section."""
    lines[end:end] = [f'  {key}:'] + body_lines


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('pubspec')
    ap.add_argument('--version', required=True)
    ap.add_argument('--constraint', nargs='+', action='extend', default=[])
    ap.add_argument('--xml', default=None)
    ap.add_argument('--sibling', action='append', default=[],
                    help='dep=relative/path/to/dep/checkout')
    args = ap.parse_args()

    path = args.pubspec
    with open(path) as f:
        lines = f.read().split('\n')

    # 1. version
    for i, line in enumerate(lines):
        if re.match(r'^version:', line):
            lines[i] = f'version: {args.version}'
            break

    # 2. fleet constraints (single-line forms only)
    for pkg in args.constraint:
        pat = re.compile(
            r'^([ \t]*' + re.escape(pkg) + r':[ \t]*)\^?[0-9]+(\.[0-9]+)+[ \t]*(#.*)?$')
        for i, line in enumerate(lines):
            m = pat.match(line)
            if m:
                comment = f'  {m.group(3)}' if m.group(3) else ''
                lines[i] = f'{m.group(1)}^{args.version}{comment}'

    start, end = section_span(lines)

    # 3+4. overrides section
    needs_section = args.xml is not None or args.sibling
    if start is None and needs_section:
        while lines and lines[-1] == '':
            lines.pop()
        lines += ['',
                  '# Fleet dev policy: xml pinned to the latest release; sibling fleet',
                  '# checkouts resolve not-yet-published constraints locally.',
                  '# dependency_overrides are stripped on publish.',
                  'dependency_overrides:']
        start, end = len(lines) - 1, len(lines)

    if start is not None:
        if args.xml is not None:
            update_xml(lines, start, end, args.xml)
        existing = section_keys(lines, start, end)
        for sib in args.sibling:
            dep, _, rel = sib.partition('=')
            if not _ or dep in existing:
                continue
            insert_entry(lines, start, end, dep, [f'    path: {rel}'])
            existing.add(dep)

    with open(path, 'w') as f:
        text = '\n'.join(lines)
        if not text.endswith('\n'):
            text += '\n'
        f.write(text)


if __name__ == '__main__':
    main()
