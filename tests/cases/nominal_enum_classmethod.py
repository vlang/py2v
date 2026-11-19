from enum import Enum


class Choice(Enum):
    NO = 0
    YES = 1

    @classmethod
    def pick(cls, accept: bool) -> "Choice":
        return cls.YES if accept else cls.NO


print(Choice.pick(True))
print(Choice.pick(False) is Choice.NO)
