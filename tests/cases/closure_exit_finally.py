from typing import Callable


def define_in_finally() -> int:
    try:
        return 5
    finally:
        def inner() -> int:
            try:
                return 7
            finally:
                print("inner cleanup")
        print(inner())


def make_exit() -> Callable[[], None]:
    try:
        def exit_later() -> None:
            print("inner exit")
            exit(0)
        return exit_later
    finally:
        print("outer cleanup")


print(define_in_finally())
delayed_exit = make_exit()
delayed_exit()
