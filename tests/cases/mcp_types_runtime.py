from mcp.types import TextContent, Tool


def reply(text: str) -> list[TextContent]:
    return [TextContent(type="text", text=text)]


def describe() -> Tool:
    return Tool(name="echo", description="Echo a word", inputSchema={"type": "object", "properties": {"word": {"type": "string"}}})


def main() -> None:
    out = reply("done")
    print(out[0].type, out[0].text)
    tool = describe()
    print(tool.name, tool.description)


if __name__ == "__main__":
    main()
