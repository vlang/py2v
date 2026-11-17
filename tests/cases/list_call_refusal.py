def main():
    change = lambda values: values.append(2)
    a = [1]
    change(a)
    print(a)


if __name__ == "__main__":
    main()
