module subprocess

import pyrt

fn test_run_separate_streams_and_exit() {
    result := run(['/bin/sh', '-c', 'printf out; printf err >&2; exit 3'],
        capture_output: true, text: true) or { panic(err.msg()) }
    // python: __import__('subprocess').run(['/bin/sh','-c','printf out; printf err >&2; exit 3'], capture_output=True, text=True).stdout == 'out'
    assert pyrt.as_str(result.stdout) or { '' } == 'out'
    // python: __import__('subprocess').run(['/bin/sh','-c','printf out; printf err >&2; exit 3'], capture_output=True, text=True).stderr == 'err'
    assert pyrt.as_str(result.stderr) or { '' } == 'err'
    // python: __import__('subprocess').run(['/bin/sh','-c','exit 3']).returncode == 3
    assert result.returncode == 3
    // python: type(__import__('subprocess').run(['/bin/sh','-c','printf x'],capture_output=True).stdout).__name__ == 'bytes'
    binary := run(['/bin/sh', '-c', 'printf x'], capture_output: true) or { panic(err.msg()) }
    assert binary.stdout is []u8
}

fn test_run_shell_and_check() {
    result := run_shell('printf hello', capture_output: true, text: true) or { panic(err.msg()) }
    // python: __import__('subprocess').run('printf hello',shell=True,capture_output=True,text=True).stdout == 'hello'
    assert pyrt.as_str(result.stdout) or { '' } == 'hello'
    mut caught := ''
    _ = run(['/bin/sh', '-c', 'exit 4'], check: true) or { caught = err.msg(); CompletedProcess{} }
    // python: (__import__('subprocess').CalledProcessError(4, ['sh']).returncode) == 4
    assert caught.contains('4')
}

fn test_popen_communication() {
    mut p := new_popen(['/bin/sh', '-c', 'printf X; printf Y >&2'],
        capture_output: true, text: true) or { panic(err.msg()) }
    stdout, stderr := p.communicate(CommunicateOptions{}) or { panic(err.msg()) }
    // python: __import__('subprocess').Popen(['/bin/sh','-c','printf X; printf Y >&2'],stdout=-1,stderr=-1,text=True).communicate() == ('X', 'Y')
    assert pyrt.as_str(stdout) or { '' } == 'X'
    // python: __import__('subprocess').Popen(['/bin/sh','-c','printf X; printf Y >&2'],stdout=-1,stderr=-1,text=True).communicate()[1] == 'Y'
    assert pyrt.as_str(stderr) or { '' } == 'Y'
    // python: __import__('subprocess').run(['/bin/sh','-c','exit 0']).returncode == 0
    assert (p.poll() or { -100 }) == 0
}

fn test_subprocess_timeout_and_environment() {
    import_check := run(['/bin/sh', '-c', 'printf "$PYRT_TEST_ENV"'],
        capture_output: true, text: true,
        env: {'PYRT_TEST_ENV': 'isolated'}, env_given: true,
        cwd: '/') or { panic(err.msg()) }
    // python: __import__('subprocess').run(['/bin/sh','-c','printf "$PYRT_TEST_ENV"'], env={'PYRT_TEST_ENV':'isolated'}, cwd='/', capture_output=True, text=True).stdout == 'isolated'
    assert pyrt.as_str(import_check.stdout) or { '' } == 'isolated'
    mut caught := ''
    _ = run(['/bin/sh', '-c', 'sleep 1'], timeout: 0.05, capture_output: true) or {
        caught = err.msg()
        CompletedProcess{}
    }
    // python: error_text(lambda: __import__('subprocess').run(['/bin/sh','-c','sleep 1'], timeout=0.05)).startswith('TimeoutExpired|Command')
    assert caught.contains('timed out')
}

fn test_subprocess_input_data() {
    result := run(['/bin/sh', '-c', 'cat'], input_data: pyrt.Value('hello'),
        text: true, capture_output: true) or { panic(err.msg()) }
    // python: __import__('subprocess').run(['/bin/sh','-c','cat'], input='hello', text=True, capture_output=True).stdout == 'hello'
    assert pyrt.as_str(result.stdout) or { '' } == 'hello'
}
