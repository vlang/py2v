def build(a, b, c, d, e, f, g, h, i, j, k, l):
    items = [
        "aaaaaaaaaa",
        "bbbbbbbbbb",
        "cccccccccc",
        "dddddddddd",
        "eeeeeeeeee",
        "ffffffffff",
        "gggggggggg",
        "hhhhhhhhhh",
        "iiiiiiiiii",
        "jjjjjjjjjj",
        "kkkkkkkkkk",
        "llllllllll",
        "mmmmmmmmmm",
        "nnnnnnnnnn",
    ]
    text = f"prefix-{a}-{b}-{c}-{d}-{e}-{f}-{g}-{h}-{i}-{j}-{k}-{l}-suffix"
    return items, text


if __name__ == "__main__":
    out = build(1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12)
    print(out[0][0])
    print(out[1])
