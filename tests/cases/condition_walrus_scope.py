def checked(value: int) -> int:
    print("check", value)
    return value


def yes() -> bool:
    print("yes")
    return True


def loop_case():
    for i in range(2):
        if not ((saved := checked(i)) < 0):
            print("loop", saved)
    print("loop-after", saved)


def nested_case():
    outer = True
    if outer:
        if (inner := yes()):
            print("nested", inner)
    print("nested-after", inner)


class Gate:
    enabled: bool

    def __init__(self, enabled: bool):
        self.enabled = enabled

    def ready(self) -> bool:
        print("ready")
        return self.enabled

    def show(self):
        if (value := self.ready()):
            print("method", value)
        else:
            print("closed", value)
        print("method-after", value)


gate = Gate(True)
gate.show()
loop_case()
nested_case()
if (module_value := yes()):
    print("module", module_value)
print("module-after", module_value)
