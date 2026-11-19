from enum import Enum


class Flags(Enum):
    OFF = 0
    ON = 1

    @classmethod
    def choose(cls, active: bool):
        return cls.ON if active else cls.OFF


print(Flags.choose(True))
print(Flags.choose(False) is Flags.OFF)
