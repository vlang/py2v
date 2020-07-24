import vast

def deval(value) -> vast.Object:
    if isinstance(value, str):
        return vast.StringLiteral(val=value, is_raw=False, language=vast.Language.V)
    elif isinstance(value, bool) or value is None:
        return vast.BoolLiteral(val=str(value).lower())
    elif isinstance(value, int):
        return vast.IntegerLiteral(val=str(value))
    else:
        raise NotImplementedError(f'Cannot devaluate type {type(value)}')
