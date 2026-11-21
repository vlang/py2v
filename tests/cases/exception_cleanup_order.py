def report(failure: bool) -> int:
    try:
        if failure:
            raise ValueError("broken")
        print("body")
    except ValueError as problem:
        print(problem)
        return 1
    else:
        print("else")
        return 2
    finally:
        print("cleanup")


print(report(False))
print(report(True))
