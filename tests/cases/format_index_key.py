def main() -> None:
    d = {"k": "K", "j": "J", "my key": "S", " k ": "W"}
    xs = [10, 20]
    rows = [d]
    print("{0[k]} {0[j]}".format(d))
    print("{d[k]}".format(d=d))
    print("{0[my key]}".format(d))
    print("{0[ k ]}".format(d))
    print("{0[0]} {0[1]}".format(xs))
    print("{0[0][k]}".format(rows))
    index = 0
    if index < 0:
        print("{0[index]}".format(xs))


if __name__ == "__main__":
    main()
