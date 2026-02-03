def main():
    # Nested for loops
    for i in range(3):
        for j in range(3):
            print(i * 3 + j)

    # Nested loops with break
    for i in range(5):
        for j in range(5):
            if j == 2:
                break
            print(i * 10 + j)


if __name__ == "__main__":
    main()
