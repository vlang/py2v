import ast
import contextlib
import io
import sys
from collections import defaultdict

import calls
import typs
import utils
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
             ast.BitAnd: '&'}


class Py2V(ast.NodeVisitor):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.scope = [set()]
        self.file = vast.File(children=[vast.ModuleDecl(name='main')])

    def visit(self, node):
        print(node)
        return super().visit(node)
        
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
        if len(self.scope) == 1:  # top level if __name__ == '__main__' checks are discarded
            if all([getattr(if_node.test.left, 'id', '') == '__name__' or getattr(if_node.test.comparators[0], 'id', '') == '__name__', isinstance(if_node.test.ops[0], ast.Eq)]):  # This is badly coded on purpose so I have an excuse to remove it and properly distribute the body to fn main later
                return

    def visit_Assign(self, assign):
        return vast.Assign(value=self.visit(assign.value), children=[*map(self.visit, assign.targets)])
        
    def visit_Name(self, name):
        return vast.Ident(name=name.id)

        
    def visit_BinOp(self, binop):
        return vast.Infix(left=self.visit(binop.left), op=OPERATORS[type(binop.op)], right=self.visit(binop.right))

    
    def generic_visit(self, node):
        raise Exception('unhandled {node}')
    

def show_tree(node):
    listed = [node.__class__.__qualname__]
    for child in node.children:
        assert child.parent == node
        listed.append('->' + show_tree(child))
    return '\n'.join(listed)


def main():
    with open(sys.argv[1]) as f:  # TODO: use argparse
        parsed = ast.parse(f.read())
    p = Py2V()
    p.visit(parsed)
    print(show_tree(p.file))
    with open('out.v', 'w') as f:
        f.write(str(p.file))
    
if __name__ == '__main__':
    main()
