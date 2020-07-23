import _ast
import ast
import sys

CALLS = {'print': 'println'}  # TODO: add an option to suppress this

def deval(value) -> str:
    if isinstance(value, str):
        return f'"{value}"'
    elif isinstance(value, bool) or value is None:
        return str(value).lower()
    else:
        return str(value)

def is_maincheck(test) -> bool:
    if not isinstance(test.left, ast.Name):
        return False
    
    if not test.left.id == '__main__':
        return False
    
    if not len(test.ops) == 1 or not isinstance(test.ops[0], ast.Eq):
        return False
    
    return True

def is_strformat(attr) -> bool:
    if not isinstance(attr.value, ast.Constant):
        return False
    
    if not isinstance(attr.value.value, str):
        return False
    
    if not attr.attr == 'format':
        return False
    
    return True


class Translator(ast.NodeVisitor):
    def visit_Constant(self, node):
        print(deval(node.value), end='')
        
    def visit_Module(self, module):
        print(f'module main')
        for child in module.body:
            self.visit(child)
            
    def visit_FunctionDef(self, definition):
        args = [arg.arg for arg in definition.args.args]
        print(f'fn {definition.name} ({", ".join(args)}) {definition.returns or ""}' + '{')
        for child in definition.body:
            self.visit(child)
        print('}')
        
    def visit_Expr(self, expr):
        self.visit(expr.value)
        
    def visit_Call(self, call):
        fmt = False
        if isinstance(call.func, ast.Name):
            print(f'{CALLS.get(call.func.id, call.func.id)}(', end='')
        elif isinstance(call.func, ast.Attribute):
            if fmt := is_strformat(call.func):
                print(deval(call.func.value.value.format(*[f'${{{arg.id}}}' for arg in call.args])), end='')
            else:
                self.visit(call.func.value)
                print(f'.{call.func.attr}(', end='')
        if not fmt:
            for i, arg in enumerate(call.args):
                self.visit(arg)
                if not i + 1 == len(call.args):  # if not last arg
                    print(', ', end='')
            print(')')
        
    def visit_If(self, if_node):
        if is_maincheck(if_node.test):
            return
        
    def visit_Assign(self, assign):
        print('mut ', end='')
        for target in assign.targets:
            self.visit(target)
        print(' := ', end='')
        self.visit(assign.value)
        print()
        
    def visit_Name(self, name):
        print(name.id, end='')
        
    def visit_BinOp(self, binop):
        self.visit(binop.left)
        if isinstance(binop.op, ast.Add):  # TODO: use dict
            print(' + ', end='')
        self.visit(binop.right)
    
    def generic_visit(self, node):
        raise Exception('unhandled {node}')


with open(sys.argv[1]) as f:  # TODO: use argparse
    src = f.read()
parsed = ast.parse(src)
Translator().visit(parsed)
