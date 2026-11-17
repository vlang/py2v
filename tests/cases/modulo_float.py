import math


def remainder(a: float, b: float) -> float:
    return a % b


def main():
    for a in [-7.5, 7.5, -6.0, 6.0, 0.0, -0.0]:
        for b in [3.0, -3.0]:
            result = remainder(a, b)
            print(result, math.copysign(1.0, result))
    value = -7.5
    value %= 3.0
    print(value)
    print(-7 % 3.5, 7.5 % -3)


if __name__ == "__main__":
    main()
