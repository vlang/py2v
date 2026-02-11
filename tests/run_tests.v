module main

import os
import term

struct TestResult {
mut:
	name        string
	passed      bool
	error_msg   string
	skip        bool
	skip_reason string
}

struct TestRunner {
mut:
	passed  int
	failed  int
	skipped int
	results []TestResult
}

fn main() {
	mut runner := TestRunner{}

	// Get the directory where this script is located
	script_dir := os.dir(os.executable())
	cases_dir := os.join_path(script_dir, 'cases')
	expected_dir := os.join_path(script_dir, 'expected')

	// Find py2v executable (in parent directory)
	py2v_path := os.join_path(os.dir(script_dir), 'py2v')

	if !os.exists(py2v_path) {
		eprintln('Error: py2v executable not found at ${py2v_path}')
		eprintln('Please build it first with: v . -o py2v')
		exit(1)
	}

	// Get all Python test cases
	cases := os.glob('${cases_dir}/*.py') or {
		eprintln('Error: Could not find test cases in ${cases_dir}')
		exit(1)
	}

	println('Running ${cases.len} tests...\n')

	for case_file in cases {
		test_name := os.file_name(case_file).replace('.py', '')
		expected_file := os.join_path(expected_dir, '${test_name}.v')

		// Skip if no expected file exists
		if !os.exists(expected_file) {
			runner.skipped++
			runner.results << TestResult{
				name:        test_name
				skip:        true
				skip_reason: 'no expected file'
			}
			continue
		}

		// Run py2v on the test case
		result := os.execute('${py2v_path} "${case_file}"')

		if result.exit_code != 0 {
			runner.failed++
			runner.results << TestResult{
				name:      test_name
				passed:    false
				error_msg: 'transpilation failed: ${result.output}'
			}
			continue
		}

		generated := result.output.trim_space()
		expected := os.read_file(expected_file) or {
			runner.failed++
			runner.results << TestResult{
				name:      test_name
				passed:    false
				error_msg: 'could not read expected file'
			}
			continue
		}

		// Compare output
		if generated == expected.trim_space() {
			runner.passed++
			runner.results << TestResult{
				name:   test_name
				passed: true
			}
		} else {
			runner.failed++
			runner.results << TestResult{
				name:      test_name
				passed:    false
				error_msg: 'output mismatch'
			}
		}
	}

	// Print results
	println('\n${'─'.repeat(60)}')
	println('Results:\n')

	for r in runner.results {
		if r.skip {
			print(term.yellow('SKIP'))
			println(' ${r.name} (${r.skip_reason})')
		} else if r.passed {
			print(term.green('PASS'))
			println(' ${r.name}')
		} else {
			print(term.red('FAIL'))
			println(' ${r.name}: ${r.error_msg}')
		}
	}

	println('\n${'─'.repeat(60)}')
	println('Summary: ${term.green('${runner.passed} passed')}, ${term.red('${runner.failed} failed')}, ${term.yellow('${runner.skipped} skipped')}')

	if runner.failed > 0 {
		exit(1)
	}
}
