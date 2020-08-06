#!/usr/bin/env python3

import argparse
import ast
import contextlib
import io
import sys
from pathlib import Path

import calls
import typs
import vast

OPERATORS = {ast.Add: '+',
             ast.Sub: '-',
             ast.Mult: '*',
             ast.Div: '/',
             ast.FloorDiv: '/',  # TODO: round this
             ast.Mod: '%',
             ast.Pow: '',  # TODO: Implement this
             ast.LShift: '<<',
             ast.RShift: '>>',
             ast.BitOr: '|',
             ast.BitXor: '^',
             ast.BitAnd: '&',
             ast.Eq: '==',
             ast.NotEq: '!=',
             ast.Lt: '<',
             ast.LtE: '<=',
             ast.Gt: '>',
             ast.GtE: '>=',
             ast.Is: 'is',
             ast.IsNot: '!is',
             ast.In: 'in',
             ast.NotIn: '!in'}


class Py2V(ast.NodeVisitor):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.file = vast.File()
        
    def visit_Constant(self, node):
        return vast.Literal(value=node.value)
        
    def visit_Module(self, module):
        for child in module.body:
            if node := self.visit(child):
                self.file.add_child(node)


    def visit_Arg(self, arg):
        return vast.Arg(name=arg.arg,
                        typ=typs.translate(arg.annotation),
                        is_mut=True,  # TODO: not mut if not changed
                        is_hidden=False)
            

    def visit_FunctionDef(self, definition: ast.FunctionDef) -> vast.FunctionDecl:
        return vast.FunctionDecl(name=definition.name,
                                 #returns=vast.Type.from_annotation(definition.returns),  TODO: multiple returns
                                 args=[*map(self.visit, definition.args.args)],  #TODO: kwargs
                                 children=[*map(self.visit, definition.body)])


    def visit_Expr(self, expr):
        return self.visit(expr.value)
        
    def visit_Call(self, call):
        if isinstance(call.func, ast.Name):
            return vast.FunctionCall(name=call.func.id,
                                     module=self.file.children[0].name,
                                     children=[*map(self.visit, call.args), *map(self.visit, call.keywords)])
        elif isinstance(call.func, ast.Attribute):
            return vast.FunctionCall(name=call.func.attr,
                                     module=self.file.children[0].name,
                                     children=[*map(self.visit, call.args), *map(self.visit, call.keywords)],
                                     left=self.visit(call.func.value))
        raise Exception(f'unhandled type {type(call.func)}')
        
    def visit_If(self, if_node):
        return vast.If(test=self.visit(if_node.test), else_=[*map(self.visit, if_node.orelse)], children=[*map(self.visit, if_node.body)])

    def visit_Assign(self, assign):
        return vast.Assign(value=self.visit(assign.value), children=[*map(self.visit, assign.targets)])
        
    def visit_Name(self, name):
        return vast.Ident(name=name.id)
        
    def visit_BinOp(self, binop):
        return vast.Infix(left=self.visit(binop.left), op=OPERATORS[type(binop.op)], right=self.visit(binop.right))

    def visit_arg(self, arg):
        return vast.Ident(name=arg.arg, typ=vast.Type.from_annotation(arg.annotation))

    def visit_Return(self, ret):
        value = self.visit(ret.value)
        if isinstance(value, (tuple, list)):
            return vast.Return(children=[*value])
        return vast.Return(children=[value])

    def visit_NoneType(self, value):
        return vast.Literal(value=value)

    def visit_Raise(self, raise_node):
        return vast.Return(children=[vast.FunctionCall(name='error', module='builtin')])  # TODO: better error handling

    def visit_Compare(self, compare):
        left = self.visit(compare.left)
        comps = []
        for op, comp in zip(compare.ops, compare.comparators):
            comps.append(vast.Infix(left=left, right=self.visit(comp), op=OPERATORS[type(op)]))
        while len(comps) > 1:
            comps.insert(vast.Infix(left=comps.pop(), right=comps.pop(), op='&&'))
        return comps[0]
    
    def generic_visit(self, node):
        raise Exception(f'unhandled {type(node)}')
    
    
def parse_file(path: Path, module: str = 'main') -> vast.File:
    p = Py2V()
    p.file.add_child(vast.ModuleDecl(name=module))
    p.visit(ast.parse(path.read_text()))
    
    return p.file


def main():
    parser = argparse.ArgumentParser(description='A Python to V transpiler.')
    parser.add_argument('input', help='input file(or module) to transpile.', type=Path)
    parser.add_argument('-o', '--output', help='output file(or directory) to write into (default: input with .v suffix)', type=Path, default=None)
    
    args = parser.parse_args()

    if args.input.is_file():
        parsed = parse_file(args.input)
        output = args.output or args.input.with_suffix('.v')
        if not output.exists():
            output.write_text(str(parsed))
        else:
            print(f'ERROR: output file already exists')
    elif args.input.is_dir():
        output_dir = args.output or args.input
        output_dir.mkdir(exist_ok=True)
        for f in args.input.glob('*.py'):
            parsed = parse_file(f, module=args.input.name)
            output = output_dir / f'{f.stem}.v'
            if not output.exists():
                output.write_text(str(parsed))
            else:
                print(f'ERROR: output file "{output}"  already exists')
    else:
        print('ERROR: input does not exist')
        exit(2)
    
if __name__ == '__main__':
    main()
