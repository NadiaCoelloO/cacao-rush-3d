Assemble parts with:
  python3 -c "from pathlib import Path; p=Path('.'); t=''.join((p/f'part_{i:02d}.txt').read_text().strip() for i in range(18)); Path('../totem_warp_cuyabeno.glb').write_bytes(__import__('base64').b64decode(t))"

Or open Godot — pilot_cuyabeno.gd can assemble via Marshalls.base64_to_raw + GLTFDocument.

CIN-001 ASSET OK @ d93f777 SHA256 e4b5a10c1f9d3e9d338fe37beca7542dcea8ec74d505e2a9b9fb5b790845f1bf
