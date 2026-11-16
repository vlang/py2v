from __future__ import annotations


class Node:
    def __init__(self, data: int) -> None:
        self.data: int = data
        self.next: Node | None = None


class LinkedList:
    def __init__(self) -> None:
        self.head: Node | None = None
        self.size: int = 0

    def push_front(self, data: int) -> None:
        node = Node(data)
        node.next = self.head
        self.head = node
        self.size += 1

    def push_back(self, data: int) -> None:
        node = Node(data)
        self.size += 1
        if self.head is None:
            self.head = node
            return
        current = self.head
        while current.next is not None:
            current = current.next
        current.next = node

    def total(self) -> int:
        result = 0
        current = self.head
        while current is not None:
            result += current.data
            current = current.next
        return result

    def reverse(self) -> None:
        prev: Node | None = None
        current = self.head
        while current is not None:
            following = current.next
            current.next = prev
            prev = current
            current = following
        self.head = prev

    def show(self) -> None:
        current = self.head
        while current is not None:
            print(current.data)
            current = current.next


class TreeNode:
    def __init__(self, value: int) -> None:
        self.value: int = value
        self.left: TreeNode | None = None
        self.right: TreeNode | None = None

    def get_left(self) -> TreeNode | None:
        return self.left

    def set_left(self, node: TreeNode | None) -> None:
        self.left = node


def insert(node: TreeNode | None, value: int) -> TreeNode:
    if node is None:
        return TreeNode(value)
    if value < node.value:
        node.left = insert(node.left, value)
    else:
        node.right = insert(node.right, value)
    return node


def in_order(node: TreeNode | None) -> None:
    if node is None:
        return
    in_order(node.left)
    print(node.value)
    in_order(node.right)


def height(node: TreeNode | None) -> int:
    if node is None:
        return 0
    return 1 + max(height(node.left), height(node.right))


def tree_sum(node: TreeNode | None) -> int:
    if node is None:
        return 0
    return node.value + tree_sum(node.left) + tree_sum(node.right)


def main() -> None:
    items = LinkedList()
    items.push_back(2)
    items.push_back(3)
    items.push_front(1)
    items.show()
    print(items.total())
    items.reverse()
    items.show()
    print(items.size)

    # aliasing: a node changed through one name is seen through another
    first = Node(10)
    second = Node(20)
    first.next = second
    second.data = 99
    if first.next is not None:
        print(first.next.data)
    alias = first
    alias.data = 11
    print(first.data)

    root: TreeNode | None = None
    for value in [5, 3, 8, 1, 4, 9]:
        root = insert(root, value)
    in_order(root)
    print(height(root))
    print(tree_sum(root))

    # aliasing through a field and through methods
    parent = TreeNode(1)
    child = TreeNode(2)
    parent.set_left(child)
    child.value = 7
    left = parent.get_left()
    if left is not None:
        print(left.value)
        left.value = 8
    print(child.value)
    print(tree_sum(parent))


if __name__ == "__main__":
    main()
