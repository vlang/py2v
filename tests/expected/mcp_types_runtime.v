module main

import pyrt.mcptypes
import pyrt

// TODO(py2v): no V equivalent for import mcp.types
// Provide one in python_to_v_import (types.v) or port the module.

type Any = pyrt.Value

fn reply(text string) []&mcptypes.TextContent {
	return [mcptypes.new_text_content(type_: 'text', text: text)]
}

fn describe() &mcptypes.Tool {
	return mcptypes.new_tool(
		name:         'echo'
		description:  'Echo a word'
		input_schema: pyrt.box({
			'type':       pyrt.box('object')
			'properties': pyrt.box(map[string]Any{
				'word': pyrt.box(map[string]Any{
					'type': pyrt.box('string')
				})
			})
		})
	)
}

fn main_func() {
	out := reply('done')
	println('${out[0].kind} ${out[0].text}')
	tool := describe()
	println('${tool.name} ${tool.description}')
}

fn main() {
	main_func()
}
