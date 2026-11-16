from __future__ import annotations

from typing import TYPE_CHECKING, Any, Optional

if TYPE_CHECKING:
    from mcp.types import TextContent, Tool


def many(text: str, mode: "Optional[str]" = None) -> list["TextContent"]:
    from mcp.types import TextContent

    if mode is not None:
        return [TextContent(type="text", text=mode)]
    return [TextContent(type="text", text=text)]


def tools() -> "list[Tool]":
    from mcp.types import Tool

    return [Tool(name="a", description="b", inputSchema={"type": "object"})]
