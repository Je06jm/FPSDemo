extends Node

# There is a bug where integer modulos operations don't actualy work, so this is
# a work around
func modi(a : int, b : int) -> int:
	var divided := a / b
	a = a - divided * b
	return a
