def loop(log: list[str]) -> None:
    try:
        log.append("start")
    finally:
        for name in ["a", "b"]:
            try:
                if name == "a":
                    continue
                log.append(name)
            finally:
                log.append("after " + name)


log: list[str] = []
loop(log)
print(log)
