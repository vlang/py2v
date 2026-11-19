class C:
    def __init__(self, py2v_numeric_marker: int):
        self.py2v_numeric_marker = py2v_numeric_marker

    def get(self) -> int:
        return self.py2v_numeric_marker

print(C(17).get())
