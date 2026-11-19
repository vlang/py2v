from collections import defaultdict as DD

def lookup(values: DD[int, int]) -> int:
    return values[5]

print(lookup({5: 17}))
