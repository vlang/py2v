@[translated]
module main

pub struct Animal {
pub mut:
	name  string
	sound string
}

pub struct Dog {
	Animal
pub mut:
	breed string
}

fn main() {
	d := Dog{
		breed:  'Labrador'
		Animal: Animal{
			name:  'Buddy'
			sound: 'Woof'
		}
	}
	println((d.name).str())
	println((d.sound).str())
	println((d.breed).str())
}
