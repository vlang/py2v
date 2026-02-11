@[translated]
module main

__global (
	a = default_value(int)
	b = default_value(int)
	c = default_value(int)
)
pub struct TriangleType {
pub mut:
	EQUILATERAL int
	ISOSCELES   int
	RIGHT       int
	ACUTE       int
	OBTUSE      int
	ILLEGAL     int
}

fn classify_triangle_correct(a int, b int, c int) TriangleType {
	if a == b && b == c {
		return TriangleType.EQUILATERAL
	} else if a == b || b == c || a == c {
		return TriangleType.ISOSCELES
	} else if a >= b && a >= c {
		if (a * a) == ((b * b) + (c * c)) {
			return TriangleType.RIGHT
		} else if (a * a) < ((b * b) + (c * c)) {
			return TriangleType.ACUTE
		} else {
			return TriangleType.OBTUSE
		}
	} else if b >= a && b >= c {
		if (b * b) == ((a * a) + (c * c)) {
			return TriangleType.RIGHT
		} else if (b * b) < ((a * a) + (c * c)) {
			return TriangleType.ACUTE
		} else {
			return TriangleType.OBTUSE
		}
	} else if (c * c) == ((a * a) + (b * b)) {
		return TriangleType.RIGHT
	} else if (c * c) < ((a * a) + (b * b)) {
		return TriangleType.ACUTE
	} else {
		return TriangleType.OBTUSE
	}
}

fn classify_triangle(a int, b int, c int) TriangleType {
	if smt_pre {
		assert a > 0
		assert b > 0
		assert c > 0
		assert a < (b + c)
	}

	if a >= b && b >= c {
		if a == c || b == c {
			if a == b && a == c {
				return TriangleType.EQUILATERAL
			} else {
				return TriangleType.ISOSCELES
			}
		} else if (a * a) != ((b * b) + (c * c)) {
			if (a * a) < ((b * b) + (c * c)) {
				return TriangleType.ACUTE
			} else {
				return TriangleType.OBTUSE
			}
		} else {
			return TriangleType.RIGHT
		}
	} else {
		return TriangleType.ILLEGAL
	}
}

fn main() {
	assert !(classify_triangle_correct(a, b, c) == classify_triangle(a, b, c))
	check_sat()
	get_model()
}
