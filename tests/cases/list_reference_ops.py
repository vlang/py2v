from typing import Any

def touch(values: Any):
    values.append(3)

def main():
    a = [1]
    b = a
    b.append(2)
    print(f"a={a}")
    print(repr(a), f"{a!r}")
    print(isinstance(a, list), bool(a), not a)
    if a:
        print("truth")
    print(a.index(2), a.count(2))
    c = [7]
    touch(c)
    print(c)
    words = ["a"]
    other = words
    other.append("b")
    print(" ".join(words))

if __name__ == '__main__':
    main()
