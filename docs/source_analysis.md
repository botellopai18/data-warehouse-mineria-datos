# Análisis de fuentes y criterios de aceptación

Se trabaja con una fotografía completa de dos sistemas: CRM y ERP. Los seis archivos
versionados son la entrada del proyecto; no hay conexión a un CRM/ERP en producción,
extracción incremental ni historización adicional. El origen es el
[proyecto de Data with Baraa](https://github.com/DataWithBaraa/sql-data-warehouse-project).

## Inventario reproducible

| Archivo | Filas sin encabezado | Uso y llave de integración |
|---|---:|---|
| `source_crm/cust_info.csv` | 18,494 | Cliente: `cst_id` para ventas y `cst_key` para ERP |
| `source_crm/prd_info.csv` | 397 | Versiones de producto: `prd_key`; Silver deriva categoría y clave de producto |
| `source_crm/sales_details.csv` | 60,398 | Línea de venta: `sls_cust_id` y `sls_prd_key` |
| `source_erp/CUST_AZ12.csv` | 18,484 | Fecha de nacimiento y género: eliminar prefijo `NAS` de `CID` |
| `source_erp/LOC_A101.csv` | 18,484 | País: eliminar guiones de `CID` |
| `source_erp/PX_CAT_G1V2.csv` | 37 | Categorías: `ID` enlaza con `cat_id` de Silver |

El manifiesto [`tests/source_manifest.json`](../tests/source_manifest.json) conserva SHA-256,
encabezados y conteos. El verificador usa un lector CSV, comprueba el ancho de cada fila
y cuenta también el registro final aunque no tenga salto de línea. No usa `wc -l` para
contar registros. Respeta los nombres ERP en mayúsculas para Linux. Los originales usan
terminadores CRLF; el procedimiento Bronze especifica ese formato explícitamente.
Tres archivos carecen de CRLF final. En una primera ejecución, SQL Server omitió el último
registro de `cust_info.csv` y `CUST_AZ12.csv` (18,493 y 18,483 filas respectivamente).
`prepare_sources.py` agrega ese terminador a las **copias de carga**, nunca a las fuentes;
se valida que el número y contenido de registros CSV no cambien. `summary.json` registra
las huellas originales y preparadas, y los archivos que recibieron el terminador.

## Reglas y decisiones

- **Clientes:** 18,494 filas menos cuatro sin `cst_id` y seis duplicados excedentes =
  18,484 clientes. Conservar el registro con fecha de creación más reciente; limpiar nombres
  y estandarizar género/estado civil. El descarte es explícito, no pérdida accidental.
- **Productos:** conservar las 397 versiones en Silver; derivar `cat_id` y `prd_key`,
  reemplazar costo nulo por cero, normalizar línea y calcular vigencia con `LEAD`.
  Gold publica los 295 productos vigentes (`prd_end_dt IS NULL`).
- **Ventas:** conservar las 60,398 líneas, convertir fechas y aplicar las reglas aritméticas
  del video. Gold debe conservar el mismo conteo e importe total que Silver.
- **ERP:** normalizar claves/país/género; fechas de nacimiento futuras pasan a `NULL`.
  El CRM es la fuente prioritaria de género; ERP completa los valores `n/a` en Gold.
- **Historial y grano:** únicamente el modelo de negocio vigente. Un número de orden puede
  tener varias líneas; no se deduplican ventas por número de orden.

## Exploración frente a aceptación

Los `quality_checks_silver.sql` y `quality_checks_gold.sql` del tutorial se mantienen como
consultas exploratorias; Gold incorpora una opción `HASH JOIN` sin cambiar su condición. Un `SELECT DISTINCT` devuelve categorías válidas: que tenga filas
no significa que una prueba falló. El chequeo de nacimientos anteriores a 1924 es un dato
para revisar; el ETL del tutorial no los elimina y no existe un requisito de edad máxima.
Las fechas de orden desconocidas quedan en `NULL` según la regla del video, sin inventarlas.
[`tests/profile_data.sql`](../tests/profile_data.sql) registra estas condiciones y los
conteos antes/después, sin publicar nombres de clientes.

Las aserciones nuevas son la puerta de aceptación: fallan con `THROW` por conteos distintos,
duplicados de identificadores, importes inconsistentes, normalización inválida, productos
sin vigencia coherente o ventas sin dimensión. Verifican además la unicidad de las claves
de negocio: comprobar solo `ROW_NUMBER()` no detecta una integración que multiplica filas.
Una tabla vacía debe fallar, aunque una consulta de duplicados sobre ella no devuelva filas.

## Límites del código del tutorial

Se mantienen las reglas originales para poder contrastarlas con el video y el cuestionario.
Una fecha de ocho dígitos imposible (por ejemplo, `20250230`) todavía produce error de
conversión. La mejora local garantiza rollback de toda la capa y propagación del error,
en lugar de dejar una carga parcial. Esto se verifica inyectando y retirando una fila
de prueba en la instancia desechable.

El caso simultáneo de importe nulo y precio negativo descrito en el cuestionario no se
reinterpreta: las expresiones originales pueden producir precio nulo. Si aparece en una
nueva fuente, las aserciones rechazan el resultado. Las verificaciones y conteos publicados
certifican los seis CSV versionados, no cualquier dataset futuro.
