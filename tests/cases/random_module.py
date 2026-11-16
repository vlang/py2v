import random
from random import randint, shuffle


def roll(sides: int) -> int:
    return random.randint(1, sides)


rolls = [roll(6) for _ in range(200)]
print(min(rolls) >= 1, max(rolls) <= 6, len(rolls))
print(6 in rolls)
value = random.random()
print(value >= 0.0 and value < 1.0)
names = ["ada", "bob", "cy"]
print(random.choice(names) in names)
deck = [1, 2, 3, 4, 5, 6, 7, 8]
random.shuffle(deck)
print(sorted(deck), len(deck))
below = random.randrange(10)
between = random.randrange(5, 8)
print(below >= 0 and below < 10, between >= 5 and between < 8)
picked = random.sample(deck, 3)
print(len(picked), picked[0] in deck)
height = random.uniform(1.5, 2.5)
print(height >= 1.5 and height <= 2.5)
pair = randint(3, 4)
print(pair >= 3 and pair <= 4)
hand = [9, 8, 7]
shuffle(hand)
print(sorted(hand))
