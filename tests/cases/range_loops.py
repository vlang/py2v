def main():
    # Simple range
    for i in range(3):
        print(i)

    # Range with start and end
    for i in range(2, 5):
        print(i)

    # Range with step
    for i in range(0, 10, 2):
        print(i)

    # Negative step (countdown)
    for i in range(5, 0, -1):
        print(i)


if __name__ == "__main__":
    main()
