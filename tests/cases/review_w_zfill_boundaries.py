for s in ['', '1', '+1', '-1', '+', '-', 'é', '-é', 'e\u0301', '١٢', '-١٢', '+é', '🙂']:
    for width in [-1, 0, 1, 3, 5]:
        print(s, width, s.zfill(width))
