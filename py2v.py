import ast
import io
import sys

CALLS = {'print': 'println'}  # TODO: add an option to suppress this
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

def deval(value) -> bytes:
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


class Py2V(ast.NodeVisitor):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.buffer = []
        
    def visit_Constant(self, node):
        self.buffer.append(deval(node.value))
        
    def visit_Module(self, module):
        self.buffer.append('module main\n')
        for child in module.body:
            self.visit(child)
            
    def visit_FunctionDef(self, definition):
        args = [arg.arg for arg in definition.args.args]
        self.buffer.append(f'fn {definition.name} ({", ".join(args)}) {definition.returns or ""}' + '{\n')
        for child in definition.body:
            self.visit(child)
        self.buffer.append('}\n')
        
    def visit_Expr(self, expr):
        self.visit(expr.value)
        
    def visit_Call(self, call):
        fmt = False
        if isinstance(call.func, ast.Name):
            self.buffer.append(f'{CALLS.get(call.func.id, call.func.id)}(')
        elif isinstance(call.func, ast.Attribute):
            if fmt := is_strformat(call.func):
                self.buffer.append(deval(call.func.value.value.format(*[f'${{{arg.id}}}' for arg in call.args])))
            else:
                self.visit(call.func.value)
                self.buffer.append(f'.{call.func.attr}(')
        if not fmt:
            for arg in call.args:
                self.visit(arg)
                self.buffer.append(', ')
            self.buffer.pop()
            self.buffer.append(')\n')
        
    def visit_If(self, if_node):
        if is_maincheck(if_node.test):
            return
        
    def visit_Assign(self, assign):
        self.buffer.append('mut ')
        for target in assign.targets:
            self.visit(target)
            self.buffer.append(', ')
        self.buffer.pop()
        self.buffer.append(' := ')
        self.visit(assign.value)
        self.buffer.append('\n')
        
    def visit_Name(self, name):
        self.buffer.append(name.id)
        
    def visit_BinOp(self, binop):
        self.visit(binop.left)
        self.buffer.append(f' {OPERATORS[type(binop.op)]} ')
        self.visit(binop.right)
    
    def generic_visit(self, node):
        raise Exception('unhandled {node}')

def main():
    with open(sys.argv[1]) as f:  # TODO: use argparse
        parsed = ast.parse(f.read())
    p = Py2V()
    p.visit(parsed)
    print(''.join(p.buffer))
    
if __name__ == '__main__':
    main()
