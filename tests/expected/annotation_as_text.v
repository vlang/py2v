module main

import pyrt.mcptypes
import pyrt

// TODO(py2v): no V equivalent for import mcp.types
// Provide one in python_to_v_import (types.v) or port the module.

fn many(text string, mode ?string) []&mcptypes.TextContent {
	if mode != none {
		return [mcptypes.new_text_content(type_: 'text', text: mode)]
	}
	return [mcptypes.new_text_content(type_: 'text', text: text)]
}

fn tools() []&mcptypes.Tool {
	return [mcptypes.new_tool(
		name:         'a'
		description:  'b'
		input_schema: pyrt.box({
			'type': 'object'
		})
	)]
}
