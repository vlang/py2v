try:
    raise ValueError('first')
except ValueError:
    try:
        raise RuntimeError('second') from None
    except RuntimeError as problem:
        print('str', str(problem))
        print('cause', problem.__cause__)
