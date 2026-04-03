class P:
    pass

p = P()
p.name = 'Bob'

person = {'name': 'Alice'}

data = {'a': {'b': 'B'}}

lst = [10, 20]

print("Hi {p.name}".format(p=p))
print("Hello {person['name']}".format(person=person))
print("Nested: {data['a']['b']}".format(data=data))
print("First: {0[0]}".format(lst))

