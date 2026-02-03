def main():
    # Enumerate
    fruits = ["apple", "banana", "cherry"]
    for i, fruit in enumerate(fruits):
        print(i)
        print(fruit)

    # Zip
    names = ["Alice", "Bob"]
    ages = [25, 30]
    for name, age in zip(names, ages):
        print(name)
        print(age)


if __name__ == "__main__":
    main()
