import ast

import vast

def resolve_args(call_args):
    args = []
    for arg in call_args:
        if isinstance(arg, ast.Name):
            args.append(vast.Ident(name=arg.id))
        elif isinstance(arg, ast.Constant):
            args.append(vast.Literal(value=arg.value))
        elif isinstance(arg, ast.Call):
            args.append(translate_call(arg))
        else:
            raise NotImplementedError(f'Cannot handle type {type(arg)}')
    return args


class CallTranslator:
    @staticmethod
    def translate(call):
        return vast.CallExpr(name=call.func.id,
                             args=resolve_args(call.args))


class Builtin(CallTranslator):
    def translate(self, call, typ=False):
        if typ:
            if isinstance(call.func.value.value, str):
                if call.func.attr == 'format':  # Replace str.format with string interpolation
                    args = [f'${{{arg.id}}}' for arg in call.args] # TODO: support kwargs
                    return vast.StringLiteral(val=call.func.value.value.format(*args))
                else:
                    raise NotImplementedError(f'Cannot handle builtin func {type(call.func.value)}.{type(call.func.attr)}')
            else:
                raise NotImplementedError(f'Cannot handle builtin type {type(call.func.value)}')
        else:
            if call.func.id == 'print':  # TODO: add support for kwargs of print
                call.func.id = 'println'
                return CallTranslator.translate(call)
            elif call.func.id == 'input':
                mod.imports.add('os')
                mod.body.append(f'os.input({resolve_args(call.args)})\n')
            else:
                CallTranslator.translate(call)


translators = {'builtin': Builtin()}


def translate_call(call):
    if isinstance(call.func, ast.Name):
        return translators['builtin'].translate(call)
    elif isinstance(call.func, ast.Attribute):
        if isinstance(call.func.value, ast.Name):
            if (translator := translators.get(call.func.value.id, None)) is None:
                return CallTranslator.translate(call)
            else:
                return translator.translate(call)
        else:
            return translators['builtin'].translate(call, typ=True)
    else:
        assert False, f"Unknown call type {type(call.func)}"
    
