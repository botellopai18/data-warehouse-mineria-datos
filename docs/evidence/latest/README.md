# Resultado de la ejecución real

Estado: **PASS**. SQL Server 2022 Developer, versión `16.0.4305.5`, imagen fijada por digest.
Las nueve etapas del verificador terminaron según lo esperado. Ver `summary.json` para las
fechas UTC, códigos de salida, SHA-256 de código/entradas/salidas y confirmación de que el
contenedor temporal fue retirado.

| Resultado | Valor |
|---|---:|
| Clientes CRM originales / Bronze | 18,494 |
| Clientes limpios / Gold | 18,484 |
| Productos Silver / Gold vigentes | 397 / 295 |
| Líneas de venta Silver / Gold | 60,398 / 60,398 |
| Importe de ventas Gold | 29,356,250 |
| Unidades vendidas | 60,423 |
| Clientes sin ID descartados | 4 |
| Duplicados excedentes de cliente descartados | 6 |
| Nombres con espacios externos, antes / después | 29 / 0 |
| Ventas con inconsistencia aritmética, antes / después | 35 / 0 |
| Nacimientos futuros, antes / después | 16 / 0 |
| Ventas sin cliente o producto | 0 |

La recarga conserva el contenido completo de los 15 objetos, comprobado por hashes de
filas ordenadas. Los errores intencionales de archivo inexistente y fecha imposible se
propagan y revierten la capa; se comprueba que tampoco cambien sus fechas técnicas.
Se rechazó una instalación sobre una base existente y una tabla de ventas vacía.

**Condiciones conservadas del tutorial:** 19 fechas de orden desconocidas y 15 fechas de
nacimiento anteriores a 1924. Se registran explícitamente; no se inventan fechas ni se
eliminan esos clientes. Detalle y alcance en `../../source_analysis.md`.

Reproducción desde la raíz: `python3 scripts/verify_pipeline.py`.
