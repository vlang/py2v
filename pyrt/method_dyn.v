module pyrt

// Kept apart from dyn.v, so that its item_at/set_index/elements/length/has
// implementations stay as they are. Both files compile into module pyrt.
pub fn method(v Value, name string, args []Value) Value {
    return call_method(v, name, args) or { panic(err.msg()) }
}
