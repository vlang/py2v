# Verify the unsupported deletion comment does not register a dead slice helper.
# This fixture checks code generation only, not slice deletion semantics.
values = [0, 1, 2, 3, 4]
print(len(values))
del values[::2]
print('reached')
