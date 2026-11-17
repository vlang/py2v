def probe(label: str) -> str:
    print(label)
    return label


if __name__ == "__main__":
    print(0 or 7)
    print(3 and 9)
    print(-1 or 3)
    print(-0.0 or 2.5)
    print(-0.0 and 9.0)
    print(2.0 or 3.5)
    print("" or "fallback")
    print(True or probe("skip-or"))
    print(False and probe("skip-and"))
    print(False or probe("run-or"))
    print(None and probe("skip-none"))
    print(not None)
    if None:
        print("bad-none")
    else:
        print("none")
    if []:
        print("bad-list")
    else:
        print("empty-list")
    while ():
        print("bad-tuple")
