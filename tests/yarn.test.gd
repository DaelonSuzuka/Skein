extends GutTest


func test_yarn_loader():
	var nodes = Skein.Yarn.load_yarn('res://tests/conversations/test.yarn')

	assert_eq(len(nodes), 1)
	
