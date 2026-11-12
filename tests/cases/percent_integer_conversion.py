def main() -> None:
    amount: float = 2.9
    negative: float = -2.9
    print("%d %i" % (amount, negative))
    print("[%5d][%05d][%-5d]" % (amount, amount, amount))
    print("%d %i" % (True, False))
    print("%s %d %f %i" % ("tag", amount, amount, True))
    print("%d" % 4294967296.5)
    small: "f32" = 2.9
    print("%d" % small)
    print("%d" % 23)


if __name__ == "__main__":
    main()
