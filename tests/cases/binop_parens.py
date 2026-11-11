def main():
    a = 7
    b = 3
    c = 2

    # Parentheses Python needs are kept
    print((a + b) * c)
    print(a - (b - c))
    print(a - (b + c))
    print(a * (b % c))
    print((a + b) % (b + c + 1))
    print(-(a - b) * c)
    print(~(a + b))
    print(+(b - a) * c)

    # V gives &, << and >> the precedence of *, and | and ^ that of +
    print(a + b << c)
    print(a << b + c)
    print(b & a + c)
    print(a | b ^ c)

    # No parentheses where V already groups the same way
    print(a * b + c)
    print(a - b - c)
    print(a ^ b & c)

    # Inside a call and before a method
    x = 7.5
    y = 2.5
    z = 3.0
    print((x + y) // z)
    s = "ab"
    t = "c"
    print((s + t) * 2)

    # `&`, `|` and `^` on bools become `&&`, `||` and `!=`, which V refuses to mix
    # unparenthesized
    p = True
    q = False
    r = True
    if p & (q or r):
        print("p and (q or r)")
    if (p and q) | r:
        print("(p and q) or r")
    if p ^ (a < b):
        print("p xor (a < b)")

    # An operation keeps its parentheses before a method, inside a comparison, inside
    # `and`/`or` and under a second minus
    print((s + (t + s)).upper())
    if p ^ ((q and r) == q):
        print("wrong")
    else:
        print("p xor ((q and r) == q) is false")
    if p and (q | r):
        print("p and (q or r), again")
    print(-(-a))

    # Lowerings that compose their own arithmetic: range() bounds and float //=
    total = 0
    for i in range(c - (b - a), a + 1):
        total += i
    print(total)
    w = 7.5
    w //= y - (z - y)
    print(w)

    # A builtin that indexes its argument, and an or-pattern inside a sequence pattern
    print(ord(t + ""))
    pair = [1, 7]
    match pair:
        case [1 | 2, 7]:
            print("pair matched")
        case _:
            print("pair missed")


if __name__ == "__main__":
    main()
