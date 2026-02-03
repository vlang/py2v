def with_finally(x: int) -> int:
    result = 0
    try:
        result = x * 2
    finally:
        print("finally executed")
    return result


def main():
    print(with_finally(5))
    print(with_finally(10))

    # Try-except-finally
    try:
        x = 10
        print(x)
    except:
        print("error")
    finally:
        print("cleanup")


if __name__ == "__main__":
    main()
