def presentation(value: int) -> str:
    return f"{value:08b} {value:+#010x} {value:*>+#10o} {value:^12X}"


values = [0, 7, -42, 999999]
for n in values:
    print(presentation(n))
    print(format(n, "#018_b"))
    print(f"[{n:*>12_b}][{n:#_X}][{n:é^15o}][{bin(n)}]")
print(f"{True:#08b}")
print(f"{9223372036854775808:#018X}")
