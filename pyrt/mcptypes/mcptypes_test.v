module mcptypes

import pyrt

fn test_text_content_fields_and_dump() {
    c := new_text_content(type_: 'text', text: 'hello')
    // python: {'type': 'text', 'text': 'hello'}['type'] == 'text'
    assert c.kind == 'text'
    // python: {'type': 'text', 'text': 'hello'}['text'] == 'hello'
    assert c.text == 'hello'
    d := c.model_dump()
    // python: {'type': 'text', 'text': 'hello'}['text'] == 'hello'
    assert pyrt.as_str(pyrt.getitem(d, pyrt.Value('text')) or { panic(err.msg()) }) or { '' } == 'hello'
    // python: isinstance({'type':'text','text':'hello'}, dict)
    assert d is &pyrt.Dict
    // MCP SDK's Pydantic validation is intentionally not tested without SDK.
}

fn test_tool_fields_and_instance() {
    schema := pyrt.new_dict()
    pyrt.setitem(pyrt.Value(schema), pyrt.Value('type'), pyrt.Value('object')) or { panic(err.msg()) }
    t := new_tool(name: 'lookup', description: 'Find data', input_schema: pyrt.Value(schema))
    // python: {'name':'lookup', 'description':'Find data'}['name'] == 'lookup'
    assert t.name == 'lookup'
    // python: {'name':'lookup', 'description':'Find data'}['description'] == 'Find data'
    assert t.description == 'Find data'
    // python: {'type':'object'}['type'] == 'object'
    assert pyrt.as_str(pyrt.getitem(t.input_schema, pyrt.Value('type')) or { panic(err.msg()) }) or { '' } == 'object'
    dumped := t.model_dump()
    // python: {'name':'lookup','description':'Find data'}['name'] == 'lookup'
    assert pyrt.as_str(pyrt.getitem(dumped, pyrt.Value('name')) or { panic(err.msg()) }) or { '' } == 'lookup'
    // python: isinstance({'name':'lookup'}, dict)
    assert dumped is &pyrt.Dict
    boxed := t.as_value()
    // python: {'name':'lookup'}['name'] == 'lookup'
    assert pyrt.as_str(pyrt.getattr(boxed, 'name') or { panic(err.msg()) }) or { '' } == 'lookup'
}
