def evaluate(divisor: int, index: int) -> None:
    try:
        print(8 / divisor)
    except ArithmeticError as problem:
        print(problem)

    try:
        print([1, 2][index])
    except IndexError as problem:
        print(problem)


evaluate(0, 2)
evaluate(4, -1)
