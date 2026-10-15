# Bitácora de replicación verificable

## Referencias y alcance

- [Video del proyecto](https://www.youtube.com/watch?v=9GVqKuTVANE).
- [Plan de tareas publicado por el autor](https://thankful-pangolin-2ca.notion.site/SQL-Data-Warehouse-Project-16ed041640ef80489667cfe2f380b269).
- [Repositorio original revisado](https://github.com/DataWithBaraa/sql-data-warehouse-project/tree/34d06e5f808183d010b9a506bbd30aebd4a00fab).
- Punto de partida de esta revisión: `7631992499a7b3f3bcb3a94992cb6671a17fc064`.

La revisión inicial encontró scripts y documentación, pero no evidencia de ejecución.
Siete de los ocho SQL coincidían byte por byte con el original; Bronze solo cambiaba las
rutas. Los commits previos se conservan sin reescribir sus fechas ni presentarlos como
prueba de ejecución. Esta bitácora acredita una ejecución posterior reproducible.

## Pasos y entregables

| Paso | Entregable / ejecución | Cómo se comprueba |
|---|---|---|
| 1. Analizar requisitos | Requisitos en README; [análisis de fuentes](source_analysis.md) | CRM + ERP, ventas, alcance vigente y criterios explícitos |
| 2. Elegir arquitectura y diseñar capas | [Arquitectura](data_architecture.md) | Bronze/Silver como tablas; Gold como vistas |
| 3. Planificar tareas | Esta matriz de seguimiento | Cada actividad tiene archivo y criterio verificable |
| 4. Definir nombres y preparar repositorio | [Convenciones](naming_conventions.md), carpetas por capa | Nombres SQL coinciden con la documentación |
| 5. Crear base y esquemas | `scripts/run_all.sql` → `init_database.sql` | Primera corrida crea la base; segunda instalación es rechazada |
| 6. Analizar sistemas fuente | Inventario y manifiesto CSV | Seis huellas SHA-256, encabezados, ancho y conteos validados en Python |
| 7. Implementar ingesta Bronze | DDL + `bronze.load_bronze` | Seis cargas reales con `BULK INSERT` |
| 8. Validar completitud y estructura Bronze | `tests/quality_checks_bronze.sql` | Conteos CSV = SQL; preservación de IDs nulos y fechas crudas |
| 9. Documentar flujo e integración | Diagramas en `data_architecture.md` | Linaje por tabla, claves de unión y dependencias de Gold |
| 10. Explorar y limpiar Silver | `silver.load_silver`, `tests/profile_data.sql` | Conteos antes/después, reglas de deduplicación y normalización |
| 11. Validar Silver | Diagnósticos originales + `tests/assert_warehouse.sql` | Último cliente, dominios, costos, fechas e importes |
| 12. Explorar objetos de negocio | Análisis de fuentes y grano en [modelo](data_model.md) | Cliente, producto vigente y línea de venta definidos |
| 13. Integrar Gold | `scripts/gold/ddl_gold.sql` | Dos dimensiones y un hecho creados como vistas |
| 14. Validar Gold | Diagnósticos originales + aserciones | Claves de negocio únicas, cero ventas huérfanas, conservación de importes |
| 15. Documentar modelo y catálogo | Diagramas Mermaid, [catálogo](data_catalog.md) | Tipos `BIGINT`, relaciones lógicas y granularidad documentados |
| 16. Comprobar recarga y fallos | `tests/reload_and_failures.sql` | Comparación SHA-256 de todas las filas de los 15 objetos; rollback probado |
| 17. Guardar ejecución reproducible | `scripts/verify_pipeline.py` | Resultados, versión, fechas UTC, huellas y códigos de salida en evidencia |

Se usan Markdown y Mermaid como equivalentes versionables de las tareas de Notion y los
diagramas de Draw.io. No se afirma haber creado un tablero Notion ni archivos Draw.io.

## Evidencia de ejecución

La fuente del estado final es [`evidence/latest/summary.json`](evidence/latest/summary.json),
generada por el verificador, no una lista de resultados escritos manualmente.

| Archivo | Qué contiene |
|---|---|
| `server_version.txt` | Versión real del motor |
| `01_initial_load.txt` | Instalación, cargas y aceptación inicial |
| `02_before_after.txt` | Perfil agregado antes/después y métricas de ventas |
| `03_tutorial_silver_diagnostics.txt` | Salidas originales de exploración Silver |
| `04_tutorial_gold_checks.txt` | Salidas originales de comprobación Gold |
| `05_reload_and_rollback.txt` | Recarga, fallos intencionales y huellas completas |
| `06_existing_database_guard.txt` | Error esperado al intentar reinstalar sobre la base existente |
| `07_empty_table_rejected.txt` | Error esperado al vaciar ventas dentro de una transacción de prueba |
| `08_final_acceptance.txt` | Aserciones después de revertir la prueba negativa |
| `09_documented_reload.txt` | Ejecución de la entrada de recarga publicada en README |

Los errores en los archivos 05–07 son **provocados y esperados**. El verificador solo los
aprueba si encuentra el error esperado y confirma recuperación; un error inesperado
termina con código distinto de cero. Una recarga correcta debe conservar todos los valores
de negocio; solo puede cambiar `dwh_create_date`. Las pruebas de rollback incluyen también
esa columna en la comparación.

## Diferencias deliberadas respecto al original

1. Entradas SQLCMD con lotes `GO` correctos y rechazo de una base existente.
2. Ruta de CSV parametrizada, mayúsculas ERP correctas para Linux y copias de carga con
   CRLF final. Esta última corrección resuelve la pérdida de dos registros detectada al
   ejecutar la prueba de completitud; no cambia los CSV originales.
3. Cargas atómicas **por capa** y errores propagados con `THROW`.
4. Aserciones ejecutables y pruebas negativas; no basta con que un SELECT no devuelva filas.
   La comprobación de huérfanos usa `HASH JOIN` para evitar reevaluar las vistas con
   `ROW_NUMBER()` por cada venta; también se añadió esta opción al diagnóstico Gold.
   La condición de validación y las vistas de negocio se mantienen.
5. Catálogo corregido a `BIGINT` para las llaves calculadas con `ROW_NUMBER()`.
6. Evidencia de ejecución aislada, imagen fijada por digest y verificador sin dependencias Python externas.

El PDF del cuestionario se conserva como explicación del código del video. En particular,
la consecuencia de una fecha imposible allí descrita corresponde al original sin rollback;
la implementación actual revierte la capa y propaga ese error. Las reglas de transformación
de negocio se mantienen; ver los límites explícitos en [análisis de fuentes](source_analysis.md).
