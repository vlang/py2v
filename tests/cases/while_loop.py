def main():
    # Simple while loop
    i = 0
    while i < 5:
        print(i)
        i += 1

    # While with break
    j = 0
    while True:
        if j >= 3:
            break
        print(j)
        j += 1

    # While with continue
    k = 0
    while k < 5:
        k += 1
        if k == 3:
            continue
        print(k)


if __name__ == "__main__":
    main()
