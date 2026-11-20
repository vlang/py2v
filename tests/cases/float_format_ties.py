def render(x: float) -> str:
    return f"{x:.2f}|{x:+.0f}|{x:.1e}|{x:.2g}|{x:.0%}"


print(render(2.5))
print(render(-0.125))
print(render(2.675))
print(render(-0.0))
