def main():
    a = [1]
    b = a
    b.append('x')
    print(a)
    c = a
    c.append(None)
    print(a)


if __name__ == '__main__':
    main()
