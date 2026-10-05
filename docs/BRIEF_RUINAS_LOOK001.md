# BRIEF_RUINAS_LOOK001

Fuente: GPT-6 Astra Extra High · Project Cacao Rush 3D · 2026-10-05  
2D tip READ ONLY: `5fd45031` · World id: `ruinas` · High-poly HOLD  
No código/assets en este commit — solo brief.

---

WORLD-001 · P1 · ruinas · Ruinas de Kakaw
Destino: Assets / Blender → Godot 4
Escala: 1u = 1m · Exportación: glTF 2.0, Y-up
Fuente 2D: 5fd45031, READ ONLY
Alcance: greybox + materiales, luces, humedad, bruma, dosel, cielo y post. High-poly HOLD.

Intención: ruinas ficticias de Kakaw integradas en bosque húmedo ecuatoriano. Piedra mate, raíces que abrazan los muros y vegetación que recupera sus juntas. Luz lateral entre copas, humedad localizada y bruma que separa planos. Mantener el lenguaje painted arcade de Cuyabeno paint_v03, con protagonismo de piedra y raíces.

1. Layout
Footprint 2D intacto: conservar posiciones, alturas, anchos, huecos, plataformas, pasos bajos, peligros, coleccionables, checkpoints, accesos secretos y meta del tip fijado.
Vestir los volúmenes existentes. No introducir escalinatas, puentes, arcos transitables ni plataformas para mejorar la composición.
Mantener diferenciadas las plataformas sólidas, unidireccionales, móviles y las que ceden. Sus materiales deben ayudar a reconocerlas sin cambiar comportamiento, recorridos ni tiempos.
Preservar el espacio libre de los pasos de agacharse y arrastrarse. Ninguna raíz, piedra o vegetación debe aparentar que bloquea un paso disponible.
Mantener visibles los bordes de apoyo y las zonas de aterrizaje. El desgaste se concentra en caras laterales y superficies decorativas.
Añadir profundidad mediante espesor visual, muros posteriores y vegetación fuera del plano jugable. La profundidad no crea nuevas rutas.
Separar geometría visual y proxies de colisión. Las colisiones proceden del port; no generarlas automáticamente a partir del conjunto decorativo.
Encuadre compatible con la cámara de juego y las zonas reservadas al HUD. No desplazar elementos jugables para obtener un mejor still.

Composición: primer plano discontinuo de raíces; plano jugable claro de piedra; muros fragmentados y troncos detrás; dosel y bruma al fondo. Evitar que las capas se superpongan sobre peligros o accesos.

2. Bioma / ambiente Ecuador

Dirección ambiental: bosque húmedo ecuatoriano como referencia de atmósfera y vegetación; Kakaw pertenece al universo ficticio del juego. No atribuir las ruinas a una cultura, sitio arqueológico o periodo histórico real.

Componente	Tratamiento
Piedra	Bloques de tamaños desiguales, superficies amplias y desgaste sencillo. Grises cálidos, tierra y manchas de humedad.
Muros	Fragmentos discontinuos que acompañan los volúmenes existentes; juntas parcialmente colonizadas por vegetación.
Raíces	Formas gruesas y asimétricas que abrazan bases y caras laterales. Pocos recorridos claros por conjunto.
Suelo	Tierra oscura, hojarasca agrupada y pequeñas zonas húmedas; lectura estable en los apoyos.
Vegetación	Masas de hojas anchas, helechos esquemáticos, musgo localizado y epífitas sugeridas mediante formas simples.
Identidad cacao	Vainas, semillas y ritmos geométricos abstractos, usados con moderación en elementos ya previstos.

La piedra debe seguir siendo reconocible entre la vegetación. Evitar cubrir todo de musgo o convertir cada muro en un entramado de raíces.

Los motivos Kakaw serán no figurativos: sin ojos, rostros, máscaras ni composiciones simétricas que sugieran una cara. No incorporar fauna nueva en este lote de lookdev.

3. Luz
Principal lateral y oblicua entre copas, con intención de primera o última parte del día. Elevación orientativa: 20–35°.
Fijar una dirección de luz en el mundo y conservarla en ambos stills.
Temperatura visual cálida y moderada sobre piedra, raíces y bordes de hojas. Sombras abiertas con relleno frío desaturado.
Usar pocas aperturas amplias en el dosel: manchas de luz legibles, sin moteado fino sobre todo el recorrido.
La luz debe explicar el volumen de los muros y separar raíces de piedra. Evitar contraluces que reduzcan las plataformas a siluetas negras.
Reservar el contraste más útil para personaje, apoyos y peligros. Los elementos decorativos quedan subordinados.
Rayos atmosféricos suaves y puntuales; no formar una cortina luminosa delante de la acción.
Cacao maduro con acentos amarillo, naranja y rojo. El dorado y cyan de efectos interactivos existentes mantienen su función, sin teñir todo el bosque.

Excluir: mediodía cenital, magenta, iluminación de discoteca, múltiples contraluces de colores, blancos quemados, destellos intermitentes y relighting distinto para cada toma.

4. Agua / humedad

La humedad se lee primero en los materiales. Los charcos son opcionales.

Oscurecer ligeramente bases de muros, juntas, depresiones visuales y zonas protegidas del sol.
Concentrar el musgo en puntos húmedos; conservar superficies relativamente secas para que exista contraste.
Valores iniciales orientativos de roughness:
Piedra seca: 0,75–0,95.
Piedra húmeda: 0,40–0,65.
Raíces: 0,65–0,90.
Charcos: 0,15–0,30, con reflejo contenido.
Materiales de piedra, suelo y raíces no metálicos. Evitar apariencia de barniz o plástico.
Si se incluyen charcos, usar pequeñas superficies discontinuas sobre suelo ya existente. No alterar su colisión ni añadir profundidad jugable.
Reflejos suaves de dosel y luz lateral; sin espejo perfecto, oleaje protagonista ni refracción costosa.
Mantener distinguibles charcos decorativos, huecos y peligros.
No añadir ríos, cascadas, lagunas ni zonas de nado como parte del look.

No forzar la laguna negra de Cuyabeno. El agua no debe dominar el encuadre ni definir la identidad de Ruinas de Kakaw.

5. Niebla / bruma entre planos

La bruma sirve para separar distancias y permitir que piedra y raíces se lean con claridad.

Plano	Tratamiento
Primer plano	Formas definidas; sin velo que reduzca toda la imagen.
Recorrido jugable	Atmósfera mínima. Bordes, peligros y personaje plenamente legibles.
Muros y troncos posteriores	Bruma ligera en intervalos, dejando zonas despejadas.
Fondo y dosel lejano	Menor contraste y saturación; pérdida gradual de detalle.
Color gris verdoso o azul grisáceo desaturado.
Mayor presencia en espacios bajos y detrás de los muros, sin ocultar plataformas inferiores.
Evitar una densidad uniforme: alternar masas y aperturas.
Movimiento, si se utiliza, lento y de baja amplitud. Sin pulsaciones ni nubes atravesando continuamente el personaje.
La lectura esencial debe mantenerse con una solución atmosférica sencilla; el look no dependerá de efectos volumétricos costosos.

Rechazo: niebla blanca que lava la escena, bruma cyan saturada, haces opacos o peligro oculto por atmósfera.

6. Dosel / cielo
Construir copas asimétricas mediante masas greybox agrupadas. Variar altura, separación y tamaño.
Dejar aperturas laterales que expliquen la entrada de luz y permitan percibir profundidad.
Evitar una banda horizontal continua de follaje: el dosel no debe parecer un techo genérico.
Alternar troncos, vacíos y masas de hojas. No repetir el mismo módulo con una cadencia evidente.
Usar el follaje cercano como marco parcial, sin cerrar ambos lados de la imagen ni tapar el recorrido.
Cielo visible en fragmentos: gris azul verdoso suave, con claridad cálida cerca de la apertura principal.
Las ruinas deben sentirse dentro del bosque. No colocarlas aisladas frente a un fondo plano de vegetación.
La toma de dosel debe conservar piedra y raíces en el encuadre para mantener la identidad del mundo.

Excluir: bambú como firma visual, arquitectura del sudeste asiático, copas esféricas repetidas, palmeras ornamentales dominantes y cielo espectacular que compita con el juego.

7. Grado de color + paleta sRGB orientativa

Tratamiento: masas amplias de color, textura contenida y contraste organizado. Conservar la simplificación pictórica de Cuyabeno paint_v03, evitando fotorealismo cinematográfico.

Paleta de partida; los hexadecimales son referencias sRGB, no colores finales de píxel después de iluminación y post.

Uso	Color	sRGB
Piedra base	Gris cálido mineral	#77766A
Piedra iluminada	Arena grisácea	#AAA083
Piedra húmeda	Gris verde oscuro	#46514B
Tierra y juntas	Marrón profundo	#352C23
Raíces	Marrón corteza	#63503A
Musgo	Verde oliva	#657047
Follaje medio	Verde bosque	#365647
Dosel en sombra	Verde profundo	#203D35
Bruma	Gris verde claro	#A1B3AA
Cielo entre copas	Azul gris verdoso	#C0CEC7
Luz cálida	Miel suave	#E3C58C
Cacao maduro	Amarillo / naranja / rojo tierra	#D7A43B / #C97632 / #A34D36
Saturación ambiental moderada; acentos de cacao pequeños y localizados.
Conservar detalle en sombras y luces. No aplastar negros ni blanquear la piedra.
Evitar un baño verde uniforme: piedra, tierra, raíces y vegetación deben distinguirse.
Bloom limitado a emisivos existentes; sin resplandor sobre piedra mojada.
Sin desenfoque de profundidad que dificulte juzgar el recorrido.
Si aparece Maya, usar el stub aprobado gris medio, nunca blanco ni con nuevos colores de vestuario.
No hornear texto, HUD, logos ni etiquetas en las imágenes.
8. Presupuesto greybox: tris, LOD y materiales

Topes propuestos para este brief, por chunk equivalente a aproximadamente una pantalla 2D. Incluyen su decoración asociada; no representan conteos ya medidos.

Grupo	LOD0 máximo	LOD1 máximo	LOD2 máximo
Piedra, suelo y muros	16.000	8.000	3.000
Raíces y troncos	8.000	4.000	1.500
Dosel y vegetación	10.000	5.000	2.000
Detalles y motivos Kakaw	4.000	2.000	1.000
Charcos y geometría atmosférica, si existen	2.000	1.000	500
Total por chunk	40.000	20.000	8.000

Estos topes quedan por debajo del techo general de 80.000 tris por chunk de la referencia técnica. No completar el presupuesto por llenar: reutilizar las mallas aprobadas y trabajar con menos geometría cuando sea suficiente.

Materiales y texturas

Chunk opaco: máximo 2 materiales compartidos — mineral/suelo y orgánico.
Máximo 2 slots por malla; preferir 1.
Charcos opcionales: 1 material adicional compartido, en malla separada.
Diferenciar variantes mediante atlas, máscaras simples o color de vértice. Evitar materiales únicos por bloque, raíz o planta.
Atlas de hasta 2K; texturas propias o con licencia CC0 verificada.
Preferir vegetación de masas opacas durante greybox. Minimizar planos transparentes superpuestos.

LOD y montaje

Mantener pivotes, límites del chunk, puntos de unión y posiciones de apoyos entre LOD.
Reducir primero detalles, ramificaciones y masas secundarias. Conservar las siluetas que explican el recorrido.
Los LOD visuales no modifican colisiones ni lógica.
Mantener plataformas móviles y elementos que ceden como piezas independientes; no fusionarlos con el fondo.
Contar triángulos después de aplicar modificadores y triangular.
Registrar geometría visible instanciada además del conteo de mallas únicas.
Usar como referencia inicial del piloto ≤180.000 tris activos y ≤80 draw calls; verificar en Godot. No declarar rendimiento a partir del conteo de Blender.

Qué NO hacer

High-poly, escultura, subdivisión de detalle, displacement geométrico o fotogrametría.
Tallados ornamentales densos, rostros, ojos, máscaras, castillos, almenas o reconstrucciones arqueológicas.
Nuevas plataformas, colisiones decorativas o cambios de timings.
Nuevos monumentos o tótems centrales para rellenar la composición.
Vegetación individual excesiva, transparencia masiva o luces de relleno por objeto.
Magenta, estética de platformer genérico o referencias arquitectónicas del sudeste asiático.
9. Entregables Assets
Entregable	Nombre / especificación
Script bpy reproducible	ruinas_look001.py
Escena editable	RUINAS_LOOK001.blend
Geometría LOD0	chunk_ruinas_\u003cid\u003e_LOD0.glb
Geometría LOD1	chunk_ruinas_\u003cid\u003e_LOD1.glb
Geometría LOD2	chunk_ruinas_\u003cid\u003e_LOD2.glb
Still de piedra	RUINAS_LOOK001_piedra.png, 1920×1080
Still de dosel	RUINAS_LOOK001_dosel.png, 1920×1080
Registro de entrega	RUINAS_LOOK001_manifest.json
Texturas, si se utilizan	Carpeta textures/, rutas relativas y licencias registradas

Script y escena

El script reconstruye el montaje sin sobrescribir fuentes aprobadas; incluye parámetros de look y semilla fija si existe variación procedural.
Separar colecciones de recorrido, decoración, proxies, luces y cámaras.
Incluir cámaras CAM_RUINAS_PIEDRA y CAM_RUINAS_DOSEL.
Exportar GLB a 1u = 1m, Y-up, sin inversión de ejes ni escalas negativas.
Conservar las piezas dinámicas separadas y correctamente identificadas.
Documentar la reproducción del look en Godot: no dar por transferidos automáticamente desde el .blend la niebla, el cielo o el post.

Stills

RUINAS_LOOK001_piedra.png: vista próxima a la cámara de juego. Debe mostrar apoyos claros, piedra seca/húmeda, raíces laterales y separación del fondo.
RUINAS_LOOK001_dosel.png: vista más abierta del mismo montaje. Debe mostrar aperturas laterales, dirección de luz y bruma entre planos, conservando ruinas visibles.
Ambos: PNG sRGB, 16:9, mismo rig de luz y grado de color; sin HUD, texto ni logos.
Registrar si cada imagen procede de Blender o Godot. Los stills de Blender no sustituyen la comprobación de importación.

Manifest mínimo

brief_id, world_id: "ruinas", display y versión.
Fuente 2D fijada, nivel y tramo representado; correspondencia de piezas con elementos del layout.
Archivos entregados y dependencias.
Tris por objeto/chunk/LOD; materiales, slots y resolución de texturas.
Escala, ejes, pivotes, dimensiones y separación visual/colisión.
Cámaras, iluminación, atmósfera y gestión de color utilizadas.
Versiones efectivamente utilizadas de Blender y Godot.
Origen/licencia de recursos.
Comprobaciones realizadas y pendientes, sin marcar como aprobado lo no verificado.

Aceptación LOOK001: footprint intacto; piedra y raíces como protagonistas; bosque húmedo legible; luz lateral coherente; humedad localizada; bruma sin ocultar el juego; cacao no figurativo; presupuestos cumplidos e importación comprobada. El resultado debe reconocerse como Ruinas de Kakaw, manteniendo continuidad visual con Cuyabeno paint_v03.
