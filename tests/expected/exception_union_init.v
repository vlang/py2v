@[translated]
module main

__global (
	__all__ = ['BarException', 'WebDriverException', 'FooException', 'Other']
)

type WebDriverExceptions = BarException | WebDriverException | FooException
