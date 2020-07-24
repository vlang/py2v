import ast

def translate(node) -> str:
    if node is None:
        return ''
    elif isinstance(node, ast.Name):  # TODO: guess type
        return node.id
    elif isinstance(node, ast.Constant):
        return str(node.value)
    else:
        raise NotImplementedError(f'Cannot handle type {type(node)}')
