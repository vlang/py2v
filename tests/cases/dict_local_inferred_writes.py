def main():
    values = {"item": "first"}
    print(values["item"])
    values["item"] = 2
    print(values["item"])
    values["other"] = "last"
    print(values["other"], len(values))


if __name__ == "__main__":
    main()
