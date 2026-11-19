import os as paths
from os.path import dirname


def hook_dirs():
    return [paths.path.dirname(__file__)]


print(len(hook_dirs()))
print("[" + dirname("file.txt") + "]")
print(dirname("/a//b.txt"))
print(dirname("/a/b/"))
