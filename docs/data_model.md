# Modelo de datos (capa Gold) – Esquema estrella

```mermaid
erDiagram
    dim_customers ||--o{ fact_sales : "customer_key"
    dim_products  ||--o{ fact_sales : "product_key"

    dim_customers {
        BIGINT customer_key PK "llave sustituta"
        INT customer_id
        NVARCHAR customer_number
        NVARCHAR first_name
        NVARCHAR last_name
        NVARCHAR country
        NVARCHAR marital_status
        NVARCHAR gender
        DATE birthdate
        DATE create_date
    }
    dim_products {
        BIGINT product_key PK "llave sustituta"
        INT product_id
        NVARCHAR product_number
        NVARCHAR product_name
        NVARCHAR category_id
        NVARCHAR category
        NVARCHAR subcategory
        NVARCHAR maintenance
        INT cost
        NVARCHAR product_line
        DATE start_date
    }
    fact_sales {
        NVARCHAR order_number
        BIGINT product_key FK
        BIGINT customer_key FK
        DATE order_date
        DATE shipping_date
        DATE due_date
        INT sales_amount
        INT quantity
        INT price
    }
```

- Regla de negocio: `sales_amount = quantity * price`.
- Las dimensiones están desnormalizadas (estrella, no copo de nieve): `dim_customers` integra CRM + ERP (AZ12, LOC_A101) y `dim_products` integra el producto con su categoría (PX_CAT_G1V2).
- Las llaves sustitutas se generan con `ROW_NUMBER()` dentro de las vistas.

- **Grano del hecho:** una línea de producto de una orden de venta de la fuente; `order_number`
  por sí solo no es llave única.
- Las marcas PK/FK del diagrama son relaciones lógicas: las vistas no crean restricciones
  físicas de llave primaria o foránea. La integridad se verifica con aserciones SQL.
- `ROW_NUMBER()` devuelve `BIGINT`. Las llaves se calculan al consultar las vistas y no son
  identificadores persistentes entre versiones distintas del dataset.
