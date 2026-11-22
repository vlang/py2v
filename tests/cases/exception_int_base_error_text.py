try:
    print(int("invalid", base=2))
except ValueError as problem:
    print(str(problem))

try:
    print(int("1_2__3", 10))
except Exception as problem:
    print(str(problem))

try:
    print(int("a'b", 16))
except (ValueError, TypeError) as problem:
    print(str(problem))

try:
    print(int("a\n", 2))
except ValueError as problem:
    print(str(problem))

try:
    print(int("\u2002", 10))
except ValueError as problem:
    print(str(problem))
