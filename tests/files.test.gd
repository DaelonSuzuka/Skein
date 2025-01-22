extends GutTest

var Files := Skein.Files

const dir = 'res://tests/test_files'

func test_get_files():
	assert_eq(len(Files.get_files(dir)), 4)
	assert_eq(len(Files.get_files(dir, '.txt')), 2)
	assert_eq(len(Files.get_files(dir, '.json')), 1)
	assert_eq(len(Files.get_files(dir, ['.txt', '.json'])), 3)

func test_get_all_files():
	assert_eq(len(Files.get_all_files(dir)), 8)
	assert_eq(len(Files.get_all_files(dir, '.txt')), 5)
	assert_eq(len(Files.get_all_files(dir, ['.cfg', '.json'])), 3)
	assert_eq(len(Files.get_all_files(dir, [], 1)), 4)
	assert_eq(len(Files.get_all_files(dir, null, 2)), 6)

func test_get_all_folders():
	assert_eq(len(Files.get_all_folders(dir)), 2)
	assert_eq(len(Files.get_all_folders(dir, 1)), 1)

func test_get_all_files_and_folders():
	assert_eq(len(Files.get_all_files_and_folders(dir)), 10)
	assert_eq(len(Files.get_all_files_and_folders(dir, 1)), 5)

func test_load_json():
	assert_eq(Files.load_json(dir.path_join('a.json')), {a='b'})
	assert_eq(Files.load_json(dir.path_join('a')), {a='b'})
	assert_eq(Files.load_json(dir.path_join('b'), {a='b'}), {a='b'})
	assert_eq(Files.load_json(dir.path_join('c')), null)
