def main():
    name = "world"
    age = 25
    pi = 3.14159

    print("hello %s" % name)
    print("name=%s age=%d" % (name, age))
    print("pi is %.2f" % pi)
    print("count: %d" % age)
    print("padded: %05d" % age)
    print("hex: %x" % 255)
    print("%s is %d years old and likes %.1f" % (name, age, pi))
    print("score: %d%%" % 95)
    print("default float: %f" % pi)
    print("truncated: %.f" % pi)
    print("left-pad: %-05d" % age)
    print(10 % 3)
    print(17 % 5)


if __name__ == "__main__":
    main()
