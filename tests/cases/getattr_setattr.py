#!/usr/bin/env python3
class Config:
    debug: bool = False
    level: int = 1
def show():
    c = Config()
    setattr(c, 'debug', True)
    val = getattr(c, 'debug')
    print(val)
    print(hasattr(c, 'level'))
    name = getattr(c, 'missing', 'default')
    print(name)
if __name__ == "__main__":
    show()
