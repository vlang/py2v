try:
    for index, value in enumerate([1, 2], start=1.0):
        print(index, value)
except TypeError:
    print("invalid")
