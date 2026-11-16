module main

import arrays

pub struct Node {
pub mut:
	data int
	next ?&Node
}

fn (mut self Node) init(data int) {
	self.data = data
	self.next = none
}

pub fn py2v_new_node(data int) &Node {
	mut py2v_instance := &Node{}
	py2v_instance.init(data)
	return py2v_instance
}

pub struct LinkedList {
pub mut:
	head ?&Node
	size int
}

fn (mut self LinkedList) init() {
	self.head = none
	self.size = 0
}

fn (mut self LinkedList) push_front(data int) {
	mut node := py2v_new_node(data)
	node.next = self.head
	self.head = node
	self.size += 1
}

fn (mut self LinkedList) push_back(data int) {
	node := py2v_new_node(data)
	self.size += 1
	if self.head == none {
		self.head = node
		return
	}
	mut current := self.head
	for current.next != none {
		current = current.next
	}
	current.next = node
}

fn (self LinkedList) total() int {
	mut result := 0
	mut current := self.head
	for current != none {
		result += current.data
		current = current.next
	}
	return result
}

fn (mut self LinkedList) reverse() {
	mut prev := ?&Node(none)
	mut current := self.head
	for current != none {
		following := current.next
		current.next = prev
		prev = current
		current = following
	}
	self.head = prev
}

fn (self LinkedList) show() {
	mut current := self.head
	for current != none {
		println(current.data)
		current = current.next
	}
}

pub fn py2v_new_linked_list() LinkedList {
	mut py2v_instance := LinkedList{}
	py2v_instance.init()
	return py2v_instance
}

pub struct TreeNode {
pub mut:
	value int
	left  ?&TreeNode
	right ?&TreeNode
}

fn (mut self TreeNode) init(value int) {
	self.value = value
	self.left = none
	self.right = none
}

fn (self &TreeNode) get_left() ?&TreeNode {
	return self.left
}

fn (mut self TreeNode) set_left(node ?&TreeNode) {
	self.left = node
}

pub fn py2v_new_tree_node(value int) &TreeNode {
	mut py2v_instance := &TreeNode{}
	py2v_instance.init(value)
	return py2v_instance
}

fn insert(mut node ?&TreeNode, value int) &TreeNode {
	if node == none {
		return py2v_new_tree_node(value)
	}
	if value < node.value {
		node.left = insert(mut node.left, value)
	} else {
		node.right = insert(mut node.right, value)
	}
	return node
}

fn in_order(node ?&TreeNode) {
	if node == none {
		return
	}
	in_order(node.left)
	println(node.value)
	in_order(node.right)
}

fn height(node ?&TreeNode) int {
	if node == none {
		return 0
	}
	return 1 + (arrays.max([height(node.left), height(node.right)]) or { panic('!') })
}

fn tree_sum(node ?&TreeNode) int {
	if node == none {
		return 0
	}
	return node.value + tree_sum(node.left) + tree_sum(node.right)
}

fn main_func() {
	mut items := py2v_new_linked_list()
	items.push_back(2)
	items.push_back(3)
	items.push_front(1)
	items.show()
	println(items.total())
	items.reverse()
	items.show()
	println(items.size)
	mut first := py2v_new_node(10)
	mut second := py2v_new_node(20)
	first.next = second
	second.data = 99
	if first.next != none {
		println(first.next.data)
	}
	mut alias := first
	alias.data = 11
	println(first.data)
	mut root := ?&TreeNode(none)
	for value in [5, 3, 8, 1, 4, 9] {
		root = insert(mut root, value)
	}
	in_order(root)
	println(height(root))
	println(tree_sum(root))
	mut parent := py2v_new_tree_node(1)
	mut child := py2v_new_tree_node(2)
	parent.set_left(child)
	child.value = 7
	mut left := parent.get_left()
	if left != none {
		println(left.value)
		left.value = 8
	}
	println(child.value)
	println(tree_sum(parent))
}

fn main() {
	main_func()
}
