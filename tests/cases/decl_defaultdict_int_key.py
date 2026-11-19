from collections import defaultdict

def lookup(values: defaultdict[int, int]) -> int:
    return values[5]

print(lookup({5: 17}))
