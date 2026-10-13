extends Node2D

@onready var base_layer: TileMapLayer = $BaseLayer
@onready var shadow_layer: TileMapLayer = $ShadowLayer
@onready var height_layer_1: TileMapLayer = $HeightLayer1
@onready var height_layer_2: TileMapLayer = $HeightLayer2
@onready var generate_button: Button = $CanvasLayer/Button

@export var width: int = 80
@export var height: int = 80
@export var plant_scene: PackedScene

@export var layer_height_offset: float = -8.0
@export var shadow_direction: Vector2i = Vector2i(-1, 1)

# River Configuration
@export var generate_river: bool = true
@export var river_width: int = 2

const SOURCE_ID = 0

# Dedicated RNG instance to guarantee fresh seeds on re-runs
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

enum TileType {
	OCEAN_DEEP,
	OCEAN_MID,
	OCEAN_SHALLOW,
	STONE_SHORE,
	DIRT,
	GRASS,
	FLOWER_GRASS,
	STONE_CLIFF
}

const TILE_ATLAS_MAP = {
	TileType.OCEAN_DEEP: [Vector2i(5, 9), Vector2i(6, 9), Vector2i(7, 9)],
	TileType.OCEAN_MID: [Vector2i(0, 8), Vector2i(1, 8), Vector2i(2, 8)],
	TileType.OCEAN_SHALLOW: [Vector2i(0, 10), Vector2i(1, 10), Vector2i(2, 10), Vector2i(3, 10)],
	TileType.STONE_SHORE: [Vector2i(2, 6), Vector2i(3, 6), Vector2i(4, 6), Vector2i(0, 7)],
	TileType.DIRT: [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(6, 1), Vector2i(7, 1)],
	TileType.GRASS: [Vector2i(0, 2), Vector2i(1, 2), Vector2i(5, 2), Vector2i(6, 2)],
	TileType.FLOWER_GRASS: [Vector2i(7, 3), Vector2i(8, 3)],
	TileType.STONE_CLIFF: [Vector2i(5, 5), Vector2i(6, 5), Vector2i(7, 5)]
}

const TILE_SHADOW: Vector2i = Vector2i(7, 1)

const DECORATION_LOGS: Array[Vector2i] = [
	Vector2i(4, 4), Vector2i(5, 4), Vector2i(6, 4), Vector2i(7, 4)
]
const DECORATION_ROCKS: Array[Vector2i] = [
	Vector2i(8, 4), Vector2i(9, 4)
]

const TILE_WEIGHTS = {
	TileType.OCEAN_DEEP: 0.1,
	TileType.OCEAN_MID: 0.2,
	TileType.OCEAN_SHALLOW: 0.8,
	TileType.STONE_SHORE: 1.5,
	TileType.DIRT: 6.0,
	TileType.GRASS: 15.0,
	TileType.FLOWER_GRASS: 2.0,
	TileType.STONE_CLIFF: 1.5
}

const DIRECTIONS = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]

var adjacency_rules: Dictionary = {}
var grid: Dictionary = {}

func _ready() -> void:
	setup_layer_sorting_and_offsets()
	define_adjacency_rules()
	generate_button.pressed.connect(_on_generate_pressed)
	run_wfc()	

func setup_layer_sorting_and_offsets() -> void:
	base_layer.y_sort_enabled = true
	shadow_layer.y_sort_enabled = true
	height_layer_1.y_sort_enabled = true
	height_layer_2.y_sort_enabled = true
	
	base_layer.z_index = 0
	shadow_layer.z_index = 1
	height_layer_1.z_index = 2
	height_layer_2.z_index = 3
	
	base_layer.position = Vector2.ZERO
	shadow_layer.position = Vector2.ZERO
	height_layer_1.position = Vector2(0, layer_height_offset)
	height_layer_2.position = Vector2(0, layer_height_offset * 2.0)

func define_adjacency_rules() -> void:
	adjacency_rules[TileType.OCEAN_DEEP] = [TileType.OCEAN_DEEP, TileType.OCEAN_MID]
	adjacency_rules[TileType.OCEAN_MID] = [TileType.OCEAN_DEEP, TileType.OCEAN_MID, TileType.OCEAN_SHALLOW]
	adjacency_rules[TileType.OCEAN_SHALLOW] = [TileType.OCEAN_SHALLOW, TileType.STONE_SHORE, TileType.DIRT]
	
	adjacency_rules[TileType.STONE_SHORE] = [TileType.OCEAN_SHALLOW, TileType.DIRT, TileType.STONE_CLIFF]
	adjacency_rules[TileType.DIRT] = [TileType.OCEAN_SHALLOW, TileType.STONE_SHORE, TileType.DIRT, TileType.GRASS, TileType.STONE_CLIFF]
	adjacency_rules[TileType.GRASS] = [TileType.DIRT, TileType.GRASS, TileType.FLOWER_GRASS, TileType.STONE_CLIFF]
	adjacency_rules[TileType.FLOWER_GRASS] = [TileType.GRASS, TileType.FLOWER_GRASS]
	adjacency_rules[TileType.STONE_CLIFF] = [TileType.DIRT, TileType.GRASS, TileType.STONE_CLIFF, TileType.STONE_SHORE]

func initialize_grid() -> void:
	grid.clear()
	base_layer.clear()
	shadow_layer.clear()
	height_layer_1.clear()
	height_layer_2.clear()
	
	var all_layers = [base_layer, shadow_layer, height_layer_1, height_layer_2]
	for layer in all_layers:
		for child in layer.get_children():
			child.queue_free()

	var all_types: Array[TileType] = [
		TileType.OCEAN_DEEP,
		TileType.OCEAN_MID,
		TileType.OCEAN_SHALLOW,
		TileType.STONE_SHORE,
		TileType.DIRT,
		TileType.GRASS,
		TileType.FLOWER_GRASS,
		TileType.STONE_CLIFF
	]

	for x in range(width):
		for y in range(height):
			grid[Vector2i(x, y)] = all_types.duplicate()

func run_wfc() -> void:
	# Force a brand new seed on every map generation call
	rng.randomize()
	initialize_grid()

	if generate_river:
		seed_river_path()

	var iterations = 0
	var max_iterations = width * height * 2

	while iterations < max_iterations:
		iterations += 1
		var min_entropy_pos = get_min_entropy_cell()
		
		if min_entropy_pos == Vector2i(-1, -1):
			break
			
		if grid[min_entropy_pos].is_empty():
			run_wfc()
			return

		collapse_cell(min_entropy_pos)
		propagate(min_entropy_pos)

	render_grid()
	generate_shadow_pass()

func seed_river_path() -> void:
	var effective_width: int = max(2, river_width)
	
	# 1. Select two different edges for entry and exit
	var entry_edge: int = rng.randi_range(0, 3) # 0: Top, 1: Right, 2: Bottom, 3: Left
	var exit_edge: int = (entry_edge + rng.randi_range(1, 3)) % 4
	
	var start_pos: Vector2 = get_random_edge_point(entry_edge)
	var target_pos: Vector2 = get_random_edge_point(exit_edge)
	
	# 2. Walk from start to target using vector inertia + drift noise
	var current_pos: Vector2 = start_pos
	var step_size: float = 1.0
	var velocity: Vector2 = (target_pos - start_pos).normalized()
	
	# Track placed tiles to avoid redundant propagation
	var river_tiles: Array[Vector2i] = []
	var max_steps: int = (width + height) * 4
	var steps: int = 0
	
	while current_pos.distance_to(target_pos) > 2.0 and steps < max_steps:
		steps += 1
		
		# Base direction toward goal
		var dir_to_target: Vector2 = (target_pos - current_pos).normalized()
		
		# Add perpendicular drift noise for organic meandering
		var perp_dir: Vector2 = Vector2(-dir_to_target.y, dir_to_target.x)
		var drift: float = rng.randf_range(-0.6, 0.6)
		
		# Blend inertia, goal pull, and drift
		velocity = (velocity * 0.65 + dir_to_target * 0.25 + perp_dir * drift).normalized()
		current_pos += velocity * step_size
		
		# Convert continuous position to grid coordinates
		var grid_center = Vector2i(round(current_pos.x), round(current_pos.y))
		
		# Carve river thickness block around the path center
		for dx in range(-effective_width / 2, (effective_width + 1) / 2):
			for dy in range(-effective_width / 2, (effective_width + 1) / 2):
				var cell = grid_center + Vector2i(dx, dy)
				if cell.x >= 0 and cell.x < width and cell.y >= 0 and cell.y < height:
					if not river_tiles.has(cell):
						river_tiles.append(cell)

	# 3. Apply water to grid and propagate WFC constraints once per tile
	for pos in river_tiles:
		grid[pos] = [TileType.OCEAN_SHALLOW]
		propagate(pos)

## Helper function to retrieve a random coordinate along a specified grid edge
func get_random_edge_point(edge: int) -> Vector2:
	match edge:
		0: # Top Edge (North)
			return Vector2(rng.randi_range(2, width - 3), 0)
		1: # Right Edge (East)
			return Vector2(width - 1, rng.randi_range(2, height - 3))
		2: # Bottom Edge (South)
			return Vector2(rng.randi_range(2, width - 3), height - 1)
		_: # Left Edge (West)
			return Vector2(0, rng.randi_range(2, height - 3))

func get_min_entropy_cell() -> Vector2i:
	var min_entropy = 99999.0
	var candidate_cells: Array[Vector2i] = []

	for pos in grid.keys():
		var count = grid[pos].size()
		if count > 1:
			var entropy = count + rng.randf_range(0.0, 0.1)
			if entropy < min_entropy:
				min_entropy = entropy
				candidate_cells = [pos]
			elif abs(entropy - min_entropy) < 0.01:
				candidate_cells.append(pos)

	if candidate_cells.is_empty():
		return Vector2i(-1, -1)
	
	# Pick a random candidate using the local RNG instance
	var idx = rng.randi_range(0, candidate_cells.size() - 1)
	return candidate_cells[idx]

func collapse_cell(pos: Vector2i) -> void:
	var candidates: Array[TileType] = grid[pos]
	var total_weight: float = 0.0
	
	for type in candidates:
		total_weight += TILE_WEIGHTS[type]

	var roll = rng.randf() * total_weight
	var cumulative = 0.0
	var chosen_type: TileType = candidates[0]

	for type in candidates:
		cumulative += TILE_WEIGHTS[type]
		if roll <= cumulative:
			chosen_type = type
			break

	grid[pos] = [chosen_type]

func propagate(start_pos: Vector2i) -> void:
	var queue: Array[Vector2i] = [start_pos]

	while not queue.is_empty():
		var current_pos = queue.pop_front()
		var current_candidates = grid[current_pos]

		for dir in DIRECTIONS:
			var neighbor_pos = current_pos + dir
			if not grid.has(neighbor_pos) or grid[neighbor_pos].size() <= 1:
				continue

			var neighbor_candidates = grid[neighbor_pos]
			var allowed_types: Array[TileType] = []

			for current_type in current_candidates:
				for valid in adjacency_rules[current_type]:
					if not allowed_types.has(valid):
						allowed_types.append(valid)

			var reduced_candidates: Array[TileType] = []
			var changed = false

			for neighbor_type in neighbor_candidates:
				if allowed_types.has(neighbor_type):
					reduced_candidates.append(neighbor_type)
				else:
					changed = true

			if changed:
				grid[neighbor_pos] = reduced_candidates
				if not queue.has(neighbor_pos):
					queue.append(neighbor_pos)

func pick_random_from_array(arr: Array) -> Variant:
	if arr.is_empty():
		return null
	return arr[rng.randi_range(0, arr.size() - 1)]

func render_grid() -> void:
	for pos in grid.keys():
		var tile_type: TileType = grid[pos][0]
		var atlas_coords: Vector2i = pick_random_from_array(TILE_ATLAS_MAP[tile_type])

		match tile_type:
			TileType.OCEAN_DEEP, TileType.OCEAN_MID, TileType.OCEAN_SHALLOW, TileType.STONE_SHORE:
				base_layer.set_cell(pos, SOURCE_ID, atlas_coords)

			TileType.DIRT:
				base_layer.set_cell(pos, SOURCE_ID, atlas_coords)

			TileType.GRASS, TileType.FLOWER_GRASS:
				base_layer.set_cell(pos, SOURCE_ID, pick_random_from_array(TILE_ATLAS_MAP[TileType.DIRT]))
				height_layer_1.set_cell(pos, SOURCE_ID, atlas_coords)
				
				if rng.randf() < 0.04:
					height_layer_1.set_cell(pos, SOURCE_ID, pick_random_from_array(DECORATION_LOGS))
				elif plant_scene and rng.randf() < 0.12:
					spawn_plant_on_layer(height_layer_1, pos)

			TileType.STONE_CLIFF:
				base_layer.set_cell(pos, SOURCE_ID, pick_random_from_array(TILE_ATLAS_MAP[TileType.DIRT]))
				height_layer_1.set_cell(pos, SOURCE_ID, atlas_coords)
				
				if rng.randf() < 0.08:
					height_layer_2.set_cell(pos, SOURCE_ID, pick_random_from_array(DECORATION_ROCKS))

func generate_shadow_pass() -> void:
	for pos in grid.keys():
		var current_type: TileType = grid[pos][0]
		
		if current_type in [TileType.GRASS, TileType.FLOWER_GRASS, TileType.STONE_CLIFF]:
			var shadow_target_pos = pos + shadow_direction
			
			if grid.has(shadow_target_pos):
				var target_type: TileType = grid[shadow_target_pos][0]
				
				if target_type in [TileType.DIRT, TileType.OCEAN_SHALLOW, TileType.STONE_SHORE]:
					shadow_layer.set_cell(shadow_target_pos, SOURCE_ID, TILE_SHADOW)

func spawn_plant_on_layer(target_layer: TileMapLayer, tile_coords: Vector2i) -> void:
	var plant = plant_scene.instantiate()
	target_layer.add_child(plant)
	plant.position = target_layer.map_to_local(tile_coords)


func _on_button_pressed() -> void:
	setup_layer_sorting_and_offsets()
	define_adjacency_rules()
	generate_button.pressed.connect(_on_generate_pressed)
	run_wfc()
	print("World Gen")

func _on_generate_pressed() -> void:
	run_wfc()
	print("World Gen")
