def show(price: float, count: int, name: str) -> str:
    return f"{name:<8}|{count:>5}|{price:>10,.2f}"


tie = 0.125
half = 2.5
big = 1e22
small = -0.001
ratio = 0.4567
n = 1234567
neg = -42
word = "héllo"

print(f"{tie:.2f} {half:.0f} {big:.2f} {small:.1f}")
print(f"{ratio:.1%} {ratio:+.0%} {n:g} {ratio:.3e} {n:,.0f}")
print(f"[{half:+08.2f}] [{half:*^9.1f}] [{half:<7.1f}] [{half:=+9.1f}]")
print(f"{n:,} {n:+,} {n:_} {neg:05d} {neg:>6} {7:03d} {neg:+d}")
print(f"[{word:>8}] [{word:^9}] [{word:*<7}] [{word:.3s}]")
print(show(1234.5, 3, "apples"))
