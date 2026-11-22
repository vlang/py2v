def main() -> None:
    words = ['İ', 'i', 'ẞ', 'ß', 'K', 'K', 'σ', 'Σ', 'ǅ', 'ǆ']
    print(sorted(words, key=str.lower))
    print(sorted(words, key=str.upper))
    print(sorted(words, key=str.lower, reverse=True))

if __name__ == '__main__':
    main()
