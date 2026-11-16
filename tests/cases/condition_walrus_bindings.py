def parameter(flag: bool):
    if (flag := True):
        print("parameter", flag)


def loop_binding():
    for flag in [False, False]:
        if (flag := True):
            print("loop", flag)
    print("loop-after", flag)


def ignored():
    if (_ := True):
        print("underscore", _)


def inferred():
    if (answer := True):
        return answer
    return False


if (module_flag := True):
    print("module-set")


if __name__ == "__main__":
    caller = False
    parameter(caller)
    print("caller", caller)
    loop_binding()
    ignored()
    print(inferred())
    print(module_flag)
