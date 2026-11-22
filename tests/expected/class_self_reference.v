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
	mut py2v_receiver1 := &self
	py2v_old2 := py2v_receiver1.size
	py2v_aug_result3 := py2v_integer_add1(py2v_old2, 1, 'class_self_reference.py:19', 'addition')
	py2v_receiver1.size = py2v_aug_result3
}

fn (mut self LinkedList) push_back(data int) {
	node := py2v_new_node(data)
	mut py2v_receiver4 := &self
	py2v_old5 := py2v_receiver4.size
	py2v_aug_result6 := py2v_integer_add1(py2v_old5, 1, 'class_self_reference.py:23', 'addition')
	py2v_receiver4.size = py2v_aug_result6
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
		py2v_old7 := result
		py2v_aug_result8 := py2v_integer_add1(py2v_old7, current.data, 'class_self_reference.py:36', 'addition')
		result = py2v_aug_result8
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
	return py2v_integer_add1(1, arrays.max([height(node.left), height(node.right)]) or { panic('!') }, 'class_self_reference.py:91', 'addition')
}

fn tree_sum(node ?&TreeNode) int {
	if node == none {
		return 0
	}
	return py2v_integer_add1(int(py2v_integer_add1(node.value, tree_sum(node.left), 'class_self_reference.py:97', 'addition')), tree_sum(node.right), 'class_self_reference.py:97', 'addition')
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

@[noreturn]
fn py2v_integer_overflow1(site string, operation string) {
	flush_stdout()
	eprintln('py2v_integer_overflow: ${site}: ${operation} exceeds the V int range')
	exit(1)
}

@[inline]
fn py2v_integer_add1(a int, b int, site string, operation string) int {
	max := int(9223372036854775807)
	min := -max - 1
	if (b > 0 && a > max - b) || (b < 0 && a < min - b) { py2v_integer_overflow1(site, operation) }
	return a + b
}

fn main() {
	main_func()
}
