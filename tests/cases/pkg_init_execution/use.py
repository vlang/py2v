from pkg_init_execution import sub
from pkg_init_execution.sub import shapes
from pkg_init_execution.sub import Exported
from pkg_init_execution.sub.shapes import Point, Plain
from pkg_init_execution.sub.shapes import Point as P
import pkg_init_execution.sub.shapes
import pkg_init_execution.sub.shapes as s
from pkg_init_execution.sibling import Sibling
from pkg_init_execution import sibling


class Local:
    def __init__(self, a: int, b: int) -> None:
        self.total: int = a + b


def run() -> None:
    p = Point(1, 2)
    q = shapes.Point(3, 4)
    t = shapes.Tag("t")
    a = P(5, 6)
    b = s.Point(7, 8)
    d = Point(9)
    k = Point(y=10, x=11)
    u = Sibling(12)
    v = sibling.Sibling(13)
    l = Local(14, 15)
    f = pkg_init_execution.sub.shapes.Point(16, 17)
    e = sub.Exported(18, 19)
    r = Exported(20, 21)
    plain = Plain()
    print(p.x, p.y, q.x, q.y, t.name)
    print(a.x, a.y, b.x, b.y)
    print(d.x, d.y, k.x, k.y)
    print(u.value, v.value, l.total, plain.value)
    print(f.x, f.y, e.x, e.y, r.x, r.y)
