def parse_digits(values: list[str], index: int, base: int) -> int:
    text = values[index]
    return int(text, base=base)


values = ["\u2002-0x_Ff\u3000", "0o_17", "٠b_١٠١", "00_0", "+1_0", "Z", "-8000_0000_0000_0000"]
bases = [0, 8, 0, 0, 2, 36, 16]
for index in range(len(values)):
    print(parse_digits(values, index, bases[index]))
print(int("0b1", 16))
print(int("00", 10))
print(int("1", int(True) + 1))
for invalid in ["01", "", "_0", "0x__f", "0b", "0o9", "0_xa", "10\x00", "3\x1c", "²"]:
    try:
        print(int(invalid, 0))
    except ValueError:
        print("invalid")
try:
    print(int("40", 37))
except ValueError:
    print("invalid base")
