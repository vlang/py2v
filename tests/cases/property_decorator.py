class Temperature:
    def __init__(self, celsius: float):
        self._celsius = celsius

    @property
    def celsius(self) -> float:
        return self._celsius

    @celsius.setter
    def celsius(self, value: float):
        self._celsius = value


if __name__ == "__main__":
    t = Temperature(25.0)
    print(t.celsius)
    t.set_celsius(30.0)
    print(t.celsius)
