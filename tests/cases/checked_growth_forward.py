def twice(x: int) -> int:
    return x + x


def forward(x: int) -> int:
    return twice(x)


def add(x: int, y: int) -> int:
    return x + y


def next_value(x: int) -> int:
    return add(x, x)


a = 1
for i in range(5):
    a = forward(a)
print(a)

b = 1
for i in range(5):
    b = next_value(b)
print(b)
