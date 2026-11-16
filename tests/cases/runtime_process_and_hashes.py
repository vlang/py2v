import base64
import hashlib
import subprocess
import uuid


def digest(text: str) -> str:
    h = hashlib.sha256()
    h.update(text.encode())
    return h.hexdigest()


def run_echo(word: str) -> str:
    result = subprocess.run(["echo", word], capture_output=True, text=True)
    if result.returncode != 0:
        return "failed: " + result.stderr
    return result.stdout.strip()


def main() -> None:
    print(digest("hello"))
    print(hashlib.md5(b"abc").hexdigest())
    print(run_echo("hi"))
    print(base64.b64encode(b"hello").decode())
    print(len(str(uuid.uuid4())))


if __name__ == "__main__":
    main()
