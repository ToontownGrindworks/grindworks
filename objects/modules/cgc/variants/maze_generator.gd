extends Node3D

## State tracking
enum MazeState {
	EMPTY,
	FILLED,
	GENERATED
}
var maze_state := MazeState.EMPTY

## Locals
const UNIT_SIZE := 4.45

## Config
@export var grid_size := Vector2i(8,7)

## Child References
@onready var generated_maze := $Maze/GeneratedMaze
@onready var base_unit := $Maze/MazeUnit
@onready var battle_area := $MazeAll/BattleArea
@onready var entrance_area := $MazeAll/OutsideElements/EntranceRoom
@onready var connector_patches := $MazeAll/OutsideElements/connectorpatches

class GridSpace:
	var x : int
	var y : int
	func is_equal(space : GridSpace) -> bool:
		return space.x == x and space.y == y
	func _to_string() -> String:
		return "("+str(x)+","+str(y)+")"
	func _init(x_ : int,  y_ : int) -> void:
		x = x_
		y = y_

var grid := {}

func clear_maze() -> void:
	for unit in generated_maze.get_children():
		unit.queue_free()
	grid.clear()
	maze_state = MazeState.EMPTY

## Fills maze with copies of the base unit
func fill_maze() -> void:
	if not maze_state == MazeState.EMPTY:
		print("Cannot fill maze, it's not empty!")
		return
	for i in grid_size.x:
		for j in grid_size.y:
			await Task.delay(0.01)
			var new_unit : Node3D = base_unit.duplicate()
			generated_maze.add_child(new_unit)
			new_unit.show()
			new_unit.position.x-=UNIT_SIZE*i
			new_unit.position.y = 0.0
			new_unit.position.z+=UNIT_SIZE*j
			var space := GridSpace.new(i,j)
			grid[space] = new_unit
			if grid.keys().size()%2==1:
				# This stops them from zfigthing
				new_unit.scale*=.999
	maze_state = MazeState.FILLED

func generate_maze() -> void:
	if not maze_state == MazeState.FILLED:
		print("Cannot generate maze, it's not filled")
		return
	
	var unvisited_cells : Array = grid.keys()
	var stack := []
	
	# Mark first cell unvisited
	var cell : GridSpace = unvisited_cells[RandomService.randi_channel('maze_sizes') % unvisited_cells.size()]
	unvisited_cells.erase(cell)
	stack.append(cell)
	
	# Make maze
	while not unvisited_cells.is_empty():
		await Task.delay(0.01)
		var cell2 = find_unvisited_neighbor(unvisited_cells,cell)
		
		if cell2:
		
			var walls := get_connecting_walls(cell,cell2)
			if not walls.is_empty():
				grid[cell].get_node(walls[1]).hide()
				grid[cell2].get_node(walls[0]).hide()
			
			stack.append(cell)
			cell = cell2
			unvisited_cells.erase(cell)
		else:
			cell = stack.pop_back()
	
	for check_cell in grid.keys():
		var hedge : Node3D = grid[check_cell]
		for child in hedge.get_children():
			if not child.visible:
				child.queue_free()

func get_connecting_walls(space1 : GridSpace,space2 : GridSpace) -> Array[String]:
	if space1.x == space2.x:
		if space2.y > space1.y: return ['HedgeLeft','HedgeRight']
		if space2.y < space1.y: return ['HedgeRight','HedgeLeft']
	elif space1.y == space2.y:
		if space2.x > space1.x: return ['HedgeBack','HedgeFront']
		if space2.x < space1.x: return ['HedgeFront','HedgeBack']
	print("Space "+str(space1) + " and space "+str(space2)+" have no connecting walls")
	return []

func get_grid_space(x : int, y: int) -> GridSpace:
	for entry : GridSpace in grid.keys():
		if entry.x == x and entry.y == y:
			return entry
	return null

## Gets a maze unit from vec pos
func get_unit(vec : Vector2i) -> Node3D:
	var grid_space := get_grid_space(vec.x,vec.y)
	if grid_space:
		return grid[grid_space]
	return null

func find_unvisited_neighbor(unvisited_cells: Array,cell : GridSpace) -> GridSpace:
	var potential_cells := [
		get_grid_space(cell.x,cell.y-1),
		get_grid_space(cell.x,cell.y+1),
		get_grid_space(cell.x-1,cell.y),
		get_grid_space(cell.x+1,cell.y)
	]
	potential_cells.shuffle()
	for potential_cell in potential_cells:
		if potential_cell in unvisited_cells:
			return potential_cell
	
	# Return null if no unvisited cells
	return null

## TODO
## Opens the entrance and exit of the maze
func open_maze() -> void:
	pass
