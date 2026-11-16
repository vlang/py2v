module pyrt

// Companion to the user's existing dyn.v, deliberately placed in its own
// file so that their already-working item_at/set_index/elements/length/has
// implementations remain untouched. Both files compile into module pyrt.
pub fn method(v Value, name string, args []Value) Value {
    return call_method(v, name, args) or { panic(err.msg()) }
}
