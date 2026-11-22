try:
    print(pow(base=2, exp=-1, mod=4))
except ValueError as problem:
    print(str(problem))

print(pow(mod=7, base=3, exp=4))
print(pow(base=5, mod=13, exp=3))
