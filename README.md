# entrega_final_sql
# Proyecto Capstone: EDA de un e-commerce con PostgreSQL

Este proyecto simula el trabajo de un analista de datos sobre una tienda de comercio electrónico. Se construyó una base de datos relacional en PostgreSQL, se cargaron datos de clientes, productos y pedidos, se realizó un proceso de validación y limpieza, y finalmente se desarrollaron consultas SQL para responder preguntas de negocio.

El objetivo principal es transformar datos operativos en información útil para analizar clientes, evolución de ventas, rotación de productos y rendimiento por categoría.

---

## Problema de negocio

La tienda necesita obtener una visión clara de su operación comercial durante el año 2025.

El análisis busca responder las siguientes preguntas:

1. ¿Cuáles son los cinco clientes que realizaron el mayor gasto?
2. ¿Cómo evolucionaron las ventas mes a mes?
3. ¿Cuáles son los tres productos con menor cantidad de unidades vendidas?
4. ¿Cómo se posicionan los productos dentro de cada categoría según sus unidades vendidas?

Para los análisis de ventas se consideran únicamente los pedidos con estado `Completado`, ya que representan operaciones finalizadas.

Los importes se presentan como valores monetarios sin especificar una moneda, por tratarse de un dataset educativo.

---

## Archivos del repositorio

| Archivo          | Contenido                                                                                                |
| ---------------- | -------------------------------------------------------------------------------------------------------- |
| `estructura.sql` | Creación de las tablas, restricciones, carga de datos, vistas de datos limpios y verificaciones básicas. |
| `analisis.sql`   | Validación y limpieza de datos, comprobación de tipos y cuatro análisis de negocio comentados.           |
| `README.md`      | Contexto del proyecto, modelo de datos, proceso de limpieza, principales hallazgos y forma de ejecución. |

---

## Dataset y modelo

El proyecto utiliza un modelo relacional compuesto por tres tablas principales:

| Tabla       | Registros | Función                                                        |
| ----------- | --------: | -------------------------------------------------------------- |
| `clientes`  |        70 | Información de los clientes de la tienda.                      |
| `productos` |        30 | Catálogo de productos, categorías, precios, stock y atributos. |
| `pedidos`   |       400 | Operaciones realizadas por los clientes sobre los productos.   |

En total se cargan **500 registros**.

El período analizado corresponde al año **2025**, con pedidos desde el **4 de enero de 2025** hasta el **30 de diciembre de 2025**.

### Relación entre las tablas

## Diagrama entidad-relación

![Diagrama entidad-relación](images/diagrama_erd.png)

## Documentación del proyecto

![Documentación del proyecto](images/segunda_imagen.png)


La estructura utiliza `PRIMARY KEY` para identificar registros y `FOREIGN KEY` para garantizar la integridad de las relaciones.

---

## Características del modelo

Además de los tipos de datos básicos, el modelo utiliza características específicas de PostgreSQL:

* `DATE` para fechas.
* `NUMERIC(10,2)` para importes.
* `JSONB` para almacenar atributos adicionales de los productos.
* `TEXT` para las descripciones.
* `PRIMARY KEY` y `FOREIGN KEY` para integridad referencial.
* `UNIQUE` para evitar emails duplicados.

El campo `precio_unitario` de `pedidos` se mantiene separado de `productos.precio` porque representa el precio registrado en el momento de realizar una compra. Esto permite conservar el valor histórico de la operación aunque el precio actual del producto pueda cambiar posteriormente.

---

# Limpieza y calidad de datos

Antes de realizar los análisis se ejecutaron diferentes controles de calidad sobre las tres tablas.

### Valores NULL

Se verificaron las columnas relevantes de `clientes`, `productos` y `pedidos`.

En `clientes` no se encontraron valores NULL en las columnas analizadas.

En `productos` se detectaron **2 valores NULL en `precio`**.

En `pedidos` se detectaron **4 valores NULL en `precio_unitario`**.

Los precios faltantes se trataron mediante `COALESCE`, utilizando `0` como valor para los cálculos analíticos.

No se modificaron los registros originales. En su lugar, se crearon vistas que funcionan como una capa de datos limpios:

* `productos_limpios`
* `pedidos_limpios`

Esto permite conservar la información original y, al mismo tiempo, trabajar con datos preparados para el análisis.

### Validación de tipos

Se utilizó `information_schema.columns` para verificar los tipos de datos de las columnas relacionadas con fechas e importes.

Se confirmó que:

* Las fechas utilizan `DATE`.
* Los importes utilizan `NUMERIC`.

### Validación temporal

Se verificó el rango de fechas de los pedidos:

* Primera fecha: **2025-01-04**
* Última fecha: **2025-12-30**

También se comprobaron valores NULL y fechas de registro de clientes fuera de rango.

### Cantidades y estados

Se verificaron las cantidades de productos en los pedidos para detectar valores nulos o menores o iguales a cero.

La distribución de estados de los pedidos es:

| Estado     | Pedidos |
| ---------- | ------: |
| Completado |     229 |
| Pendiente  |      93 |
| Cancelado  |      78 |
| **Total**  | **400** |

Los análisis de ventas utilizan únicamente los **229 pedidos completados**.

### Integridad de clientes

También se verificaron:

* valores NULL en columnas relevantes;
* emails duplicados;
* nombres repetidos;
* rango de fechas de registro;
* fechas de registro futuras.

La repetición de nombres no se consideró automáticamente como duplicación de clientes, ya que diferentes personas pueden compartir el mismo nombre.

---

# Análisis y principales hallazgos

## 1. Top 5 clientes por gasto

Se calculó el gasto total de cada cliente utilizando la cantidad comprada y el precio unitario registrado en cada pedido completado.

| Posición | Cliente           | Ciudad        | Gasto total |
| -------: | ----------------- | ------------- | ----------: |
|        1 | Malena Gómez      | Rosario       |   $7.183,53 |
|        2 | Andrés Romero     | Mar del Plata |   $7.023,86 |
|        3 | Julieta Ruiz      | Santa Fe      |   $6.838,23 |
|        4 | Valentina Sánchez | Neuquén       |   $6.139,99 |
|        5 | Catalina Molina   | Mendoza       |   $4.589,47 |

Malena Gómez registra el mayor gasto entre los clientes analizados, con **$7.183,53**.

Los cinco clientes pertenecen a diferentes ciudades, por lo que el grupo de mayor gasto no se concentra en una única ciudad.

La consulta utiliza `JOIN`, `GROUP BY`, `SUM()` y `ORDER BY ... LIMIT 5`.

---

## 2. Evolución mensual de las ventas

Las ventas se agruparon por mes y se utilizó `LAG()` para comparar cada período con el mes anterior.

| Mes        | Ventas totales | Mes anterior | Variación |
| ---------- | -------------: | -----------: | --------: |
| Enero      |      $6.932,00 |        $0,00 |    0,00 % |
| Febrero    |      $5.592,00 |    $6.932,00 |  -19,33 % |
| Marzo      |     $14.838,47 |    $5.592,00 | +165,35 % |
| Abril      |     $10.344,78 |   $14.838,47 |  -30,28 % |
| Mayo       |      $5.233,80 |   $10.344,78 |  -49,41 % |
| Junio      |      $9.166,29 |    $5.233,80 |  +75,14 % |
| Julio      |     $16.317,92 |    $9.166,29 |  +78,02 % |
| Agosto     |     $10.227,82 |   $16.317,92 |  -37,32 % |
| Septiembre |      $6.853,73 |   $10.227,82 |  -32,99 % |
| Octubre    |      $6.699,37 |    $6.853,73 |   -2,25 % |
| Noviembre  |      $4.355,38 |    $6.699,37 |  -34,99 % |
| Diciembre  |     $13.772,62 |    $4.355,38 | +216,22 % |

La serie presenta una **variación considerable entre meses**.

Julio registra el mayor volumen de ventas del año, con **$16.317,92**.

Noviembre presenta el menor volumen, con **$4.355,38**.

La mayor variación positiva ocurre en diciembre, con un crecimiento del **216,22 % respecto de noviembre**.

La mayor contracción mensual se produce en mayo, con una variación de **-49,41 %** respecto de abril.

La consulta utiliza `DATE_TRUNC()`, `LAG()`, `CASE`, `NULLIF()` y una CTE para organizar el cálculo.

Estas variaciones describen el comportamiento del dataset, pero no permiten determinar por sí solas las causas de los cambios.

---

## 3. Tres productos menos vendidos

Se analizaron las unidades vendidas por producto considerando únicamente pedidos completados.

Además de las unidades, se calcularon la cantidad de pedidos y los ingresos generados.

| Ranking | Producto         | Categoría  | Unidades | Pedidos |  Ingresos |
| ------: | ---------------- | ---------- | -------: | ------: | --------: |
|       1 | Notebook Air 13  | Tecnología |        8 |       3 | $7.849,92 |
|       2 | Mochila Urbana   | Accesorios |        9 |       3 |   $539,91 |
|       3 | Smartphone X12   | Tecnología |       10 |       4 | $7.879,90 |
|       3 | Bicicleta Urbana | Deportes   |       10 |       4 | $6.920,10 |

El resultado devuelve cuatro productos porque `Smartphone X12` y `Bicicleta Urbana` empatan en la tercera posición con 10 unidades vendidas.

El análisis también muestra que el volumen de unidades no necesariamente representa el nivel de ingresos. Por ejemplo, Mochila Urbana registra 9 unidades vendidas y genera $539,91, mientras que Smartphone X12 registra 10 unidades y genera $7.879,90.

Se utiliza `LEFT JOIN` para conservar productos que eventualmente no tengan ventas completadas y `RANK()` para manejar empates.

---

## 4. Ranking de productos por categoría

Se calculó un ranking de productos dentro de cada categoría utilizando:

```sql
RANK() OVER (
    PARTITION BY categoria
    ORDER BY unidades_vendidas DESC
)
```

El uso de `PARTITION BY` permite que el ranking comience nuevamente en cada categoría.

Algunos de los principales resultados son:

| Categoría    | Ranking | Producto              | Unidades |  Ingresos |
| ------------ | ------: | --------------------- | -------: | --------: |
| Accesorios   |       1 | Botella Térmica       |       41 | $1.371,36 |
| Deportes     |       1 | Mancuernas 10kg       |       23 | $1.602,03 |
| Hogar        |       1 | Cafetera Espresso     |       29 | $5.509,71 |
| Indumentaria |       1 | Buzo Unisex           |       23 | $1.350,77 |
| Tecnología   |       1 | Auriculares Bluetooth |       38 | $4.373,25 |

En Tecnología, por ejemplo, Auriculares Bluetooth ocupa el primer lugar en unidades vendidas con 38 unidades.

Sin embargo, Notebook Pro 15 ocupa el sexto lugar en unidades con 15 unidades y genera **$18.849,85**, superando los ingresos de los demás productos de la categoría.

Esto muestra que **el producto con mayor volumen de unidades vendidas no necesariamente es el que genera mayores ingresos**.

También se observa un empate en Tecnología entre Monitor 27 4K y Cámara Digital, ambos con 13 unidades vendidas. `RANK()` asigna a ambos la posición 7.

---

# Tecnologías utilizadas

* PostgreSQL
* SQL
* pgAdmin 4
* `JOIN`
* `GROUP BY`
* CTEs (`WITH`)
* Funciones de ventana
* `RANK()`
* `LAG()`
* `DATE_TRUNC()`
* `COALESCE()`
* `CASE`
* `NULLIF()`
* `information_schema`
* `JSONB`

---

# Cómo ejecutar el proyecto

## Requisitos

* PostgreSQL instalado.
* pgAdmin 4, `psql` u otro cliente compatible.
* Permisos para crear y modificar tablas dentro de la base de datos utilizada.

## Opción A: pgAdmin

1. Abrir la base de datos donde se ejecutará el proyecto.
2. Abrir el Query Tool.
3. Ejecutar `estructura.sql` completo.
4. Verificar que los controles finales indiquen:

   * 70 clientes.
   * 30 productos.
   * 400 pedidos.
   * 30 registros en `productos_limpios`.
   * 400 registros en `pedidos_limpios`.
5. Ejecutar `analisis.sql`.
6. Revisar los resultados de cada análisis.

## Opción B: psql

Desde la carpeta del proyecto:

```bash
psql -U postgres -d capstone_project -f estructura.sql
psql -U postgres -d capstone_project -f analisis.sql
```

El nombre de la base de datos puede modificarse según la configuración utilizada.

### Importante

`estructura.sql` utiliza `DROP TABLE IF EXISTS` y `DROP VIEW IF EXISTS` para permitir reconstruir el proyecto desde cero.

Por lo tanto, **su ejecución elimina las tablas y vistas existentes del proyecto antes de volver a crearlas**. No debe ejecutarse sobre una base que contenga información que se quiera conservar.

---

# Matriz de cumplimiento

| Requisito                  | Evidencia                                                           |
| -------------------------- | ------------------------------------------------------------------- |
| Modelo relacional          | Tablas `clientes`, `productos` y `pedidos`.                         |
| Primary Keys               | Todas las tablas poseen clave primaria.                             |
| Foreign Keys               | `pedidos` se relaciona con `clientes` y `productos`.                |
| Tipos `DATE`               | Fechas de clientes y pedidos.                                       |
| Tipos `NUMERIC`            | Precios y precios unitarios.                                        |
| Tratamiento de NULL        | Validaciones y vistas con `COALESCE()`.                             |
| Validación de tipos        | Consulta mediante `information_schema.columns`.                     |
| JOIN                       | Utilizado en los cuatro análisis.                                   |
| GROUP BY                   | Utilizado para agregaciones por cliente, mes, producto y categoría. |
| Top 5 clientes             | Análisis 2.1.                                                       |
| Ventas mensuales           | Análisis 2.2 con `DATE_TRUNC()` y `LAG()`.                          |
| 3 productos menos vendidos | Análisis 2.3 con `LEFT JOIN` y `RANK()`.                            |
| Ranking por categoría      | Análisis 2.4 con `RANK() OVER (PARTITION BY ...)`.                  |
| CTEs                       | Utilizadas en los análisis de ventas y productos.                   |
| JSONB                      | Columna `atributos` de `productos`.                                 |
| Documentación              | Comentarios en las consultas y conclusiones en este README.         |

---

# Limitaciones

* El dataset es educativo y generado artificialmente; los resultados no representan una empresa real.
* El período analizado comprende únicamente el año 2025.
* Los importes no especifican una moneda.
* No se incluyen impuestos, costos, descuentos ni devoluciones.
* Los pedidos `Pendiente` y `Cancelado` no se consideran ventas completadas en los análisis comerciales.
* Las variaciones mensuales muestran cambios observados en el dataset, pero no permiten determinar las causas de esos cambios.
* La información de productos y clientes es estática dentro del dataset utilizado para el proyecto.

---

## Conclusión

El proyecto permite recorrer un flujo completo de análisis de datos utilizando PostgreSQL: desde la construcción del modelo y carga de información hasta la validación, limpieza y análisis de los datos.

La utilización de vistas como `pedidos_limpios` y `productos_limpios` permite separar los datos originales de la capa utilizada para el análisis, mientras que las CTEs y funciones de ventana permiten construir consultas más estructuradas y obtener indicadores como variaciones mensuales y rankings por categoría.

Los cuatro análisis muestran diferentes perspectivas del negocio: comportamiento de clientes, evolución temporal de las ventas, productos de menor rotación y posición relativa de los productos dentro de cada categoría.
