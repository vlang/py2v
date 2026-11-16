def run(log: list[str]) -> int:
    try:
        log.append("body")
        return 1
    finally:
        try:
            log.append("cleanup")
        finally:
            log.append("close")


def loop(log: list[str]) -> None:
    try:
        log.append("start")
    finally:
        for name in ["a", "b"]:
            try:
                for part in [name, "x"]:
                    if part == "x":
                        break
                    log.append(part)
            finally:
                log.append("after " + name)


log: list[str] = []
print(run(log), log)
loop(log)
print(log)
