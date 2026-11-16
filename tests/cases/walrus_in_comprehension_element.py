names = ["a-1", "b-x", "c-22"]
print(sum(int(last) if (last := n.split("-")[-1]).isdigit() else 0 for n in names))
print([len(n) + (size := len(n)) for n in names])
