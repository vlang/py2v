@[translated]

module main

import math

fn complex_test() {
	c1 := 2 + math.complex(0.0, 3.0)
	c2 := 4 + math.complex(0.0, 5.0)
	c3 := c1 + c2
	assert c3 == 6 + math.complex(0.0, 8.0)
	c4 := c1 + 3
	assert c4 == 5 + math.complex(0.0, 3.0)
	c5 := c1 + math.complex(0.0, 4.0)
	assert c5 == 2 + math.complex(0.0, 7.0)
	c6 := c3 - 2.3
	assert c6 == 3.7 + math.complex(0.0, 8.0)
}

fn main() {
	complex_test()
	println('OK')
}
