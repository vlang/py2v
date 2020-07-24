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

@contextlib.contextmanager
def new_scope(visitor):
    visitor.scope.append(set())
    try:
        yield
    finally:
        visitor.scope.pop()


class Py2V(ast.NodeVisitor):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.scope = [set()]
        self.file = vast.File(mod=vast.Module(name='main'), imports=set(), stmts=[])

    
    def visit(self, node):
        print(node)
        return super().visit(node)
        
    def visit_Constant(self, node):
        return utils.deval(node.value)
        
    def visit_Module(self, module):
        for child in module.body:
            if node := self.visit(child):
                self.file.stmts.append(node)
            
    def visit_Arg(self, arg):
        return vast.Arg(name=arg.arg,
                        typ=typs.translate(arg.annotation),
                        is_mut=True,  # TODO: not mut if not changed
                        is_hidden=False)
            

    def visit_FunctionDef(self, definition: ast.FunctionDef) -> vast.FnDecl:
        args = []
        with new_scope(self):
            for arg in definition.args.args:  # TODO: support other kinds of args
                args.append(self.visit(arg))
                
            stmts = []
            for child in definition.body:
                if node := self.visit(child):
                    stmts.append(node)


        return vast.FnDecl(name=definition.name,
                           mod=self.file.mod.name,
                           args=args,
                           stmts=stmts,
                           return_type=typs.translate(definition.returns))

        
    def visit_Expr(self, expr):
        return self.visit(expr.value)
        
    def visit_Call(self, call):
        return calls.translate_call(call)
        
    def visit_If(self, if_node):
        if len(self.scope) == 1:  # top level if __name__ == '__main__' checks are discarded
            if all([getattr(if_node.test.left, 'id', '') == '__name__' or getattr(if_node.test.comparators[0], 'id', '') == '__name__', isinstance(if_node.test.ops[0], ast.Eq)]):  # This is badly coded on purpose so I have an excuse to remove it and properly distribute the body to fn main later
                return

    def visit_Assign(self, assign):
        op = ':='
        ident = vast.Ident(name=assign.targets[0].id)
        for scope in reversed(self.scope):
            for i in scope:  # 99% chance that there's a better implementation for this
                if ident.name == i.name:
                    op = '='
                    i.is_mut = True
        self.scope[-1].add(ident)

        return vast.AssignStmt(left=ident, op=op, right=self.visit(assign.value))
        
    def visit_Name(self, name):
        return vast.Ident(name=name.id)

        
    def visit_BinOp(self, binop):
        return vast.InfixExpr(left=self.visit(binop.left), op=OPERATORS[type(binop.op)], right=self.visit(binop.right))

    
    def generic_visit(self, node):
        raise Exception('unhandled {node}')

def main():
    with open(sys.argv[1]) as f:  # TODO: use argparse
        parsed = ast.parse(f.read())
    p = Py2V()
    p.visit(parsed)
    with open('out.v', 'w') as f:
        f.write(str(p.file))
    
if __name__ == '__main__':
    main()
