module main

import os

fn match_value() string {
	match py2v_unsupported_assignment_expression('value', os.input('')) {
		'yes' {
			return value
		}
		else {
			return 'other'
		}
	}
}
