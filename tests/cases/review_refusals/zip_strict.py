try:
    for number, text in zip([1, 2], ["a"], strict=True):
        print(f"{number}:{text}")
except ValueError:
    print("different lengths")
