module argparse

import pyrt

fn argparse_exit(p &ArgumentParser, argv []string) string {
    p.parse_args(argv) or {
        if e := pyrt.caught(err, 'BaseException') { return e.class_name + '|' + e.msg() }
        return err.msg()
    }
    return '<no error>'
}

fn test_argparse_typed_namespace_and_options() {
    p := new_parser(prog: 'tool', emit_output: false)
    p.add_argument(['file']) or { panic(err.msg()) }
    p.add_argument(['-v', '--verbose'], action: 'count') or { panic(err.msg()) }
    p.add_argument(['--dry-run'], action: 'store_true') or { panic(err.msg()) }
    p.add_argument(['--number'], value_type: .int_type, default_value: pyrt.Value('3')) or { panic(err.msg()) }
    p.add_argument(['--ratio'], value_type: .float_type, default_value: pyrt.Value(f64(1.5))) or { panic(err.msg()) }
    p.add_argument(['--color'], choices: [pyrt.Value('red'), pyrt.Value('blue')]) or { panic(err.msg()) }
    n := p.parse_args(['-vv', '--dry-run', '--number=10', '--ratio', '.25', '--color', 'blue', 'data']) or { panic(err.msg()) }
    // python: argparse_probe("p=argparse.ArgumentParser(prog='tool');p.add_argument('file');p.add_argument('-v','--verbose',action='count');p.add_argument('--dry-run',action='store_true');p.add_argument('--number',type=int,default='3');p.add_argument('--ratio',type=float,default=1.5);p.add_argument('--color',choices=['red','blue'])", ['-vv', '--dry-run', '--number=10', '--ratio', '.25', '--color', 'blue', 'data'], False)['namespace']['file'] == 'data'
    assert (n.get_str('file') or { panic(err.msg()) }) == 'data'
    // python: argparse_probe("p=argparse.ArgumentParser(prog='tool');p.add_argument('file');p.add_argument('-v','--verbose',action='count');p.add_argument('--dry-run',action='store_true');p.add_argument('--number',type=int,default='3');p.add_argument('--ratio',type=float,default=1.5);p.add_argument('--color',choices=['red','blue'])", ['-vv', '--dry-run', '--number=10', '--ratio', '.25', '--color', 'blue', 'data'], False)['namespace']['verbose'] == 2
    assert (n.get_int('verbose') or { panic(err.msg()) }) == 2
    // python: argparse_probe("p=argparse.ArgumentParser(prog='tool');p.add_argument('file');p.add_argument('-v','--verbose',action='count');p.add_argument('--dry-run',action='store_true');p.add_argument('--number',type=int,default='3');p.add_argument('--ratio',type=float,default=1.5);p.add_argument('--color',choices=['red','blue'])", ['-vv', '--dry-run', '--number=10', '--ratio', '.25', '--color', 'blue', 'data'], False)['namespace']['dry_run'] == True
    assert (n.get_bool('dry_run') or { panic(err.msg()) }) == true
    // python: argparse_probe("p=argparse.ArgumentParser(prog='tool');p.add_argument('file');p.add_argument('-v','--verbose',action='count');p.add_argument('--dry-run',action='store_true');p.add_argument('--number',type=int,default='3');p.add_argument('--ratio',type=float,default=1.5);p.add_argument('--color',choices=['red','blue'])", ['-vv', '--dry-run', '--number=10', '--ratio', '.25', '--color', 'blue', 'data'], False)['namespace']['number'] == 10
    assert (n.get_int('number') or { panic(err.msg()) }) == 10
    // python: argparse_probe("p=argparse.ArgumentParser(prog='tool');p.add_argument('file');p.add_argument('-v','--verbose',action='count');p.add_argument('--dry-run',action='store_true');p.add_argument('--number',type=int,default='3');p.add_argument('--ratio',type=float,default=1.5);p.add_argument('--color',choices=['red','blue'])", ['-vv', '--dry-run', '--number=10', '--ratio', '.25', '--color', 'blue', 'data'], False)['namespace']['ratio'] == 0.25
    assert (n.get_float('ratio') or { panic(err.msg()) }) == 0.25
    // python: argparse_probe("p=argparse.ArgumentParser(prog='tool');p.add_argument('file');p.add_argument('-v','--verbose',action='count');p.add_argument('--dry-run',action='store_true');p.add_argument('--number',type=int,default='3');p.add_argument('--ratio',type=float,default=1.5);p.add_argument('--color',choices=['red','blue'])", ['-vv', '--dry-run', '--number=10', '--ratio', '.25', '--color', 'blue', 'data'], False)['namespace']['color'] == 'blue'
    assert (n.get_str('color') or { panic(err.msg()) }) == 'blue'
    defaults := p.parse_args(['data']) or { panic(err.msg()) }
    // python: argparse_probe("p=argparse.ArgumentParser(prog='tool');p.add_argument('file');p.add_argument('-v','--verbose',action='count');p.add_argument('--dry-run',action='store_true');p.add_argument('--number',type=int,default='3');p.add_argument('--ratio',type=float,default=1.5);p.add_argument('--color',choices=['red','blue'])", ['data'], False)['namespace']['number'] == 3
    assert (defaults.get_int('number') or { panic(err.msg()) }) == 3
    // python: argparse_probe("p=argparse.ArgumentParser(prog='tool');p.add_argument('file');p.add_argument('-v','--verbose',action='count');p.add_argument('--dry-run',action='store_true');p.add_argument('--number',type=int,default='3');p.add_argument('--ratio',type=float,default=1.5);p.add_argument('--color',choices=['red','blue'])", ['data'], False)['namespace']['verbose'] == None
    assert defaults.get('verbose') is pyrt.NoneType
    // python: argparse_probe("p=argparse.ArgumentParser(prog='tool');p.add_argument('file');p.add_argument('-v','--verbose',action='count');p.add_argument('--dry-run',action='store_true');p.add_argument('--number',type=int,default='3');p.add_argument('--ratio',type=float,default=1.5);p.add_argument('--color',choices=['red','blue'])", ['data'], False)['namespace']['dry_run'] == False
    assert !(defaults.get_bool('dry_run') or { panic(err.msg()) })
    // python: argparse_probe("p=argparse.ArgumentParser(prog='tool');p.add_argument('file');p.add_argument('-v','--verbose',action='count');p.add_argument('--dry-run',action='store_true');p.add_argument('--number',type=int,default='3');p.add_argument('--ratio',type=float,default=1.5);p.add_argument('--color',choices=['red','blue'])", ['data'], False)['namespace']['ratio'] == 1.5
    assert (defaults.get_float('ratio') or { panic(err.msg()) }) == 1.5
    // python: not hasattr(__import__('argparse').ArgumentParser().parse_args([]), 'help')
    assert !defaults.has('help')
    boxed := n.as_value()
    // python: getattr(__import__('argparse').Namespace(number=10), 'number') == 10
    assert (pyrt.as_int(pyrt.getattr(boxed, 'number') or { panic(err.msg()) }) or { panic(err.msg()) }) == 10
    pyrt.setattr(boxed, 'number', pyrt.Value(12)) or { panic(err.msg()) }
    // python: exec_result("import argparse; n=argparse.Namespace(number=10);setattr(n,'number',12)", "n.number == 12")
    assert (n.get_int('number') or { panic(err.msg()) }) == 12
    n.set('extra', pyrt.Value('yes'))
    // python: exec_result("import argparse; n=argparse.Namespace();n.extra='yes'", "n.extra == 'yes'")
    assert pyrt.str(n.get('extra')) == 'yes'
}
fn test_argparse_short_bundles_and_terminator() {
    p := new_parser(prog: 'tool', emit_output: false)
    p.add_argument(['-v'], action: 'count', default_value: pyrt.Value(2)) or { panic(err.msg()) }
    p.add_argument(['-n','--number'], value_type: .int_type) or { panic(err.msg()) }
    p.add_argument(['--on'], action: 'store_false') or { panic(err.msg()) }
    p.add_argument(['rest'], nargs: '*') or { panic(err.msg()) }
    n := p.parse_args(['-vvn12', '--on', '--', '-x', '--number=8']) or { panic(err.msg()) }
    // python: argparse_probe("p=argparse.ArgumentParser(prog='tool');p.add_argument('-v',action='count',default=2);p.add_argument('-n','--number',type=int);p.add_argument('--on',action='store_false');p.add_argument('rest',nargs='*')", ['-vvn12', '--on', '--', '-x', '--number=8'], False)['namespace']['v'] == 4
    assert (n.get_int('v') or { panic(err.msg()) }) == 4
    // python: argparse_probe("p=argparse.ArgumentParser(prog='tool');p.add_argument('-v',action='count',default=2);p.add_argument('-n','--number',type=int);p.add_argument('--on',action='store_false');p.add_argument('rest',nargs='*')", ['-vvn12', '--on', '--', '-x', '--number=8'], False)['namespace']['number'] == 12
    assert (n.get_int('number') or { panic(err.msg()) }) == 12
    // python: argparse_probe("p=argparse.ArgumentParser(prog='tool');p.add_argument('-v',action='count',default=2);p.add_argument('-n','--number',type=int);p.add_argument('--on',action='store_false');p.add_argument('rest',nargs='*')", ['-vvn12', '--on', '--', '-x', '--number=8'], False)['namespace']['on'] == False
    assert !(n.get_bool('on') or { panic(err.msg()) })
    // python: argparse_probe("p=argparse.ArgumentParser(prog='tool');p.add_argument('-v',action='count',default=2);p.add_argument('-n','--number',type=int);p.add_argument('--on',action='store_false');p.add_argument('rest',nargs='*')", ['-vvn12', '--on', '--', '-x', '--number=8'], False)['namespace']['rest'] == ['-x', '--number=8']
    assert (n.get_strings('rest') or { panic(err.msg()) }) == ['-x','--number=8']
    negative := p.parse_args(['--num', '-12']) or { panic(err.msg()) }
    // python: argparse_probe("p=argparse.ArgumentParser(prog='tool');p.add_argument('-v',action='count',default=2);p.add_argument('-n','--number',type=int);p.add_argument('--on',action='store_false');p.add_argument('rest',nargs='*')", ['--num', '-12'], False)['namespace']['number'] == -12
    assert (negative.get_int('number') or { panic(err.msg()) }) == -12
}
fn test_argparse_append_and_nargs() {
    p := new_parser(prog: 'tool', emit_output: false)
    p.add_argument(['--tag'], action: 'append', default_value: pyrt.from_strings(['base'])) or { panic(err.msg()) }
    p.add_argument(['--pair'], action: 'append', nargs: '2', value_type: .int_type) or { panic(err.msg()) }
    p.add_argument(['--maybe'], nargs: '?', const_value: pyrt.Value('4'), default_value: pyrt.Value('2'), value_type: .int_type) or { panic(err.msg()) }
    p.add_argument(['--many'], nargs: '+', value_type: .int_type) or { panic(err.msg()) }
    n := p.parse_args(['--tag','a','--tag','b','--pair','1','2','--pair','3','4','--maybe','--many','5','6']) or { panic(err.msg()) }
    // python: argparse_probe("p=argparse.ArgumentParser(prog='tool');p.add_argument('--tag',action='append',default=['base']);p.add_argument('--pair',action='append',nargs=2,type=int);p.add_argument('--maybe',nargs='?',const='4',default='2',type=int);p.add_argument('--many',nargs='+',type=int)", ['--tag', 'a', '--tag', 'b', '--pair', '1', '2', '--pair', '3', '4', '--maybe', '--many', '5', '6'], False)['namespace']['tag'] == ['base', 'a', 'b']
    assert pyrt.repr(n.get('tag')) == "['base', 'a', 'b']"
    // python: argparse_probe("p=argparse.ArgumentParser(prog='tool');p.add_argument('--tag',action='append',default=['base']);p.add_argument('--pair',action='append',nargs=2,type=int);p.add_argument('--maybe',nargs='?',const='4',default='2',type=int);p.add_argument('--many',nargs='+',type=int)", ['--tag', 'a', '--tag', 'b', '--pair', '1', '2', '--pair', '3', '4', '--maybe', '--many', '5', '6'], False)['namespace']['pair'] == [[1, 2], [3, 4]]
    assert pyrt.repr(n.get('pair')) == '[[1, 2], [3, 4]]'
    // python: argparse_probe("p=argparse.ArgumentParser(prog='tool');p.add_argument('--tag',action='append',default=['base']);p.add_argument('--pair',action='append',nargs=2,type=int);p.add_argument('--maybe',nargs='?',const='4',default='2',type=int);p.add_argument('--many',nargs='+',type=int)", ['--tag', 'a', '--tag', 'b', '--pair', '1', '2', '--pair', '3', '4', '--maybe', '--many', '5', '6'], False)['namespace']['maybe'] == 4
    assert (n.get_int('maybe') or { panic(err.msg()) }) == 4
    // python: argparse_probe("p=argparse.ArgumentParser(prog='tool');p.add_argument('--tag',action='append',default=['base']);p.add_argument('--pair',action='append',nargs=2,type=int);p.add_argument('--maybe',nargs='?',const='4',default='2',type=int);p.add_argument('--many',nargs='+',type=int)", ['--tag', 'a', '--tag', 'b', '--pair', '1', '2', '--pair', '3', '4', '--maybe', '--many', '5', '6'], False)['namespace']['many'] == [5, 6]
    assert pyrt.repr(n.get('many')) == '[5, 6]'
    again := p.parse_args([]string{}) or { panic(err.msg()) }
    // python: argparse_probe("p=argparse.ArgumentParser(prog='tool');p.add_argument('--tag',action='append',default=['base']);p.add_argument('--pair',action='append',nargs=2,type=int);p.add_argument('--maybe',nargs='?',const='4',default='2',type=int);p.add_argument('--many',nargs='+',type=int)", [], False)['namespace']['tag'] == ['base']
    assert pyrt.repr(again.get('tag')) == "['base']"
    // python: argparse_probe("p=argparse.ArgumentParser(prog='tool');p.add_argument('--tag',action='append',default=['base']);p.add_argument('--pair',action='append',nargs=2,type=int);p.add_argument('--maybe',nargs='?',const='4',default='2',type=int);p.add_argument('--many',nargs='+',type=int)", [], False)['namespace']['maybe'] == 2
    assert (again.get_int('maybe') or { panic(err.msg()) }) == 2
}
fn test_argparse_positional_reservations() {
    p := new_parser(prog: 'tool', emit_output: false)
    p.add_argument(['head'], nargs: '?') or { panic(err.msg()) }
    p.add_argument(['middle'], nargs: '*') or { panic(err.msg()) }
    p.add_argument(['tail']) or { panic(err.msg()) }
    one := p.parse_args(['z']) or { panic(err.msg()) }
    // python: argparse_probe("p=argparse.ArgumentParser(prog='tool');p.add_argument('head',nargs='?');p.add_argument('middle',nargs='*');p.add_argument('tail')", ['z'], False)['namespace']['head'] == None
    assert one.get('head') is pyrt.NoneType
    // python: argparse_probe("p=argparse.ArgumentParser(prog='tool');p.add_argument('head',nargs='?');p.add_argument('middle',nargs='*');p.add_argument('tail')", ['z'], False)['namespace']['middle'] == []
    assert (one.get_strings('middle') or { panic(err.msg()) }).len == 0
    // python: argparse_probe("p=argparse.ArgumentParser(prog='tool');p.add_argument('head',nargs='?');p.add_argument('middle',nargs='*');p.add_argument('tail')", ['z'], False)['namespace']['tail'] == 'z'
    assert (one.get_str('tail') or { panic(err.msg()) }) == 'z'
    many := p.parse_args(['a','b','c','d']) or { panic(err.msg()) }
    // python: argparse_probe("p=argparse.ArgumentParser(prog='tool');p.add_argument('head',nargs='?');p.add_argument('middle',nargs='*');p.add_argument('tail')", ['a', 'b', 'c', 'd'], False)['namespace']['head'] == 'a'
    assert (many.get_str('head') or { panic(err.msg()) }) == 'a'
    // python: argparse_probe("p=argparse.ArgumentParser(prog='tool');p.add_argument('head',nargs='?');p.add_argument('middle',nargs='*');p.add_argument('tail')", ['a', 'b', 'c', 'd'], False)['namespace']['middle'] == ['b', 'c']
    assert (many.get_strings('middle') or { panic(err.msg()) }) == ['b','c']
}
fn test_argparse_defaults_and_suppression() {
    p := new_parser(prog: 'tool', emit_output: false)
    p.set_defaults({'number': pyrt.Value('8')})
    p.add_argument(['--number'], value_type: .int_type) or { panic(err.msg()) }
    p.add_argument(['--flag'], action: 'store_true', default_value: pyrt.none_) or { panic(err.msg()) }
    p.add_argument(['--hidden'], default_value: pyrt.Value(suppress)) or { panic(err.msg()) }
    p.set_defaults({'extra': pyrt.Value('yes')})
    n := p.parse_args([]string{}) or { panic(err.msg()) }
    // python: argparse_probe("p=argparse.ArgumentParser(prog='tool');p.set_defaults(number='8');p.add_argument('--number',type=int);p.add_argument('--flag',action='store_true',default=None);p.add_argument('--hidden',default=argparse.SUPPRESS);p.set_defaults(extra='yes')", [], False)['namespace']['number'] == 8
    assert (n.get_int('number') or { panic(err.msg()) }) == 8
    // python: argparse_probe("p=argparse.ArgumentParser(prog='tool');p.set_defaults(number='8');p.add_argument('--number',type=int);p.add_argument('--flag',action='store_true',default=None);p.add_argument('--hidden',default=argparse.SUPPRESS);p.set_defaults(extra='yes')", [], False)['namespace']['flag'] == None
    assert n.get('flag') is pyrt.NoneType
    // python: argparse_probe("p=argparse.ArgumentParser(prog='tool');p.set_defaults(number='8');p.add_argument('--number',type=int);p.add_argument('--flag',action='store_true',default=None);p.add_argument('--hidden',default=argparse.SUPPRESS);p.set_defaults(extra='yes')", [], False)['namespace']['extra'] == 'yes'
    assert (n.get_str('extra') or { panic(err.msg()) }) == 'yes'
    // python: 'hidden' not in argparse_probe("p=argparse.ArgumentParser(prog='tool');p.set_defaults(number='8');p.add_argument('--number',type=int);p.add_argument('--flag',action='store_true',default=None);p.add_argument('--hidden',default=argparse.SUPPRESS);p.set_defaults(extra='yes')", [])['namespace']
    assert !n.has('hidden')
    // python: exec_result("import argparse;p=argparse.ArgumentParser();p.set_defaults(number='8');p.add_argument('--number',type=int)", "p.get_default('number') == '8'")
    assert pyrt.str(p.get_default('number')) == '8'
}
fn test_argparse_subcommands() {
    p := new_parser(prog: 'tool', emit_output: false)
    p.add_argument(['--verbose'], action: 'store_true') or { panic(err.msg()) }
    subs := p.add_subparsers(dest: 'command', required: true) or { panic(err.msg()) }
    run_parser := subs.add_parser('run') or { panic(err.msg()) }
    run_parser.add_argument(['file']) or { panic(err.msg()) }
    run_parser.add_argument(['--workers'], value_type: .int_type, default_value: pyrt.Value(1)) or { panic(err.msg()) }
    run_parser.set_defaults({'handler': pyrt.Value('runner')})
    subs.add_parser('list') or { panic(err.msg()) }
    n := p.parse_args(['--verbose','run','--workers=3','input']) or { panic(err.msg()) }
    // python: argparse_probe("p=argparse.ArgumentParser(prog='tool');p.add_argument('--verbose',action='store_true');subs=p.add_subparsers(dest='command',required=True);run=subs.add_parser('run');run.add_argument('file');run.add_argument('--workers',type=int,default=1);run.set_defaults(handler='runner');subs.add_parser('list')", ['--verbose', 'run', '--workers=3', 'input'], False)['namespace']['command'] == 'run'
    assert (n.get_str('command') or { panic(err.msg()) }) == 'run'
    // python: argparse_probe("p=argparse.ArgumentParser(prog='tool');p.add_argument('--verbose',action='store_true');subs=p.add_subparsers(dest='command',required=True);run=subs.add_parser('run');run.add_argument('file');run.add_argument('--workers',type=int,default=1);run.set_defaults(handler='runner');subs.add_parser('list')", ['--verbose', 'run', '--workers=3', 'input'], False)['namespace']['file'] == 'input'
    assert (n.get_str('file') or { panic(err.msg()) }) == 'input'
    // python: argparse_probe("p=argparse.ArgumentParser(prog='tool');p.add_argument('--verbose',action='store_true');subs=p.add_subparsers(dest='command',required=True);run=subs.add_parser('run');run.add_argument('file');run.add_argument('--workers',type=int,default=1);run.set_defaults(handler='runner');subs.add_parser('list')", ['--verbose', 'run', '--workers=3', 'input'], False)['namespace']['handler'] == 'runner'
    assert (n.get_str('handler') or { panic(err.msg()) }) == 'runner'
    // python: argparse_probe("p=argparse.ArgumentParser(prog='tool');p.add_argument('--verbose',action='store_true');subs=p.add_subparsers(dest='command',required=True);run=subs.add_parser('run');run.add_argument('file');run.add_argument('--workers',type=int,default=1);run.set_defaults(handler='runner');subs.add_parser('list')", ['--verbose', 'run', '--workers=3', 'input'], False)['namespace']['workers'] == 3
    assert (n.get_int('workers') or { panic(err.msg()) }) == 3
    // python: argparse_probe("p=argparse.ArgumentParser(prog='tool');p.add_argument('--verbose',action='store_true');subs=p.add_subparsers(dest='command',required=True);run=subs.add_parser('run');run.add_argument('file');run.add_argument('--workers',type=int,default=1);run.set_defaults(handler='runner');subs.add_parser('list')", ['--verbose', 'run', '--workers=3', 'input'], False)['namespace']['verbose'] == True
    assert n.get_bool('verbose') or { panic(err.msg()) }
    // python: argparse_probe("p=argparse.ArgumentParser(prog='tool');p.add_argument('--verbose',action='store_true');subs=p.add_subparsers(dest='command',required=True);run=subs.add_parser('run');run.add_argument('file');run.add_argument('--workers',type=int,default=1);run.set_defaults(handler='runner');subs.add_parser('list')", [], False)['exception'] == 'SystemExit|2'
    assert argparse_exit(p, []string{}) == 'SystemExit|2'
    // python: argparse_probe("p=argparse.ArgumentParser(prog='tool');p.add_argument('--verbose',action='store_true');subs=p.add_subparsers(dest='command',required=True);run=subs.add_parser('run');run.add_argument('file');run.add_argument('--workers',type=int,default=1);run.set_defaults(handler='runner');subs.add_parser('list')", [], False)['stderr'] == 'usage: tool [-h] [--verbose] {run,list} ...\ntool: error: the following arguments are required: command\n'
    assert p.last_stderr() == 'usage: tool [-h] [--verbose] {run,list} ...\ntool: error: the following arguments are required: command\n'
    // python: argparse_probe("p=argparse.ArgumentParser(prog='tool');p.add_argument('--verbose',action='store_true');subs=p.add_subparsers(dest='command',required=True);run=subs.add_parser('run');run.add_argument('file');run.add_argument('--workers',type=int,default=1);run.set_defaults(handler='runner');subs.add_parser('list')", ['unknown'], False)['exception'] == 'SystemExit|2'
    assert argparse_exit(p, ['unknown']) == 'SystemExit|2'
    // python: argparse_probe("p=argparse.ArgumentParser(prog='tool');p.add_argument('--verbose',action='store_true');subs=p.add_subparsers(dest='command',required=True);run=subs.add_parser('run');run.add_argument('file');run.add_argument('--workers',type=int,default=1);run.set_defaults(handler='runner');subs.add_parser('list')", ['unknown'], False)['stderr'] == "usage: tool [-h] [--verbose] {run,list} ...\ntool: error: argument command: invalid choice: 'unknown' (choose from 'run', 'list')\n"
    assert p.last_stderr() == 'usage: tool [-h] [--verbose] {run,list} ...\ntool: error: argument command: invalid choice: \'unknown\' (choose from \'run\', \'list\')\n'
    // python: argparse_probe("p=argparse.ArgumentParser(prog='tool');p.add_argument('--verbose',action='store_true');subs=p.add_subparsers(dest='command',required=True);run=subs.add_parser('run');run.add_argument('file');run.add_argument('--workers',type=int,default=1);run.set_defaults(handler='runner');subs.add_parser('list')", ['run'], False)['exception'] == 'SystemExit|2'
    assert argparse_exit(p, ['run']) == 'SystemExit|2'
    // python: argparse_probe("p=argparse.ArgumentParser(prog='tool');p.add_argument('--verbose',action='store_true');subs=p.add_subparsers(dest='command',required=True);run=subs.add_parser('run');run.add_argument('file');run.add_argument('--workers',type=int,default=1);run.set_defaults(handler='runner');subs.add_parser('list')", ['run'], False)['stderr'] == 'usage: tool run [-h] [--workers WORKERS] file\ntool run: error: the following arguments are required: file\n'
    assert p.last_stderr() == 'usage: tool run [-h] [--workers WORKERS] file\ntool run: error: the following arguments are required: file\n'
}
fn test_argparse_exclusive_groups() {
    p := new_parser(prog: 'tool', emit_output: false)
    group := p.add_mutually_exclusive_group(required: true)
    group.add_argument(['-a'], action: 'store_true') or { panic(err.msg()) }
    group.add_argument(['-b'], action: 'store_true') or { panic(err.msg()) }
    n := p.parse_args(['-a']) or { panic(err.msg()) }
    // python: argparse_probe("p=argparse.ArgumentParser(prog='tool');g=p.add_mutually_exclusive_group(required=True);g.add_argument('-a',action='store_true');g.add_argument('-b',action='store_true')", ['-a'], False)['namespace']['a'] == True
    assert n.get_bool('a') or { panic(err.msg()) }
    // python: argparse_probe("p=argparse.ArgumentParser(prog='tool');g=p.add_mutually_exclusive_group(required=True);g.add_argument('-a',action='store_true');g.add_argument('-b',action='store_true')", [], False)['exception'] == 'SystemExit|2'
    assert argparse_exit(p, []string{}) == 'SystemExit|2'
    // python: argparse_probe("p=argparse.ArgumentParser(prog='tool');g=p.add_mutually_exclusive_group(required=True);g.add_argument('-a',action='store_true');g.add_argument('-b',action='store_true')", [], False)['stderr'] == 'usage: tool [-h] (-a | -b)\ntool: error: one of the arguments -a -b is required\n'
    assert p.last_stderr() == 'usage: tool [-h] (-a | -b)\ntool: error: one of the arguments -a -b is required\n'
    // python: argparse_probe("p=argparse.ArgumentParser(prog='tool');g=p.add_mutually_exclusive_group(required=True);g.add_argument('-a',action='store_true');g.add_argument('-b',action='store_true')", ['-a', '-b'], False)['exception'] == 'SystemExit|2'
    assert argparse_exit(p, ['-a','-b']) == 'SystemExit|2'
    // python: argparse_probe("p=argparse.ArgumentParser(prog='tool');g=p.add_mutually_exclusive_group(required=True);g.add_argument('-a',action='store_true');g.add_argument('-b',action='store_true')", ['-a', '-b'], False)['stderr'] == 'usage: tool [-h] (-a | -b)\ntool: error: argument -b: not allowed with argument -a\n'
    assert p.last_stderr() == 'usage: tool [-h] (-a | -b)\ntool: error: argument -b: not allowed with argument -a\n'
}
fn test_argparse_known_args_order() {
    p := new_parser(prog: 'tool', emit_output: false)
    p.add_argument(['--number'], value_type: .int_type) or { panic(err.msg()) }
    parsed := p.parse_known_args(['x','--alien','--number','4','y']) or { panic(err.msg()) }
    // python: argparse_probe("p=argparse.ArgumentParser(prog='tool');p.add_argument('--number',type=int)", ['x', '--alien', '--number', '4', 'y'], True)['unknown'] == ['x', '--alien', 'y']
    assert parsed.unknown == ['x','--alien','y']
    // python: argparse_probe("p=argparse.ArgumentParser(prog='tool');p.add_argument('--number',type=int)", ['x', '--alien', '--number', '4', 'y'], True)['namespace']['number'] == 4
    assert (parsed.namespace.get_int('number') or { panic(err.msg()) }) == 4
    marker := p.parse_known_args(['--','-x']) or { panic(err.msg()) }
    // python: argparse_probe("p=argparse.ArgumentParser(prog='tool');p.add_argument('--number',type=int)", ['--', '-x'], True)['unknown'] == ['--', '-x']
    assert marker.unknown == ['--','-x']
}
fn test_argparse_help_and_version() {
    p := new_parser(prog: 'tool', description: 'Process files.', epilog: 'Done.', emit_output: false)
    p.add_argument(['file'], help: 'input file') or { panic(err.msg()) }
    p.add_argument(['-v','--verbose'], action: 'store_true', help: 'show details') or { panic(err.msg()) }
    // UNSURE[HELP_312_1]: exact CPython 3.12 layout; expected text verified on CPython 3.13.5 only.
    // python: argparse_probe("p=argparse.ArgumentParser(prog='tool',description='Process files.',epilog='Done.');p.add_argument('file',help='input file');p.add_argument('-v','--verbose',action='store_true',help='show details')", ['--help'], False)['help'] == 'usage: tool [-h] [-v] file\n\nProcess files.\n\npositional arguments:\n  file           input file\n\noptions:\n  -h, --help     show this help message and exit\n  -v, --verbose  show details\n\nDone.\n'
    assert p.format_help() == 'usage: tool [-h] [-v] file\n\nProcess files.\n\npositional arguments:\n  file           input file\n\noptions:\n  -h, --help     show this help message and exit\n  -v, --verbose  show details\n\nDone.\n'
    // UNSURE[HELP_312_2]: exact CPython 3.12 layout; expected text verified on CPython 3.13.5 only.
    // python: argparse_probe("p=argparse.ArgumentParser(prog='tool',description='Process files.',epilog='Done.');p.add_argument('file',help='input file');p.add_argument('-v','--verbose',action='store_true',help='show details')", ['--help'], False)['usage'] == 'usage: tool [-h] [-v] file\n'
    assert p.format_usage() == 'usage: tool [-h] [-v] file\n'
    // python: argparse_probe("p=argparse.ArgumentParser(prog='tool',description='Process files.',epilog='Done.');p.add_argument('file',help='input file');p.add_argument('-v','--verbose',action='store_true',help='show details')", ['--help'], False)['exception'] == 'SystemExit|0'
    assert argparse_exit(p, ['--help']) == 'SystemExit|0'
    // UNSURE[HELP_312_3]: exact CPython 3.12 layout; expected text verified on CPython 3.13.5 only.
    // python: argparse_probe("p=argparse.ArgumentParser(prog='tool',description='Process files.',epilog='Done.');p.add_argument('file',help='input file');p.add_argument('-v','--verbose',action='store_true',help='show details')", ['--help'], False)['stdout'] == 'usage: tool [-h] [-v] file\n\nProcess files.\n\npositional arguments:\n  file           input file\n\noptions:\n  -h, --help     show this help message and exit\n  -v, --verbose  show details\n\nDone.\n'
    assert p.last_stdout() == 'usage: tool [-h] [-v] file\n\nProcess files.\n\npositional arguments:\n  file           input file\n\noptions:\n  -h, --help     show this help message and exit\n  -v, --verbose  show details\n\nDone.\n'
    // python: argparse_probe("p=argparse.ArgumentParser(prog='tool',description='Process files.',epilog='Done.');p.add_argument('file',help='input file');p.add_argument('-v','--verbose',action='store_true',help='show details')", ['--help'], False)['stderr'] == ''
    assert p.last_stderr() == ''
    version_parser := new_parser(prog: 'app', emit_output: false)
    version_parser.add_argument(['--version'], action: 'version', version: '%(prog)s 1.0') or { panic(err.msg()) }
    // python: argparse_probe("p=argparse.ArgumentParser(prog='app');p.add_argument('--version',action='version',version='%(prog)s 1.0')", ['--version'], False)['exception'] == 'SystemExit|0'
    assert argparse_exit(version_parser, ['--version']) == 'SystemExit|0'
    // python: argparse_probe("p=argparse.ArgumentParser(prog='app');p.add_argument('--version',action='version',version='%(prog)s 1.0')", ['--version'], False)['stdout'] == 'app 1.0\n'
    assert version_parser.last_stdout() == 'app 1.0\n'
}
fn test_argparse_error_messages() {
    p0 := new_parser(prog: 'tool', emit_output: false)
    p0.add_argument(['--number'], value_type: .int_type) or { panic(err.msg()) }
    // python: argparse_probe("p=argparse.ArgumentParser(prog='tool');p.add_argument('--number',type=int)", ['--number', 'oops'], False)['exception'] == 'SystemExit|2'
    assert argparse_exit(p0, ['--number','oops']) == 'SystemExit|2'
    // python: argparse_probe("p=argparse.ArgumentParser(prog='tool');p.add_argument('--number',type=int)", ['--number', 'oops'], False)['stderr'] == "usage: tool [-h] [--number NUMBER]\ntool: error: argument --number: invalid int value: 'oops'\n"
    assert p0.last_stderr() == 'usage: tool [-h] [--number NUMBER]\ntool: error: argument --number: invalid int value: \'oops\'\n'
    p1 := new_parser(prog: 'tool', emit_output: false)
    p1.add_argument(['--number'], value_type: .int_type) or { panic(err.msg()) }
    // python: argparse_probe("p=argparse.ArgumentParser(prog='tool');p.add_argument('--number',type=int)", ['--number'], False)['exception'] == 'SystemExit|2'
    assert argparse_exit(p1, ['--number']) == 'SystemExit|2'
    // python: argparse_probe("p=argparse.ArgumentParser(prog='tool');p.add_argument('--number',type=int)", ['--number'], False)['stderr'] == 'usage: tool [-h] [--number NUMBER]\ntool: error: argument --number: expected one argument\n'
    assert p1.last_stderr() == 'usage: tool [-h] [--number NUMBER]\ntool: error: argument --number: expected one argument\n'
    p2 := new_parser(prog: 'tool', emit_output: false)
    p2.add_argument(['--ratio'], value_type: .float_type) or { panic(err.msg()) }
    // python: argparse_probe("p=argparse.ArgumentParser(prog='tool');p.add_argument('--ratio',type=float)", ['--ratio', 'oops'], False)['exception'] == 'SystemExit|2'
    assert argparse_exit(p2, ['--ratio','oops']) == 'SystemExit|2'
    // python: argparse_probe("p=argparse.ArgumentParser(prog='tool');p.add_argument('--ratio',type=float)", ['--ratio', 'oops'], False)['stderr'] == "usage: tool [-h] [--ratio RATIO]\ntool: error: argument --ratio: invalid float value: 'oops'\n"
    assert p2.last_stderr() == 'usage: tool [-h] [--ratio RATIO]\ntool: error: argument --ratio: invalid float value: \'oops\'\n'
    p3 := new_parser(prog: 'tool', emit_output: false)
    p3.add_argument(['--color'], choices: [pyrt.Value('red'),pyrt.Value('blue')]) or { panic(err.msg()) }
    // python: argparse_probe("p=argparse.ArgumentParser(prog='tool');p.add_argument('--color',choices=['red','blue'])", ['--color', 'green'], False)['exception'] == 'SystemExit|2'
    assert argparse_exit(p3, ['--color','green']) == 'SystemExit|2'
    // python: argparse_probe("p=argparse.ArgumentParser(prog='tool');p.add_argument('--color',choices=['red','blue'])", ['--color', 'green'], False)['stderr'] == "usage: tool [-h] [--color {red,blue}]\ntool: error: argument --color: invalid choice: 'green' (choose from 'red', 'blue')\n"
    assert p3.last_stderr() == 'usage: tool [-h] [--color {red,blue}]\ntool: error: argument --color: invalid choice: \'green\' (choose from \'red\', \'blue\')\n'
    p4 := new_parser(prog: 'tool', emit_output: false)
    p4.add_argument(['--key'], required: true) or { panic(err.msg()) }
    // python: argparse_probe("p=argparse.ArgumentParser(prog='tool');p.add_argument('--key',required=True)", [], False)['exception'] == 'SystemExit|2'
    assert argparse_exit(p4, []string{}) == 'SystemExit|2'
    // python: argparse_probe("p=argparse.ArgumentParser(prog='tool');p.add_argument('--key',required=True)", [], False)['stderr'] == 'usage: tool [-h] --key KEY\ntool: error: the following arguments are required: --key\n'
    assert p4.last_stderr() == 'usage: tool [-h] --key KEY\ntool: error: the following arguments are required: --key\n'
    p5 := new_parser(prog: 'tool', emit_output: false)
    p5.add_argument(['--many'], nargs: '+') or { panic(err.msg()) }
    // python: argparse_probe("p=argparse.ArgumentParser(prog='tool');p.add_argument('--many',nargs='+')", ['--many'], False)['exception'] == 'SystemExit|2'
    assert argparse_exit(p5, ['--many']) == 'SystemExit|2'
    // python: argparse_probe("p=argparse.ArgumentParser(prog='tool');p.add_argument('--many',nargs='+')", ['--many'], False)['stderr'] == 'usage: tool [-h] [--many MANY [MANY ...]]\ntool: error: argument --many: expected at least one argument\n'
    assert p5.last_stderr() == 'usage: tool [-h] [--many MANY [MANY ...]]\ntool: error: argument --many: expected at least one argument\n'
    p6 := new_parser(prog: 'tool', emit_output: false)
    p6.add_argument(['--pair'], nargs: '2') or { panic(err.msg()) }
    // python: argparse_probe("p=argparse.ArgumentParser(prog='tool');p.add_argument('--pair',nargs=2)", ['--pair', 'x'], False)['exception'] == 'SystemExit|2'
    assert argparse_exit(p6, ['--pair','x']) == 'SystemExit|2'
    // python: argparse_probe("p=argparse.ArgumentParser(prog='tool');p.add_argument('--pair',nargs=2)", ['--pair', 'x'], False)['stderr'] == 'usage: tool [-h] [--pair PAIR PAIR]\ntool: error: argument --pair: expected 2 arguments\n'
    assert p6.last_stderr() == 'usage: tool [-h] [--pair PAIR PAIR]\ntool: error: argument --pair: expected 2 arguments\n'
    p7 := new_parser(prog: 'tool', emit_output: false)
    p7.add_argument(['--flag'], action: 'store_true') or { panic(err.msg()) }
    // python: argparse_probe("p=argparse.ArgumentParser(prog='tool');p.add_argument('--flag',action='store_true')", ['--flag=x'], False)['exception'] == 'SystemExit|2'
    assert argparse_exit(p7, ['--flag=x']) == 'SystemExit|2'
    // python: argparse_probe("p=argparse.ArgumentParser(prog='tool');p.add_argument('--flag',action='store_true')", ['--flag=x'], False)['stderr'] == "usage: tool [-h] [--flag]\ntool: error: argument --flag: ignored explicit argument 'x'\n"
    assert p7.last_stderr() == 'usage: tool [-h] [--flag]\ntool: error: argument --flag: ignored explicit argument \'x\'\n'
}
fn test_argparse_subparser_choice_labels() {
    with_dest := new_parser(prog: 'tool', emit_output: false)
    dest_sub := with_dest.add_subparsers(dest: 'command', required: true) or { panic(err.msg()) }
    dest_sub.add_parser('run') or { panic(err.msg()) }
    dest_sub.add_parser('list') or { panic(err.msg()) }
    // python: argparse_probe("p=argparse.ArgumentParser(prog='tool');s=p.add_subparsers(dest='command',required=True);s.add_parser('run');s.add_parser('list')", ['unknown'], False)['exception'] == 'SystemExit|2'
    assert argparse_exit(with_dest, ['unknown']) == 'SystemExit|2'
    // python: argparse_probe("p=argparse.ArgumentParser(prog='tool');s=p.add_subparsers(dest='command',required=True);s.add_parser('run');s.add_parser('list')", ['unknown'], False)['stderr'] == "usage: tool [-h] {run,list} ...\ntool: error: argument command: invalid choice: 'unknown' (choose from 'run', 'list')\n"  # CPython 3.15 choice formatting
    assert with_dest.last_stderr() == 'usage: tool [-h] {run,list} ...\ntool: error: argument command: invalid choice: \'unknown\' (choose from \'run\', \'list\')\n'
    without_dest := new_parser(prog: 'tool', emit_output: false)
    bare_sub := without_dest.add_subparsers(required: true) or { panic(err.msg()) }
    bare_sub.add_parser('run') or { panic(err.msg()) }
    bare_sub.add_parser('list') or { panic(err.msg()) }
    // python: argparse_probe("p=argparse.ArgumentParser(prog='tool');s=p.add_subparsers(required=True);s.add_parser('run');s.add_parser('list')", ['unknown'], False)['exception'] == 'SystemExit|2'
    assert argparse_exit(without_dest, ['unknown']) == 'SystemExit|2'
    // python: argparse_probe("p=argparse.ArgumentParser(prog='tool');s=p.add_subparsers(required=True);s.add_parser('run');s.add_parser('list')", ['unknown'], False)['stderr'] == "usage: tool [-h] {run,list} ...\ntool: error: argument {run,list}: invalid choice: 'unknown' (choose from 'run', 'list')\n"  # CPython 3.15 choice formatting
    assert without_dest.last_stderr() == 'usage: tool [-h] {run,list} ...\ntool: error: argument {run,list}: invalid choice: \'unknown\' (choose from \'run\', \'list\')\n'
}

fn test_argparse_numeric_conversion() {
    p := new_parser(prog: 'tool', emit_output: false)
    p.add_argument(['--i'], value_type: .int_type) or { panic(err.msg()) }
    p.add_argument(['--f'], value_type: .float_type) or { panic(err.msg()) }
    i0 := p.parse_args(['--i='+'1_234']) or { panic(err.msg()) }
    // python: argparse_probe("p=argparse.ArgumentParser(prog='tool');p.add_argument('--i',type=int);p.add_argument('--f',type=float)", ['--i=1_234'], False)['namespace']['i'] == 1234
    assert (i0.get_int('i') or { panic(err.msg()) }) == i64(1234)
    i1 := p.parse_args(['--i='+'+00042']) or { panic(err.msg()) }
    // python: argparse_probe("p=argparse.ArgumentParser(prog='tool');p.add_argument('--i',type=int);p.add_argument('--f',type=float)", ['--i=+00042'], False)['namespace']['i'] == 42
    assert (i1.get_int('i') or { panic(err.msg()) }) == i64(42)
    i2 := p.parse_args(['--i='+'-9223372036854775808']) or { panic(err.msg()) }
    // python: argparse_probe("p=argparse.ArgumentParser(prog='tool');p.add_argument('--i',type=int);p.add_argument('--f',type=float)", ['--i=-9223372036854775808'], False)['namespace']['i'] == -9223372036854775808
    assert (i2.get_int('i') or { panic(err.msg()) }) == i64(-9223372036854775807) - 1
    f0 := p.parse_args(['--f='+'.25']) or { panic(err.msg()) }
    // python: argparse_probe("p=argparse.ArgumentParser(prog='tool');p.add_argument('--i',type=int);p.add_argument('--f',type=float)", ['--f=.25'], False)['namespace']['f'] == 0.25
    assert (f0.get_float('f') or { panic(err.msg()) }) == 0.25
    f1 := p.parse_args(['--f='+'0012.']) or { panic(err.msg()) }
    // python: argparse_probe("p=argparse.ArgumentParser(prog='tool');p.add_argument('--i',type=int);p.add_argument('--f',type=float)", ['--f=0012.'], False)['namespace']['f'] == 12.0
    assert (f1.get_float('f') or { panic(err.msg()) }) == 12.0
    f2 := p.parse_args(['--f='+'+1_000.5']) or { panic(err.msg()) }
    // python: argparse_probe("p=argparse.ArgumentParser(prog='tool');p.add_argument('--i',type=int);p.add_argument('--f',type=float)", ['--f=+1_000.5'], False)['namespace']['f'] == 1000.5
    assert (f2.get_float('f') or { panic(err.msg()) }) == 1000.5
    f3 := p.parse_args(['--f='+'-1e-3']) or { panic(err.msg()) }
    // python: argparse_probe("p=argparse.ArgumentParser(prog='tool');p.add_argument('--i',type=int);p.add_argument('--f',type=float)", ['--f=-1e-3'], False)['namespace']['f'] == -0.001
    assert (f3.get_float('f') or { panic(err.msg()) }) == -0.001
    negative_zero := p.parse_args(['--f=-0']) or { panic(err.msg()) }
    // python: repr(float('-0')) == '-0.0'
    assert pyrt.repr(negative_zero.get('f')) == '-0.0'
}
fn test_argparse_positional_boundaries() {
    p := new_parser(prog: 'tool', emit_output: false)
    p.add_argument(['files'], nargs: '*') or { panic(err.msg()) }
    p.add_argument(['--flag']) or { panic(err.msg()) }
    parsed := p.parse_known_args(['a','--flag','b','c']) or { panic(err.msg()) }
    // python: argparse_probe("p=argparse.ArgumentParser(prog='tool');p.add_argument('files',nargs='*');p.add_argument('--flag')", ['a', '--flag', 'b', 'c'], True)['namespace']['files'] == ['a']
    assert pyrt.repr(parsed.namespace.get('files')) == "['a']"
    // python: argparse_probe("p=argparse.ArgumentParser(prog='tool');p.add_argument('files',nargs='*');p.add_argument('--flag')", ['a', '--flag', 'b', 'c'], True)['unknown'] == ['c']
    assert parsed.unknown == ['c']
    pair := new_parser(prog: 'pair', emit_output: false)
    pair.add_argument(['values'], nargs: '2') or { panic(err.msg()) }
    pair.add_argument(['-v'], action: 'store_true') or { panic(err.msg()) }
    grouped := pair.parse_known_args(['a','-v','b','c']) or { panic(err.msg()) }
    // python: argparse_probe("p=argparse.ArgumentParser(prog='pair');p.add_argument('values',nargs=2);p.add_argument('-v',action='store_true')", ['a', '-v', 'b', 'c'], True)['namespace']['values'] == ['b', 'c']
    assert pyrt.repr(grouped.namespace.get('values')) == "['b', 'c']"
    // python: argparse_probe("p=argparse.ArgumentParser(prog='pair');p.add_argument('values',nargs=2);p.add_argument('-v',action='store_true')", ['a', '-v', 'b', 'c'], True)['unknown'] == ['a']
    assert grouped.unknown == ['a']
}
fn namespace_missing(which int) string {
    n := new_namespace(map[string]pyrt.Value{})
    if which == 0 { n.get_str('absent') or { return err.msg() } }
    if which == 1 { n.get_int('absent') or { return err.msg() } }
    if which == 2 { n.get_float('absent') or { return err.msg() } }
    if which == 3 { n.get_bool('absent') or { return err.msg() } }
    if which == 4 { n.get_strings('absent') or { return err.msg() } }
    if which == 5 { n.require('absent') or { return err.msg() } }
    if which == 6 { n.getattr('absent') or { return err.msg() } }
    return '<no error>'
}
fn test_namespace_missing_and_raw_helpers() {
    // python: error_text(lambda: getattr(__import__('argparse').Namespace(), 'absent')) == "AttributeError|'Namespace' object has no attribute 'absent'"
    assert namespace_missing(0) == "'Namespace' object has no attribute 'absent'"
    // python: error_text(lambda: getattr(__import__('argparse').Namespace(), 'absent')) == "AttributeError|'Namespace' object has no attribute 'absent'"
    assert namespace_missing(1) == "'Namespace' object has no attribute 'absent'"
    // python: error_text(lambda: getattr(__import__('argparse').Namespace(), 'absent')) == "AttributeError|'Namespace' object has no attribute 'absent'"
    assert namespace_missing(2) == "'Namespace' object has no attribute 'absent'"
    // python: error_text(lambda: getattr(__import__('argparse').Namespace(), 'absent')) == "AttributeError|'Namespace' object has no attribute 'absent'"
    assert namespace_missing(3) == "'Namespace' object has no attribute 'absent'"
    // python: error_text(lambda: getattr(__import__('argparse').Namespace(), 'absent')) == "AttributeError|'Namespace' object has no attribute 'absent'"
    assert namespace_missing(4) == "'Namespace' object has no attribute 'absent'"
    // python: error_text(lambda: getattr(__import__('argparse').Namespace(), 'absent')) == "AttributeError|'Namespace' object has no attribute 'absent'"
    assert namespace_missing(5) == "'Namespace' object has no attribute 'absent'"
    // python: error_text(lambda: getattr(__import__('argparse').Namespace(), 'absent')) == "AttributeError|'Namespace' object has no attribute 'absent'"
    assert namespace_missing(6) == "'Namespace' object has no attribute 'absent'"
    n := new_namespace(map[string]pyrt.Value{'ready': pyrt.Value(true)})
    // python: getattr(__import__('argparse').Namespace(), 'missing', None) is None
    assert n.get('missing') is pyrt.NoneType
    // python: type(__import__('argparse').Namespace()).__name__ == 'Namespace'
    assert n.class_name() == 'Namespace'
    // python: hasattr(__import__('argparse').Namespace(ready=True), 'ready')
    assert n.has('ready')
    // python: (lambda n: id(n) == id(n))(__import__('argparse').Namespace())
    assert n.pyrt_identity() == n.pyrt_identity()
}
