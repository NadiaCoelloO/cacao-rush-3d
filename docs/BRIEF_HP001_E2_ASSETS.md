# HP-001 E2 · Cuyabeno — dosel + muelle + suelo (brief Astra → Assets 3D)

Fecha: 2026-10-06. Plan aprobado: HP001_PLAN_CUYABENO.md (Coordinador OK). E1 tiene ASSET OK de Identidad (PR#6 @ fb5e85db).
Salida: /home/box/workspace/world-001/hp-001/assets-out-e2/ (Blender 5.2.1, bpy + .blend + GLB por LOD + texturas + README + SHA256SUMS.txt + stills).
Nada va a Godot, al repo ni a DaVinci. Sin ojos y sin magenta. Escala 1u=1m, glTF 2.0 Y-up.

## Piezas
1. **canopy_cuyabeno_hp**: dosel cerrado de várzea, en clumps.
   - Presupuesto: 2.5k / 1.2k / impostor (quad o billboard) por clump. Atlas 1K, alpha-scissor (sin alpha blend).
   - Total visible ≤60k en cualquier vista. Hoy la vista dosel ya está en 265k con E1, así que apuntá a ≤45k visibles en dosel.
   - Lectura: copa cerrada y oscura, verde profundo, con huecos chicos de cielo sepia que no crezcan en el centro (nota vieja de Identidad).
   - Que tape las horquillas peladas de los troncos E1 (muñones a la altura que da trunk_selva_kit_hp).
   - Prohibido: palmeras, frondas en abanico, agave (eso fue NO PASA en E1).
   - Variantes: 3 clumps (chico, medio y grande) más hojas colgantes/leaf cards para MultiMesh.
2. **dock_cuyabeno_hp**: muelle de madera modular de 4 m.
   - Presupuesto: 3k / 1.5k / 500 por segmento. Atlas 1K de tablas gastadas y húmedas, con pilotes y amarres de soga.
   - Solo visual, sin colisión nueva: hay que respetar las colisiones existentes. Piezas: recto, fin y escalón.
3. **groundcover_cuyabeno**: lirios de agua, helechos y hojas de cacao caídas.
   - Presupuesto: 300–500 / 150 por pieza, atlas compartido, MultiMesh, alpha-scissor.
   - La flor de lirio puede ser crema o blanca, nada magenta ni rosa saturado.

## Reglas
- Paleta: verdes profundos y marrones fríos; la corteza ya está lockeada (hue 29–34°, sat ≤0.2). Nada que compita con las vainas Y/O/R ni con la crema de Maya #8F8578.
- Pivots en la base y nombres limpios. LODs con los sufijos _LOD0/_LOD1/_LOD2.
- Stills por pieza: frente, 3/4 y close-up. Además, si podés, un still combinado con un tronco E1 para el contexto de escala.
- README: tris por LOD, tamaño de texturas, riesgos para Identidad.

## Opcional (soft de E1)
- Si llegás: trunk_selva_kit_hp v4 con bromelias de ~0.7 m y centro rojizo apagado, y la veta de los tablares sin chevrón (blend o rotación).
