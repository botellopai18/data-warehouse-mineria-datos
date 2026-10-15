# Convenciones de nombres

Reglas para nombrar esquemas, tablas, vistas, columnas y demás objetos del data warehouse.

## Principios generales

- **snake_case**: minúsculas y guion bajo (`_`) para separar palabras.
- **Idioma**: inglés para todos los nombres de objetos.
- **Palabras reservadas**: no usar palabras reservadas de SQL como nombres.

## Tablas

### Bronze y Silver
- El nombre empieza con el sistema fuente y conserva el nombre original de la tabla, sin renombrarla.
- Patrón **`<sistema_fuente>_<entidad>`**
  - `<sistema_fuente>`: `crm`, `erp`.
  - `<entidad>`: nombre exacto de la tabla en la fuente.
  - Ejemplo: `crm_cust_info` → información de clientes del CRM.

### Gold
- Nombres de negocio, con prefijo de categoría.
- Patrón **`<categoria>_<entidad>`**
  - Ejemplos: `dim_customers`, `dim_products`, `fact_sales`.

| Patrón    | Significado        | Ejemplo                               |
|-----------|--------------------|---------------------------------------|
| `dim_`    | Dimensión          | `dim_customers`, `dim_products`       |
| `fact_`   | Tabla de hechos    | `fact_sales`                          |
| `report_` | Tabla de reporte   | `report_sales_monthly`                |

## Columnas

### Llaves sustitutas
- Toda llave primaria de una dimensión termina en `_key`: **`<tabla>_key`**.
- Ejemplo: `customer_key` en `dim_customers`.

### Columnas técnicas
- Toda columna de metadatos generada por el warehouse empieza con **`dwh_`**: **`dwh_<nombre>`**.
- Ejemplo: `dwh_create_date` → fecha en que el registro se cargó al warehouse.

## Procedimientos almacenados

- Los procedimientos de carga siguen el patrón **`load_<capa>`**.
- Ejemplos: `bronze.load_bronze`, `silver.load_silver`.
