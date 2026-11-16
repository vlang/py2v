class Grid:
    def __getitem__(self, key: tuple[slice, int]) -> str:
        return f"{key[0].start}:{key[1]}"


g = Grid()
print(g[:, 1])
