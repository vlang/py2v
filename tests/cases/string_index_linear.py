s = 'ab' * 50000
total = 0
for i in range(len(s)):
    total += ord(s[i])
print(total)
