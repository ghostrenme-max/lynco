extends RefCounted
## Logical board coordinates shared by rules and presentation. No nodes or RNG.
const COLS := 6
const ROWS := 5
const CAPACITY := COLS * ROWS
const INVALID := Vector2i(-1, -1)
const OFFSETS := {"up":Vector2i(0,-1),"right":Vector2i(1,0),"down":Vector2i(0,1),"left":Vector2i(-1,0),"up_left":Vector2i(-1,-1),"up_right":Vector2i(1,-1),"down_left":Vector2i(-1,1),"down_right":Vector2i(1,1)}

static func contains(cell: Vector2i) -> bool:
 return cell.x >= 0 and cell.x < COLS and cell.y >= 0 and cell.y < ROWS

static func first_empty(occupied: Dictionary) -> Vector2i:
 # Row-major order is part of deterministic placement/AI tie-breaking.
 for y in range(ROWS):
  for x in range(COLS):
   var cell := Vector2i(x,y)
   if not occupied.has(cell):return cell
 return INVALID
