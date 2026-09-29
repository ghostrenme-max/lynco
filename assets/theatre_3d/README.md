# LYNCO Blender theatre props

Created in Blender 5.2.0 LTS using tools/blender/build_theatre_props.py. Live MCP was unavailable, so an isolated background Blender process was used; no existing user scene was edited.

Source: tools/blender/lynco_theatre_props.blend (editable model review scene). tools/blender/.gdignore prevents source files from being imported into Godot. Runtime assets are the GLB files here.

Assets: chair (30774 triangles; one mesh with wood, brass and textured velvet surfaces), candelabra (1,368), folded curtain (2,684), star pendant (40), pedestal and vase (836). Four chairs, two candelabras, four curtains, two pendants, two vases are placed outside the original boards. No physics bodies are imported. Original shop/black-market distributors remain unchanged.

felt.png and walnut.png are subtle material textures generated in Blender. The original Godot Table and OpponentTable meshes, sizes, transforms, legs and collision shapes are preserved. Only materials change. No replacement table was exported.

Lighting: subdued warm ambient, a stronger table spotlight, a softer distant table spotlight and two candle pools, plus four restrained chair bounce spotlights. Compatibility renderer shadow-map banding on thin low-poly meshes is avoided by disabling spot/directional shadow maps; soft light falloff supplies the quiet dark-room effect. Six shader flames now sway and stretch independently with subtle candle-light modulation (scripts/candle_animation.gd, asset/candle_flame.gdshader). This is visual only; no gameplay random state is used.

Godot wiring: scripts/theatre_room.gd and asset/theatre_floor.gdshader. The updated chair includes thick rounded sidewalls, closed projecting back pads, five padded button tufts, cloth grain/normal textures, gold piping and tassels. Top view extends the original table felt material rather than substituting grey. Top view hides TheatreRoom and restores it with the existing camera workflow. Floor checker fades into darkness at the room edges.

Rebuild (from project root):
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' --background --factory-startup --python D:/Lynco/tools/blender/build_theatre_props.py

Preview: test-results/blender_theatre_props.png; game views: test-results/room_player_1280.png, room_player_1920.png, room_top.png, room_overview.png. Overview uses a review camera, not a new gameplay camera.