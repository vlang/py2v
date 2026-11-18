from typing import Any
def inspect(v: Any):
    print(v == v, v is v)
a=[1]
b=a
inspect(a)
print(b)
