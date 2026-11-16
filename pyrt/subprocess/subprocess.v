module subprocess

import os
import time
import crypto.rand
import encoding.hex
import pyrt

// Public sentinel names are V-safe; the manifest maps Python PIPE/DEVNULL.
pub const pipe = -1
pub const devnull = -3

@[params]
pub struct RunOptions {
pub:
    capture_output bool
    text bool
    check bool
    cwd string
    env map[string]string
    env_given bool
    input_data pyrt.Value = pyrt.none_
    timeout f64 = -1.0
    shell bool
}

@[params]
pub struct WaitOptions {
pub:
    timeout f64 = -1.0
}

@[params]
pub struct CommunicateOptions {
pub:
    input_data pyrt.Value = pyrt.none_
    timeout f64 = -1.0
}

pub struct CompletedProcess {
pub:
    args []string
    returncode int
    stdout pyrt.Value = pyrt.none_
    stderr pyrt.Value = pyrt.none_
}

pub struct CalledProcessError {
pub:
    returncode int
    cmd []string
    stdout pyrt.Value = pyrt.none_
    stderr pyrt.Value = pyrt.none_
}

pub struct TimeoutExpired {
pub:
    cmd []string
    timeout f64
    stdout pyrt.Value = pyrt.none_
    stderr pyrt.Value = pyrt.none_
}

// os.Process has no documented independent, non-blocking pipe-drain facility.
// Calling wait before both slurps CAN DEADLOCK if either pipe fills. This
// implementation handles small/medium bounded outputs only. Timeout polling
// cannot cure a child blocked writing to a full pipe.
fn register_errors() {
    pyrt.register_exception('subprocess.SubprocessError', ['Exception'])
    pyrt.register_exception('subprocess.CalledProcessError', ['subprocess.SubprocessError'])
    pyrt.register_exception('subprocess.TimeoutExpired', ['subprocess.SubprocessError'])
}

fn bytes_of(text string) []u8 {
    mut out := []u8{}
    for i in 0 .. text.len { out << text[i] }
    return out
}

fn output_value(text string, as_text bool) pyrt.Value {
    if as_text { return pyrt.Value(text) }
    return pyrt.Value(bytes_of(text))
}

fn command_string(args []string) string {
    if args.len == 0 { return '[]' }
    mut pieces := []string{}
    for arg in args { pieces << pyrt.repr(pyrt.Value(arg)) }
    return '[' + pieces.join(', ') + ']'
}

fn timeout_error(args []string, seconds f64) IError {
    register_errors()
    return pyrt.raise('subprocess.TimeoutExpired',
        "Command '${command_string(args)}' timed out after ${pyrt.repr(pyrt.Value(seconds))} seconds")
}

fn process_error(code int, args []string) IError {
    register_errors()
    return pyrt.raise('subprocess.CalledProcessError',
        "Command '${command_string(args)}' returned non-zero exit status ${code}.")
}

fn program_path(name string) !string {
    if name.contains('/') { return name }
    return os.find_abs_path_of_executable(name) or {
        return pyrt.raise('FileNotFoundError', "[Errno 2] No such file or directory: '${name}'")
    }
}

fn make_process(args []string, opts RunOptions) !&os.Process {
    if args.len == 0 { return pyrt.raise('IndexError', 'list index out of range') }
    mut actual := args.clone()
    if opts.shell {
        actual = ['/bin/sh', '-c', args[0]]
        for i in 1 .. args.len { actual << args[i] }
    }
    binary := program_path(actual[0])!
    mut p := os.new_process(binary)
    if actual.len > 1 { p.set_args(actual[1 .. actual.len]) }
    if opts.cwd != '' { p.set_work_folder(opts.cwd) }
    if opts.env_given { p.set_environment(opts.env) }
    p.set_redirect_stdio()
    return p
}

fn write_input_file(mut p os.Process, input_data pyrt.Value) !string {
    if input_data is pyrt.NoneType {
        // A redirected pipe left open prevents EOF. /dev/null is POSIX-only.
        p.set_stdin_path('/dev/null')
        return ''
    }
    if input_data is []u8 {
        random_name := hex.encode(rand.bytes(16)!, hex.EncodeParams{})
        path := os.join_path(os.vtmp_dir(), 'pyrt-stdin-${os.getpid()}-${random_name}')
        os.write_bytes(path, input_data)!
        p.set_stdin_path(path)
        return path
    }
    input_text := pyrt.as_str(input_data)!
    random_name := hex.encode(rand.bytes(16)!, hex.EncodeParams{})
    path := os.join_path(os.vtmp_dir(), 'pyrt-stdin-${os.getpid()}-${random_name}')
    os.write_file(path, input_text)!
    p.set_stdin_path(path)
    return path
}

fn await_exit(mut p os.Process, timeout f64, args []string) ! {
    if timeout < 0 {
        p.wait()
        return
    }
    began := time.sys_mono_now()
    for p.is_alive() {
        elapsed := f64(time.sys_mono_now() - began) / 1000000000.0
        if elapsed >= timeout {
            p.signal_kill()
            p.wait()
            return timeout_error(args, timeout)
        }
        time.sleep(10 * time.millisecond)
    }
    p.wait()
}

pub fn run(args []string, opts RunOptions) !CompletedProcess {
    mut p := make_process(args, opts)!
    input_path := write_input_file(mut p, opts.input_data)!
    defer {
        if input_path != '' { os.rm(input_path) or {} }
        p.close()
    }
    p.run()
    if p.err != '' { return pyrt.raise('OSError', p.err) }
    await_exit(mut p, opts.timeout, args)!
    output := p.stdout_slurp()
    error_output := p.stderr_slurp()
    result := CompletedProcess{
        args: args.clone()
        returncode: p.code
        stdout: if opts.capture_output { output_value(output, opts.text) } else { pyrt.none_ }
        stderr: if opts.capture_output { output_value(error_output, opts.text) } else { pyrt.none_ }
    }
    if !opts.capture_output {
        if output != '' { print(output) }
        if error_output != '' { eprintln(error_output) }
    }
    if opts.check && p.code != 0 { return process_error(p.code, args) }
    return result
}

pub fn run_shell(command string, opts RunOptions) !CompletedProcess {
    return run([command], RunOptions{
        capture_output: opts.capture_output, text: opts.text, check: opts.check,
        cwd: opts.cwd, env: opts.env.clone(), env_given: opts.env_given,
        input_data: opts.input_data, timeout: opts.timeout, shell: true
    })!
}

pub fn (p CompletedProcess) check_returncode() ! {
    if p.returncode != 0 { return process_error(p.returncode, p.args) }
}

pub fn check_output(args []string, opts RunOptions) !pyrt.Value {
    result := run(args, RunOptions{
        capture_output: true, text: opts.text, check: true, cwd: opts.cwd,
        env: opts.env.clone(), env_given: opts.env_given, input_data: opts.input_data,
        timeout: opts.timeout, shell: opts.shell
    })!
    return result.stdout
}

// Popen retains the process. stdout/stderr are read only once at communicate().
pub struct Popen {
pub:
    args []string
    pid int
    text bool
    capture_output bool
pub mut:
    returncode ?int
mut:
    process &os.Process = unsafe { nil }
    completed bool
    stdout pyrt.Value = pyrt.none_
    stderr pyrt.Value = pyrt.none_
    input_path string
}

pub fn new_popen(args []string, opts RunOptions) !&Popen {
    mut process := make_process(args, opts)!
    path := write_input_file(mut process, opts.input_data)!
    process.run()
    if process.err != '' {
        if path != '' { os.rm(path) or {} }
        return pyrt.raise('OSError', process.err)
    }
    return &Popen{args: args.clone(), pid: process.pid, process: process,
        text: opts.text, capture_output: opts.capture_output, input_path: path}
}

fn (mut p Popen) capture() {
    if p.completed { return }
    captured_out := p.process.stdout_slurp()
    captured_err := p.process.stderr_slurp()
    if p.capture_output {
        p.stdout = output_value(captured_out, p.text)
        p.stderr = output_value(captured_err, p.text)
    } else {
        p.stdout = pyrt.none_
        p.stderr = pyrt.none_
        if captured_out != '' { print(captured_out) }
        if captured_err != '' { eprintln(captured_err) }
    }
    p.returncode = p.process.code
    p.completed = true
    if p.input_path != '' { os.rm(p.input_path) or {}; p.input_path = '' }
    p.process.close()
}

pub fn (mut p Popen) wait(opts WaitOptions) !int {
    if p.completed { return p.returncode or { -1 } }
    await_exit(mut p.process, opts.timeout, p.args)!
    p.capture()
    return p.returncode or { -1 }
}

pub fn (mut p Popen) poll() ?int {
    if p.completed { return p.returncode }
    if p.process.is_alive() { return none }
    p.process.wait()
    p.capture()
    return p.returncode
}

pub fn (mut p Popen) communicate(opts CommunicateOptions) !(pyrt.Value, pyrt.Value) {
    if !(opts.input_data is pyrt.NoneType) {
        // stdin_write has no documented close/EOF control; require input at
        // construction time to use set_stdin_path for reliable EOF.
        return pyrt.raise('NotImplementedError',
            'pass subprocess input_data to new_popen; no stdin pipe close API is available')
    }
    _ = p.wait(timeout: opts.timeout)!
    return p.stdout, p.stderr
}

pub fn (mut p Popen) kill() { if !p.completed { p.process.signal_kill() } }
pub fn (mut p Popen) terminate() { if !p.completed { p.process.signal_term() } }
