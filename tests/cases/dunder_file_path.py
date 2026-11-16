def source_name() -> str:
    return __file__


path = source_name()
print(len(path) > 0)
print(path.endswith(".py") or path.endswith(".v"))
print(__file__ == path)
