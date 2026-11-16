module re

import regex.pcre
import pyrt

// Capture-free atoms still use the supplied engine. This small backtracking
// machine records group spans itself, so an UNSET capture cannot turn a valid
// match into none in the PCRE wrapper. No unlisted PCRE functions are used.
// Unsupported capturing grammar is rejected; group-free native fallback
// remains available. See README_ROUND5 for the exact supported subset.
enum CaptureKind {
    empty
    atom
    sequence
    alternate
    group
    repeat
    start_line
    end_line
    start_text
    end_text
    boundary
    nonboundary
    backref
}

struct CaptureNode {
    kind CaptureKind
    text string
    children []int
    number int
    minimum int
    maximum int
    lazy bool
}

struct CaptureParser {
    text string
mut:
    pos int
    nodes []CaptureNode
    count int
    names map[string]int
}

enum CaptureOp {
    atom
    split
    jump
    begin_group
    end_group
    start_line
    end_line
    start_text
    end_text
    boundary
    nonboundary
    backref
    mark
    progress
    accept
}

struct CaptureInstruction {
mut:
    op CaptureOp
    x int
    y int
}

struct CaptureProgram {
mut:
    supported bool
    code []CaptureInstruction
    atoms []pcre.Regex
    guards int
    count int
    names map[string]int
    flags int
    prefix string
}

struct CaptureState {
mut:
    pc int
    pos int
    starts []int
    ends []int
    guards []int
}

fn unsupported_capture() IError {
    return pyrt.raise('NotImplementedError', 'pattern uses syntax outside the capture-recovery grammar')
}

fn next_codepoint(text string, pos int) int {
    if pos >= text.len { return text.len }
    mut end := pos + 1
    for end < text.len && (text[end] & 0xc0) == 0x80 { end = end + 1 }
    return end
}

fn (mut p CaptureParser) add(node CaptureNode) int {
    p.nodes << node
    return p.nodes.len - 1
}

fn (mut p CaptureParser) expression() !int {
    mut branches := []int{}
    branches << p.sequence()!
    for p.pos < p.text.len && p.text[p.pos] == 124 {
        p.pos = p.pos + 1
        branches << p.sequence()!
    }
    if branches.len == 1 { return branches[0] }
    return p.add(CaptureNode{kind: .alternate, children: branches})
}

fn (mut p CaptureParser) sequence() !int {
    mut children := []int{}
    for p.pos < p.text.len && p.text[p.pos] != 41 && p.text[p.pos] != 124 {
        children << p.repeated()!
    }
    return p.add(CaptureNode{kind: .sequence, children: children})
}

fn (mut p CaptureParser) number() !int {
    start := p.pos
    mut n := 0
    for p.pos < p.text.len && p.text[p.pos] >= 48 && p.text[p.pos] <= 57 {
        if n > 10000 { return unsupported_capture() }
        n = n * 10 + int(p.text[p.pos] - 48)
        p.pos = p.pos + 1
    }
    if start == p.pos || n > 10000 { return unsupported_capture() }
    return n
}

fn (mut p CaptureParser) repeated() !int {
    child := p.primary()!
    if p.pos >= p.text.len { return child }
    b := p.text[p.pos]
    mut minimum := 0
    mut maximum := 0
    if b == 42 { maximum = -1; p.pos = p.pos + 1 }
    else if b == 43 { minimum = 1; maximum = -1; p.pos = p.pos + 1 }
    else if b == 63 { maximum = 1; p.pos = p.pos + 1 }
    else if b == 123 {
        saved := p.pos
        p.pos = p.pos + 1
        // Non-quantifier braces are literals. The native compiler has already
        // validated the original pattern before this parser is called.
        if p.pos >= p.text.len { p.pos = saved; return child }
        if p.text[p.pos] != 44 && (p.text[p.pos] < 48 || p.text[p.pos] > 57) {
            p.pos = saved
            return child
        }
        if p.text[p.pos] != 44 { minimum = p.number()! }
        maximum = minimum
        if p.pos < p.text.len && p.text[p.pos] == 44 {
            p.pos = p.pos + 1
            maximum = -1
            if p.pos < p.text.len && p.text[p.pos] >= 48 && p.text[p.pos] <= 57 { maximum = p.number()! }
        }
        if p.pos >= p.text.len || p.text[p.pos] != 125 { p.pos = saved; return child }
        p.pos = p.pos + 1
    } else { return child }
    mut lazy := false
    if p.pos < p.text.len && p.text[p.pos] == 63 { lazy = true; p.pos = p.pos + 1 }
    // Possessive quantifiers need atomic backtracking boundaries, not this VM.
    if p.pos < p.text.len && p.text[p.pos] == 43 { return unsupported_capture() }
    return p.add(CaptureNode{kind: .repeat, children: [child], minimum: minimum, maximum: maximum, lazy: lazy})
}

fn (mut p CaptureParser) primary() !int {
    if p.pos >= p.text.len { return unsupported_capture() }
    start := p.pos
    b := p.text[p.pos]
    p.pos = p.pos + 1
    if b == 40 {
        mut capture := true
        mut name := ''
        if p.pos < p.text.len && p.text[p.pos] == 63 {
            p.pos = p.pos + 1
            if p.pos < p.text.len && p.text[p.pos] == 58 {
                capture = false
                p.pos = p.pos + 1
            } else if p.pos + 1 < p.text.len && p.text[p.pos] == 80 && p.text[p.pos + 1] == 60 {
                p.pos = p.pos + 2
                name_start := p.pos
                for p.pos < p.text.len && p.text[p.pos] != 62 { p.pos = p.pos + 1 }
                if p.pos >= p.text.len { return unsupported_capture() }
                name = p.text[name_start .. p.pos]
                p.pos = p.pos + 1
            } else if p.pos + 1 < p.text.len && p.text[p.pos] == 80 && p.text[p.pos + 1] == 61 {
                p.pos = p.pos + 2
                name_start := p.pos
                for p.pos < p.text.len && p.text[p.pos] != 41 { p.pos = p.pos + 1 }
                if p.pos >= p.text.len { return unsupported_capture() }
                refname := p.text[name_start .. p.pos]
                number := p.names[refname] or { return unsupported_capture() }
                p.pos = p.pos + 1
                return p.add(CaptureNode{kind: .backref, number: number})
            } else if p.pos < p.text.len && p.text[p.pos] == 35 {
                for p.pos < p.text.len && p.text[p.pos] != 41 { p.pos = p.pos + 1 }
                if p.pos >= p.text.len { return unsupported_capture() }
                p.pos = p.pos + 1
                return p.add(CaptureNode{kind: .empty})
            } else { return unsupported_capture() }
        }
        mut number := 0
        if capture {
            p.count = p.count + 1
            number = p.count
            if name != '' { p.names[name] = number }
        }
        child := p.expression()!
        if p.pos >= p.text.len || p.text[p.pos] != 41 { return unsupported_capture() }
        p.pos = p.pos + 1
        if !capture { return child }
        return p.add(CaptureNode{kind: .group, children: [child], number: number})
    }
    if b == 91 {
        if p.pos < p.text.len && p.text[p.pos] == 94 { p.pos = p.pos + 1 }
        if p.pos < p.text.len && p.text[p.pos] == 93 { p.pos = p.pos + 1 }
        for p.pos < p.text.len && p.text[p.pos] != 93 {
            if p.text[p.pos] == 92 {
                p.pos = p.pos + 1
                if p.pos >= p.text.len { return unsupported_capture() }
            }
            p.pos = p.pos + 1
        }
        if p.pos >= p.text.len { return unsupported_capture() }
        p.pos = p.pos + 1
        return p.add(CaptureNode{kind: .atom, text: p.text[start .. p.pos]})
    }
    if b == 94 { return p.add(CaptureNode{kind: .start_line}) }
    if b == 36 { return p.add(CaptureNode{kind: .end_line}) }
    if b == 92 {
        if p.pos >= p.text.len { return unsupported_capture() }
        c := p.text[p.pos]
        p.pos = p.pos + 1
        if c == 65 { return p.add(CaptureNode{kind: .start_text}) }
        if c == 90 { return p.add(CaptureNode{kind: .end_text}) }
        if c == 98 { return p.add(CaptureNode{kind: .boundary}) }
        if c == 66 { return p.add(CaptureNode{kind: .nonboundary}) }
        if c >= 49 && c <= 57 {
            mut n := int(c - 48)
            if p.pos < p.text.len && p.text[p.pos] >= 48 && p.text[p.pos] <= 57 {
                n = n * 10 + int(p.text[p.pos] - 48)
                p.pos = p.pos + 1
                if p.pos < p.text.len && p.text[p.pos] >= 48 && p.text[p.pos] <= 55 { return unsupported_capture() }
            }
            return p.add(CaptureNode{kind: .backref, number: n})
        }
        if c == 48 {
            mut consumed := 1
            for consumed < 3 && p.pos < p.text.len && p.text[p.pos] >= 48 && p.text[p.pos] <= 55 {
                p.pos = p.pos + 1
                consumed = consumed + 1
            }
        } else if c == 120 { p.pos = p.pos + 2 }
        else if c == 117 { p.pos = p.pos + 4 }
        else if c == 85 { p.pos = p.pos + 8 }
        else if c == 78 || c == 103 || c == 107 || c == 112 || c == 80 { return unsupported_capture() }
        if p.pos > p.text.len { return unsupported_capture() }
        return p.add(CaptureNode{kind: .atom, text: p.text[start .. p.pos]})
    }
    p.pos = next_codepoint(p.text, start)
    piece := p.text[start .. p.pos]
    // Dot is the only unescaped metacharacter that is a one-character atom.
    literal := if b == 46 { piece } else { escape(piece) }
    return p.add(CaptureNode{kind: .atom, text: literal})
}

fn (mut p CaptureProgram) emit(op CaptureOp, x int, y int) int {
    p.code << CaptureInstruction{op: op, x: x, y: y}
    return p.code.len - 1
}

fn (mut p CaptureProgram) compile_node(nodes []CaptureNode, index int) ! {
    n := nodes[index]
    match n.kind {
        .empty {}
        .atom {
            atom := pcre.compile(p.prefix + '(?:' + n.text + ')') or { return unsupported_capture() }
            p.atoms << atom
            p.emit(.atom, p.atoms.len - 1, 0)
        }
        .sequence { for child in n.children { p.compile_node(nodes, child)! } }
        .alternate {
            mut exits := []int{}
            for i, child in n.children {
                if i + 1 == n.children.len { p.compile_node(nodes, child)!; break }
                branch := p.emit(.split, 0, 0)
                p.code[branch].x = p.code.len
                p.compile_node(nodes, child)!
                exits << p.emit(.jump, 0, 0)
                p.code[branch].y = p.code.len
            }
            for at in exits { p.code[at].x = p.code.len }
        }
        .group {
            p.emit(.begin_group, n.number, 0)
            p.compile_node(nodes, n.children[0])!
            p.emit(.end_group, n.number, 0)
        }
        .repeat {
            for _ in 0 .. n.minimum { p.compile_node(nodes, n.children[0])! }
            if n.maximum == -1 {
                guard := p.guards
                p.guards = p.guards + 1
                branch := p.emit(.split, 0, 0)
                body := p.code.len
                p.emit(.mark, guard, 0)
                p.compile_node(nodes, n.children[0])!
                check := p.emit(.progress, guard, 0)
                p.emit(.jump, branch, 0)
                finish := p.code.len
                p.code[check].y = finish
                p.code[branch].x = if n.lazy { finish } else { body }
                p.code[branch].y = if n.lazy { body } else { finish }
            } else {
                mut exits := []int{}
                for _ in n.minimum .. n.maximum {
                    branch := p.emit(.split, 0, 0)
                    body := p.code.len
                    p.compile_node(nodes, n.children[0])!
                    // All skipped alternatives go to the repeat's final end,
                    // not to the next optional copy (capture-order matters).
                    if n.lazy { p.code[branch].y = body } else { p.code[branch].x = body }
                    exits << branch
                }
                for branch in exits {
                    if n.lazy { p.code[branch].x = p.code.len } else { p.code[branch].y = p.code.len }
                }
            }
        }
        .start_line { p.emit(.start_line, 0, 0) }
        .end_line { p.emit(.end_line, 0, 0) }
        .start_text { p.emit(.start_text, 0, 0) }
        .end_text { p.emit(.end_text, 0, 0) }
        .boundary { p.emit(.boundary, 0, 0) }
        .nonboundary { p.emit(.nonboundary, 0, 0) }
        .backref { p.emit(.backref, n.number, 0) }
    }
}

fn capture_program(pattern string, prefix string, flags int) CaptureProgram {
    mut parser := CaptureParser{text: pattern, names: map[string]int{}}
    root := parser.expression() or { return CaptureProgram{} }
    if parser.pos != pattern.len { return CaptureProgram{} }
    mut program := CaptureProgram{count: parser.count, names: parser.names.clone(), flags: flags, prefix: prefix}
    program.emit(.begin_group, 0, 0)
    program.compile_node(parser.nodes, root) or { return CaptureProgram{} }
    program.emit(.end_group, 0, 0)
    program.emit(.accept, 0, 0)
    program.supported = true
    return program
}

fn clone_capture_state(state CaptureState, pc int) CaptureState {
    return CaptureState{pc: pc, pos: state.pos, starts: state.starts.clone(), ends: state.ends.clone(), guards: state.guards.clone()}
}

fn (p CaptureProgram) word_at(text string, pos int) bool {
    if pos < 0 || pos >= text.len { return false }
    word := pcre.compile(p.prefix + '\\w') or { return false }
    return word.fullmatch(text[pos .. next_codepoint(text, pos)]) != none
}

fn (p CaptureProgram) execute(text string, begin int, end_required bool, nonempty bool) ?CaptureState {
    mut starts := []int{}
    mut ends := []int{}
    for _ in 0 .. p.count + 1 { starts << -1; ends << -1 }
    mut guards := []int{}
    for _ in 0 .. p.guards { guards << -1 }
    mut state := CaptureState{pos: begin, starts: starts, ends: ends, guards: guards}
    mut stack := []CaptureState{}
    for {
        instruction := p.code[state.pc]
        mut failed := false
        match instruction.op {
            .atom {
                if state.pos >= text.len { failed = true }
                else {
                    end := next_codepoint(text, state.pos)
                    if p.atoms[instruction.x].fullmatch(text[state.pos .. end]) == none { failed = true }
                    else { state.pos = end; state.pc = state.pc + 1 }
                }
            }
            .split { stack << clone_capture_state(state, instruction.y); state.pc = instruction.x }
            .jump { state.pc = instruction.x }
            .begin_group { state.starts[instruction.x] = state.pos; state.pc = state.pc + 1 }
            .end_group { state.ends[instruction.x] = state.pos; state.pc = state.pc + 1 }
            .mark { state.guards[instruction.x] = state.pos; state.pc = state.pc + 1 }
            .progress { state.pc = if state.pos == state.guards[instruction.x] { instruction.y } else { state.pc + 1 } }
            .start_line {
                if state.pos == 0 || (p.flags & multiline != 0 && text[state.pos - 1] == 10) { state.pc = state.pc + 1 }
                else { failed = true }
            }
            .end_line {
                if state.pos == text.len || (state.pos < text.len && text[state.pos] == 10 && (p.flags & multiline != 0 || state.pos + 1 == text.len)) { state.pc = state.pc + 1 }
                else { failed = true }
            }
            .start_text { if state.pos == 0 { state.pc = state.pc + 1 } else { failed = true } }
            .end_text { if state.pos == text.len { state.pc = state.pc + 1 } else { failed = true } }
            .boundary, .nonboundary {
                mut prev := state.pos - 1
                for prev > 0 && (text[prev] & 0xc0) == 0x80 { prev = prev - 1 }
                boundary := p.word_at(text, prev) != p.word_at(text, state.pos)
                wanted := instruction.op == .boundary
                // CPython 3.12/3.13 \B does not match the empty input.
                if boundary == wanted && (wanted || text.len > 0) { state.pc = state.pc + 1 }
                else { failed = true }
            }
            .backref {
                n := instruction.x
                if n <= 0 || n > p.count { failed = true }
                else if state.starts[n] < 0 || state.ends[n] < state.starts[n] { failed = true }
                else {
                    captured := text[state.starts[n] .. state.ends[n]]
                    mut end := state.pos
                    for _ in captured.runes() { end = next_codepoint(text, end) }
                    candidate := text[state.pos .. end]
                    mut equal := candidate == captured
                    if !equal && p.flags & ignorecase != 0 {
                        probe := pcre.compile(p.prefix + escape(captured)) or { return none }
                        equal = probe.fullmatch(candidate) != none
                    }
                    if equal { state.pos = end; state.pc = state.pc + 1 } else { failed = true }
                }
            }
            .accept {
                if (end_required && state.pos != text.len) || (nonempty && state.pos == begin) { failed = true }
                else { return state }
            }
        }
        if failed {
            if stack.len == 0 { return none }
            state = stack.pop()
        }
    }
    return none
}

fn (p Pattern) capture_search(text string, from_byte int, anchored bool, full bool, nonempty bool) ?Match {
    mut begin := from_byte
    for begin <= text.len {
        if state := p.captures.execute(text, begin, full, nonempty && begin == from_byte) {
            mut values := []pyrt.Value{}
            mut spans := []Span{}
            for i in 0 .. state.starts.len {
                a := state.starts[i]
                b := state.ends[i]
                if a < 0 || b < a { values << pyrt.none_; spans << Span{start: -1, end: -1} }
                else { values << pyrt.Value(text[a .. b]); spans << Span{start: a, end: b} }
            }
            return Match{values: values, offsets: spans, group_names: p.group_names.clone(), count: p.group_count,
                source: text, start_byte: begin, end_byte: state.pos}
        }
        if anchored || begin == text.len { break }
        begin = next_codepoint(text, begin)
    }
    return none
}
