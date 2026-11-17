def main():
    a = [1, 2]
    rows = [a]
    rows[0].append(3)
    print(a)
    a.append(4)
    print(rows[0])
    records = {"row": a}
    records["row"].append(5)
    print(a, rows[0])


if __name__ == "__main__":
    main()
