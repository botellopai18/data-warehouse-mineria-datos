# Arquitectura de datos

## Capas (Medallion)

```mermaid
flowchart LR
    subgraph Fuentes
        CRM[CRM · CSV]
        ERP[ERP · CSV]
    end
    subgraph Bronze
        B1[crm_cust_info]
        B2[crm_prd_info]
        B3[crm_sales_details]
        B4[erp_cust_az12]
        B5[erp_loc_a101]
        B6[erp_px_cat_g1v2]
    end
    subgraph Silver
        S1[crm_cust_info]
        S2[crm_prd_info]
        S3[crm_sales_details]
        S4[erp_cust_az12]
        S5[erp_loc_a101]
        S6[erp_px_cat_g1v2]
    end
    subgraph Gold
        G1[dim_customers]
        G2[dim_products]
        G3[fact_sales]
    end
    CRM --> B1 & B2 & B3
    ERP --> B4 & B5 & B6
    B1 --> S1
    B2 --> S2
    B3 --> S3
    B4 --> S4
    B5 --> S5
    B6 --> S6
    S1 & S4 & S5 --> G1
    S2 & S6 --> G2
    S3 --> G3
```

| | Bronze | Silver | Gold |
|---|---|---|---|
| **Definición** | Datos crudos, sin cambios | Datos limpios y estandarizados | Datos listos para el negocio |
| **Objetivo** | Trazabilidad y depuración | Preparar datos para análisis | Consumo en reportes y analítica |
| **Tipo de objeto** | Tablas | Tablas | Vistas |
| **Método de carga** | Full load (TRUNCATE + BULK INSERT) | Full load (TRUNCATE + INSERT) | Ninguno |
| **Transformación** | Ninguna | Limpieza, estandarización, normalización, columnas derivadas, enriquecimiento | Integración, agregación, lógica de negocio |
| **Modelado** | Ninguno (as-is) | Ninguno (as-is) | Esquema estrella |
| **Usuarios** | Ingenieros de datos | Ingenieros y analistas de datos | Analistas y usuarios de negocio |

## Integración de datos

```mermaid
flowchart LR
    subgraph CRM
        C1[crm_sales_details<br/>transacciones]
        C2[crm_cust_info<br/>clientes]
        C3[crm_prd_info<br/>productos]
    end
    subgraph ERP
        E1[erp_cust_az12<br/>fecha de nacimiento, género]
        E2[erp_loc_a101<br/>país]
        E3[erp_px_cat_g1v2<br/>categorías]
    end
    C1 -- sls_prd_key = prd_key --> C3
    C1 -- sls_cust_id = cst_id --> C2
    C2 -- cst_key = cid --> E1
    C2 -- cst_key = cid --> E2
    C3 -- cat_id = id --> E3
```
