def start() -> int:
    print('start')
    return 2

def end() -> int:
    print('end')
    return 4

for i in range(start(), end()):
    print('call', i)
n = 4
for i in range(n):
    print('snapshot', i)
    n = 0
for i in range(5, -1, -2):
    print('negative', i)
for i in range(3, 1):
    print('wrong', i)
else:
    print('empty else')
