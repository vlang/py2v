def echo(flag: bool) -> bool:
    print(str(flag), f"{flag!s}", f"{flag!r}", f"{flag!a}")
    return flag


flag = True
flag = False
print(str(flag), f"{flag}")
print(echo(True))
flags = [False, True]
print(str(flags[0]), f"{flags[1]}", f"{1 > 2}")
names = ["True"]
if str(flags[0]) not in names:
    print("False is absent")
