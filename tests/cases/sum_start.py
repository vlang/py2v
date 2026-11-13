def main():
    xs = [1, 2, 3]
    fs = [1.5, 2.5]
    base = 10
    step = 2
    print(sum(xs, 10))
    print(sum(xs, base))
    print(sum(fs, 0.5))
    print(sum(fs, 10))
    print(sum(fs, base))
    print(sum(xs, 0.5))
    print(sum(range(4), 3))
    print(sum(xs, 10) * 2)
    print(sum(xs, start=10))
    print(sum(xs, -1))
    print(sum(xs, base - step))


if __name__ == "__main__":
    main()
