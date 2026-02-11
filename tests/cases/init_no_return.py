class Thing:
    x: int

    def __init__(self, x):
        self.x = x


if __name__ == "__main__":
    t = Thing(1)
    print(t.x)
