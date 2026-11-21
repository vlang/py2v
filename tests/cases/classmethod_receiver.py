from dataclasses import dataclass

@dataclass
class Piece:
    code: int

    @classmethod
    def null(cls) -> "Piece":
        return cls(0)

    @classmethod
    def from_code(owner, code: int) -> "Piece":
        if code == 0:
            return owner.null()
        return owner(code)

if __name__ == "__main__":
    print(Piece.from_code(0).code)
    print(Piece.from_code(7).code)
