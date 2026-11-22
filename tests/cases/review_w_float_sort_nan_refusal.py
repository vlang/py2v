def identity(x: float) -> float:
    return x

def main() -> None:
    numbers = [3.0, float('nan'), 2.0, 1.0, -1.0, 0.0]
    print(sorted(numbers, key=identity))

if __name__ == '__main__':
    main()
