#!/usr/bin/env python3

import os
import tempfile


def write_and_read():
    """File handles in with statements should get defer close."""
    path = tempfile.mktemp()
    with open(path, "w") as f:
        f.write("hello world")

    with open(path, "r") as f:
        data = f.read()
        print(data)

    os.remove(path)


def nested_files():
    """Nested with-open blocks each get their own defer."""
    path1 = "a.txt"
    path2 = "b.txt"
    with open(path1, "w") as f1:
        f1.write("file1")
        with open(path2, "w") as f2:
            f2.write("file2")


if __name__ == "__main__":
    write_and_read()
    nested_files()
