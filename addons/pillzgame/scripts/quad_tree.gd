class_name QuadTree

var boundary: Rect2
var capacity: int
var points: Array[Node3D] = []
var divided: bool = false
var northeast: QuadTree
var northwest: QuadTree
var southeast: QuadTree
var southwest: QuadTree

func _init(bounds: Rect2, cap: int = 4):
    boundary = bounds
    capacity = cap

func insert(point: Node3D) -> bool:
    if not boundary.has_point(Vector2(point.global_position.x, point.global_position.z)):
        return false
        
    if points.size() < capacity:
        points.append(point)
        return true
        
    if not divided:
        subdivide()
        
    return (northeast.insert(point) or
            northwest.insert(point) or
            southeast.insert(point) or
            southwest.insert(point))

func subdivide():
    var x = boundary.position.x
    var y = boundary.position.y
    var w = boundary.size.x / 2
    var h = boundary.size.y / 2
    
    northeast = QuadTree.new(Rect2(x + w, y, w, h))
    northwest = QuadTree.new(Rect2(x, y, w, h))
    southeast = QuadTree.new(Rect2(x + w, y + h, w, h))
    southwest = QuadTree.new(Rect2(x, y + h, w, h))
    
    divided = true

func query(range: Rect2) -> Array[Node3D]:
    var found_points: Array[Node3D] = []
    
    var query_range = range.abs()
    
    if not boundary.intersects(query_range):
        return found_points
        
    for point in points:
        if not is_instance_valid(point):
            continue
        
        if query_range.has_point(Vector2(point.global_position.x, point.global_position.z)):
            found_points.append(point)
            
    if divided:
        found_points.append_array(northeast.query(query_range))
        found_points.append_array(northwest.query(query_range))
        found_points.append_array(southeast.query(query_range))
        found_points.append_array(southwest.query(query_range))
        
    return found_points

func query_radius(center: Vector3, radius: float) -> Array[Node3D]:
    # Create a square range that encompasses the circle
    var range = Rect2(
        center.x - radius,
        center.z - radius,
        radius * 2,
        radius * 2
    )
    
    # Get points in square first
    var points_in_range = query(range)
    
    # Filter points to only those within radius
    var radius_squared = radius * radius
    return points_in_range.filter(
        func(point): 
            var dx = point.global_position.x - center.x
            var dz = point.global_position.z - center.z
            return (dx * dx + dz * dz) <= radius_squared
    )

func clear():
    points = points.filter(func(p): return is_instance_valid(p))
    points.clear()
    if divided:
        northeast.clear()
        northwest.clear()
        southeast.clear()
        southwest.clear()
        divided = false 