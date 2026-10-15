# Fallo de completitud observado antes de preparar los CSV

Salida real de una corrida inicial durante esta corrección. Con los archivos originales
sin CRLF final, SQL Server cargó 18,493 clientes CRM y 18,483 registros ERP de clientes,
frente a 18,494 y 18,484 registros detectados por el lector CSV. La aserción detuvo el flujo.
La ejecución final está en `../latest/`; esta salida es evidencia del fallo anterior,
no el resultado del código actual. No se modificaron los originales para corregirlo.
