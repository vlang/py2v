#!/usr/bin/env python3
"""Test itertools module translations."""

import itertools

nums = [1, 2, 3]
letters = ['a', 'b']

# chain: concatenate iterables
chained = list(itertools.chain(nums, letters))

# islice: take first n items
sliced = list(itertools.islice(nums, 2))

# repeat: repeat a value n times
repeated = list(itertools.repeat(7, 3))

# product: cartesian product
pairs = list(itertools.product(nums, letters))

print(chained)
print(sliced)
print(repeated)

