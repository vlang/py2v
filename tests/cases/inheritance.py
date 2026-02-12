class Animal:
    name: str
    sound: str


class Dog(Animal):
    breed: str


if __name__ == "__main__":
    d = Dog(name="Buddy", sound="Woof", breed="Labrador")
    print(d.name)
    print(d.sound)
    print(d.breed)
