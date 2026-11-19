class C:
    def __init__(self, py2v_dunder_payload: int):
        self.py2v_dunder_payload = py2v_dunder_payload

    def get(self) -> int:
        return self.py2v_dunder_payload

print(C(7).get())
