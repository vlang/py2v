def main() -> None:
    for x in [1, 2, 3]:
        if x == 2:
            print("found", x)
            break
    else:
        print("missing")

    for x in [1, 2, 3]:
        if x == 5:
            break
    else:
        print("no 5")

    for i in range(4):
        for j in range(4):
            if j > i:
                break
        else:
            print("inner done", i)
        if i == 2:
            break
    else:
        print("outer done")

    n = 5
    while n > 0:
        n -= 1
        if n == 2:
            print("stopped at", n)
            break
    else:
        print("ran out")

    k = 0
    while k < 3:
        k += 1
    else:
        print("counted", k)


if __name__ == "__main__":
    main()
