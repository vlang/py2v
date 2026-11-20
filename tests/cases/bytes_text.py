def echo(data: bytes) -> bytes:
    print(data, str(data), f"{data!r}")
    return data


raw = b"'\xff\n\t\r\x00\\"
print(echo(raw))
print(echo(b"""a'b"c"""))
print("é".encode(), b"")
