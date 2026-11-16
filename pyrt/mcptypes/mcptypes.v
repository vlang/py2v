module mcptypes

import pyrt

// mcp.types accepts extra fields and performs Pydantic validation; this small
// replacement deliberately models only the fields requested by the project.
// `type` is reserved in V: a TextContent's V field is `kind`.
@[params]
pub struct TextContentOptions {
pub:
    type_ string = 'text'
    text string
}

@[params]
pub struct ToolOptions {
pub:
    name string
    description string
    input_schema pyrt.Value = pyrt.none_
}

pub struct TextContent {
mut:
    identity i64
pub mut:
    kind string = 'text'
    text string
}

pub struct Tool {
mut:
    identity i64
pub mut:
    name string
    description string
    input_schema pyrt.Value = pyrt.none_
}

pub fn new_text_content(opts TextContentOptions) &TextContent {
    return &TextContent{kind: opts.type_, text: opts.text, identity: pyrt.identity_token()}
}

pub fn new_tool(opts ToolOptions) &Tool {
    return &Tool{name: opts.name, description: opts.description,
        input_schema: opts.input_schema, identity: pyrt.identity_token()}
}

pub fn (c &TextContent) class_name() string { return 'TextContent' }
pub fn (c &TextContent) pyrt_identity() i64 { return c.identity }
pub fn (c &TextContent) as_value() pyrt.Value { return pyrt.Value(pyrt.Instance(c)) }

pub fn (c &TextContent) getattr(name string) !pyrt.Value {
    if name == 'type' { return pyrt.Value(c.kind) }
    if name == 'text' { return pyrt.Value(c.text) }
    return pyrt.raise('AttributeError', "'TextContent' object has no attribute '${name}'")
}

pub fn (mut c TextContent) setattr(name string, value pyrt.Value) ! {
    if name == 'type' { c.kind = pyrt.as_str(value)!; return }
    if name == 'text' { c.text = pyrt.as_str(value)!; return }
    return pyrt.raise('AttributeError', "'TextContent' object has no attribute '${name}'")
}

pub fn (c &TextContent) model_dump() pyrt.Value {
    d := pyrt.new_dict()
    pyrt.setitem(pyrt.Value(d), pyrt.Value('type'), pyrt.Value(c.kind)) or { panic(err.msg()) }
    pyrt.setitem(pyrt.Value(d), pyrt.Value('text'), pyrt.Value(c.text)) or { panic(err.msg()) }
    return pyrt.Value(d)
}

pub fn (t &Tool) class_name() string { return 'Tool' }
pub fn (t &Tool) pyrt_identity() i64 { return t.identity }
pub fn (t &Tool) as_value() pyrt.Value { return pyrt.Value(pyrt.Instance(t)) }

pub fn (t &Tool) getattr(name string) !pyrt.Value {
    if name == 'name' { return pyrt.Value(t.name) }
    if name == 'description' { return pyrt.Value(t.description) }
    if name == 'inputSchema' { return t.input_schema }
    return pyrt.raise('AttributeError', "'Tool' object has no attribute '${name}'")
}

pub fn (mut t Tool) setattr(name string, value pyrt.Value) ! {
    if name == 'name' { t.name = pyrt.as_str(value)!; return }
    if name == 'description' { t.description = pyrt.as_str(value)!; return }
    if name == 'inputSchema' { t.input_schema = value; return }
    return pyrt.raise('AttributeError', "'Tool' object has no attribute '${name}'")
}

pub fn (t &Tool) model_dump() pyrt.Value {
    d := pyrt.new_dict()
    pyrt.setitem(pyrt.Value(d), pyrt.Value('name'), pyrt.Value(t.name)) or { panic(err.msg()) }
    pyrt.setitem(pyrt.Value(d), pyrt.Value('description'), pyrt.Value(t.description)) or { panic(err.msg()) }
    pyrt.setitem(pyrt.Value(d), pyrt.Value('inputSchema'), t.input_schema) or { panic(err.msg()) }
    return pyrt.Value(d)
}
