# runtime/import/

Notes for wiring repo greybox into the Godot `res://` tree.

Godot cannot load outside `res://` at runtime. Prefer copying (or symlinking on local clones) into `runtime/models/`:

- `hero_grey.glb` ← `../../assets/greybox/heroes/hero_grey.glb`
- `chunk_selva_floor.glb` ← `../../assets/greybox/worlds/selva/chunk_selva_floor.glb`

See [../models/README.md](../models/README.md). Pilot scripts fall back to CSG if files are missing.
