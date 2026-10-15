# Catálogo de datos – capa Gold

La capa Gold es la representación de negocio de los datos, pensada para análisis y reportes.
Está formada por **dimensiones** y **tablas de hechos** (implementadas como vistas).

## 1. gold.dim_customers
**Propósito:** datos de clientes enriquecidos con información demográfica y geográfica.

| Columna          | Tipo          | Descripción |
|------------------|---------------|-------------|
| customer_key     | BIGINT           | Llave sustituta que identifica cada cliente en la dimensión. |
| customer_id      | INT           | Identificador numérico del cliente en el CRM. |
| customer_number  | NVARCHAR(50)  | Identificador alfanumérico del cliente (p. ej. `AW00011000`). |
| first_name       | NVARCHAR(50)  | Nombre del cliente. |
| last_name        | NVARCHAR(50)  | Apellido del cliente. |
| country          | NVARCHAR(50)  | País de residencia (p. ej. `Australia`). |
| marital_status   | NVARCHAR(50)  | Estado civil (`Married`, `Single`, `n/a`). |
| gender           | NVARCHAR(50)  | Género (`Male`, `Female`, `n/a`); el CRM es la fuente maestra y el ERP es respaldo. |
| birthdate        | DATE          | Fecha de nacimiento (YYYY-MM-DD). |
| create_date      | DATE          | Fecha de creación del registro en el CRM. |

## 2. gold.dim_products
**Propósito:** información de productos y sus atributos (solo productos vigentes, `prd_end_dt IS NULL`).

| Columna        | Tipo          | Descripción |
|----------------|---------------|-------------|
| product_key    | BIGINT           | Llave sustituta del producto. |
| product_id     | INT           | Identificador interno del producto. |
| product_number | NVARCHAR(50)  | Código alfanumérico del producto (p. ej. `FR-R92B-58`). |
| product_name   | NVARCHAR(50)  | Nombre descriptivo (tipo, color, talla). |
| category_id    | NVARCHAR(50)  | Identificador de la categoría (p. ej. `CO_RF`). |
| category       | NVARCHAR(50)  | Categoría (Bikes, Components, …). |
| subcategory    | NVARCHAR(50)  | Subcategoría. |
| maintenance    | NVARCHAR(50)  | Si requiere mantenimiento (`Yes`/`No`). |
| cost           | INT           | Costo base del producto. |
| product_line   | NVARCHAR(50)  | Línea (Road, Mountain, Touring, Other Sales). |
| start_date     | DATE          | Fecha en que el producto estuvo disponible. |

## 3. gold.fact_sales
**Propósito:** transacciones de venta para análisis.

| Columna       | Tipo          | Descripción |
|---------------|---------------|-------------|
| order_number  | NVARCHAR(50)  | Número de orden (p. ej. `SO54496`). |
| product_key   | BIGINT           | Llave sustituta hacia `dim_products`. |
| customer_key  | BIGINT           | Llave sustituta hacia `dim_customers`. |
| order_date    | DATE          | Fecha de la orden. |
| shipping_date | DATE          | Fecha de envío. |
| due_date      | DATE          | Fecha de vencimiento del pago. |
| sales_amount  | INT           | Monto total de la línea (`quantity * price`). |
| quantity      | INT           | Unidades vendidas. |
| price         | INT           | Precio unitario. |
