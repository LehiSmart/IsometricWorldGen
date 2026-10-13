extends Node

@onready var shadow_layer: TileMapLayer = $ShadowLayer

# Atlas coords for shadow tiles (e.g., pure black/translucent overlay or dark dirt)
const TILE_SHADOW_CORNER = Vector2i(6, 9) # Adjust to your shadow atlas coord
