@[translated]
module main

pub struct Packet {
pub mut:
	val f64
}

pub struct Register {
pub mut:
	PACKET &Packet
	VALUE  int
}

fn main() {
	a := Register.VALUE(10)
	assert a.is_value()
	a.value()
	b := Register.PACKET(Packet{
		val: 1.3
	})
	assert b.is_packet()
	b.packet()
	println('OK')
}
