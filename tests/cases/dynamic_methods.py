#!/usr/bin/env python3


def describe(record, words):
    name = record.get("name", "nobody")
    tags = record.get("tags")
    if tags:
        print(name.upper(), len(tags))
    else:
        print(name, "no tags")
    if record.get("missing"):
        print("unexpected")
    words.append("end")
    for key in record.keys():
        print(key)
    return len(words)


def first_word(text):
    parts = text.strip().split(" ")
    return parts[0]


def count_of(items, wanted):
    return items.count(wanted) + 1


if __name__ == "__main__":
    print(describe({"name": "ada", "tags": ["x", "y"]}, ["a"]))
    print(describe({"tags": []}, ["a", "b"]))
    print(first_word("  hello there "))
    print(count_of([1, 2, 1], 1))
