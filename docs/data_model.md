# Modelo de datos (capa Gold) – Esquema estrella

```mermaid
erDiagram
    dim_customers ||--o{ fact_sales : "customer_key"
    dim_products  ||--o{ fact_sales : "product_key"

    dim_customers {
        INT customer_key PK "llave sustituta"
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
        INT product_key PK "llave sustituta"
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
        INT product_key FK
        INT customer_key FK
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
