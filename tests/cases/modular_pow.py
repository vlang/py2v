def residue(base: int, exponent: int, modulus: int) -> int:
    return pow(base, exponent, modulus)


values = [7, -4, 123456789123456789, 9223372036854775783]
print(residue(values[0], values[1], 13))
print(residue(values[2], 547, values[3]))
print(residue(-2, 3, -5))
print(pow(1, -9223372036854775808, -7))
print(residue(0, -1, 1))
print(pow(True, False, 4))
try:
    residue(2, 5, 0)
except ValueError as exc:
    print(str(exc))
try:
    print(pow(2, -1, 4))
except ValueError as exc:
    print(str(exc))
