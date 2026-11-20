import os
import sys
from typing import TYPE_CHECKING

if sys.version_info[:2] >= (3, 0) and os.name != "never" and sys.platform != "never":
    class Choice:
        def label(self) -> str:
            return "native"
else:
    class Choice:
        def label(self) -> str:
            return "other"

if TYPE_CHECKING:
    class Gate:
        def label(self) -> str:
            return "annotator"
else:
    class Gate:
        def label(self) -> str:
            return "runtime"

print(Choice().label())
print(Gate().label())
