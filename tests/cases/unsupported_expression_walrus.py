def match_value():
    match (value := input()):
        case "yes":
            return value
        case _:
            return "other"
