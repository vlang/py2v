#!/usr/bin/env python3
"""Test re module → regex module translations."""

import re

# Basic pattern matching
pattern = re.compile(r'\d+')
text = 'hello 42 world'

# re.match - match at start
m = re.match(r'hello', text)

# re.search - search anywhere
s = re.search(r'\d+', text)

# re.findall - find all matches
matches = re.findall(r'\d+', text)

# re.sub - replace
result = re.sub(r'\d+', 'NUM', text)

# re.split - split by pattern
parts = re.split(r'\s+', text)

# re.fullmatch - full string match
fm = re.fullmatch(r'hello \d+ world', text)

print(result)

