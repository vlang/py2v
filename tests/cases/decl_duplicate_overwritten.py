class Sample:
    def value(self):
        return 1

    alias = value

    def value(self):
        return 2

    def alias(self):
        return 3


sample = Sample()
print(sample.value())
print(sample.alias())
