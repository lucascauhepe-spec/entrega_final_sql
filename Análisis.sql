-- ============================================================
-- 1. LIMPIEZA Y CALIDAD DE DATOS
-- ============================================================

----- VALIDACIÓN PRODUCTOS -----
SELECT
    COUNT(*) AS total_productos,
    COUNT(*) FILTER (WHERE nombre IS NULL) AS nombres_nulos,
    COUNT(*) FILTER (WHERE categoria IS NULL) AS categoria_nulos,
    COUNT(*) FILTER (WHERE precio IS NULL) AS precio_nulos,
    COUNT(*) FILTER (WHERE stock IS NULL) AS stock_nulos,
	COUNT(*) FILTER (WHERE descripcion IS NULL) AS descripcion_nulos,
	COUNT(*) FILTER (WHERE atributos IS NULL) AS atributos_nulos
FROM productos;


-- 1.1 Detectar valores NULL en columnas críticas
SELECT
    COUNT(*) AS total_productos,
    COUNT(*) FILTER (
		WHERE precio IS NULL
	) AS precios_nulos
FROM productos;

-- 1.2 Identificar productos con precio faltante

SELECT
    producto_id,
    nombre,
    categoria,
    precio
FROM productos
WHERE precio IS NULL;

-- 1.3 Aplicar COALESCE para obtener un precio limpio

SELECT
    producto_id,
    nombre,
    categoria,
    COALESCE(precio, 0) AS precio_limpio
FROM productos;

-- ============================================================
-- -- VISTA DE PRODUCTOS LIMPIOS CREADA EN "estructura.sql"
-- ============================================================



------ VALIDACIÓN PEDIDOS -----
SELECT
    COUNT(*) AS total_pedidos,
    COUNT(*) FILTER (WHERE fecha_pedido IS NULL) AS fecha_nulos,
    COUNT(*) FILTER (WHERE cantidad IS NULL) AS cantidad_nulos,
    COUNT(*) FILTER (WHERE precio_unitario IS NULL) AS precio_nulos,
    COUNT(*) FILTER (WHERE estado IS NULL) AS estado_nulos	
FROM pedidos;

-- 1.4 Detectar precios unitarios faltantes en pedidos

SELECT
    COUNT(*) AS total_pedidos,
    COUNT(*) FILTER (
        WHERE precio_unitario IS NULL
    ) AS precios_unitarios_nulos
FROM pedidos;

-- 1.5 Identificar pedidos con precio unitario faltante

SELECT
    pedido_id,
    cliente_id,
    producto_id,
    fecha_pedido,
    cantidad,
    precio_unitario,
    estado
FROM pedidos
WHERE precio_unitario IS NULL;

-- 1.6 Aplicar COALESCE al precio unitario

SELECT
    pedido_id,
    producto_id,
    cantidad,
    COALESCE(precio_unitario, 0) AS precio_unitario_limpio
FROM pedidos;

-- 1.7 Verificar fechas faltantes

SELECT
    COUNT(*) AS total_pedidos,
    COUNT(*) FILTER (
        WHERE fecha_pedido IS NULL
    ) AS fechas_nulas
FROM pedidos;

-- 1.8 Revisar rango temporal de los pedidos

SELECT
    MIN(fecha_pedido) AS primera_fecha,
    MAX(fecha_pedido) AS ultima_fecha
FROM pedidos;

-- 1.9 Detectar cantidades inválidas

SELECT
    pedido_id,
    cantidad
FROM pedidos
WHERE cantidad IS NULL
   OR cantidad <= 0;
   
-- 1.10 Revisar categorías de estado de los pedidos

SELECT
    estado,
    COUNT(*) AS cantidad_pedidos
FROM pedidos
GROUP BY estado
ORDER BY cantidad_pedidos DESC;

-- ============================================================
-- VISTA DE PEDIDOS LIMPIOS CREADA EN "estructura.sql"
-- ============================================================



----- VALIDACIÓN CLIENTES -----

-- 1.11 Revisar valores NULL en clientes

SELECT
    COUNT(*) AS total_clientes,
    COUNT(*) FILTER (WHERE nombre IS NULL) AS nombres_nulos,
    COUNT(*) FILTER (WHERE email IS NULL) AS emails_nulos,
    COUNT(*) FILTER (WHERE ciudad IS NULL) AS ciudades_nulas,
    COUNT(*) FILTER (WHERE fecha_registro IS NULL) AS fechas_registro_nulas
FROM clientes;

-- 1.12 Verificar emails duplicados

SELECT
    email,
    COUNT(*) AS cantidad
FROM clientes
GROUP BY email
HAVING COUNT(*) > 1;

-- 1.13 Detectar nombres repetidos

SELECT
    nombre,
    COUNT(*) AS cantidad
FROM clientes
GROUP BY nombre
HAVING COUNT(*) > 1
ORDER BY cantidad DESC;

-- 1.14 Revisar rango de fechas de registro

SELECT
    MIN(fecha_registro) AS primer_registro,
    MAX(fecha_registro) AS ultimo_registro
FROM clientes;


-- ------------------------------------------------------------
--  VALIDACIÓN DE TIPOS DE DATOS DE LAS TRES TABLAS
-- ------------------------------------------------------------
SELECT
    table_name,
    column_name,
    data_type
FROM information_schema.columns
WHERE table_name IN ('clientes', 'productos', 'pedidos')
  AND column_name IN (
      'fecha_registro',
      'fecha_pedido',
      'precio',
      'precio_unitario'
  )
ORDER BY
    table_name,
    column_name;


 		


-------------- ============================================================
-------------- 2. ANÁLISIS 
-------------- ============================================================

-- 2.1 Top 5 clientes por gasto total
--
-- Calculamos el gasto total de cada cliente multiplicando
-- la cantidad comprada por el precio unitario de cada pedido.

SELECT
    c.cliente_id,
    c.nombre,
    c.ciudad,
    SUM(
        p.cantidad * p.precio_unitario
    ) AS gasto_total
FROM clientes c
JOIN pedidos_limpios p
    ON c.cliente_id = p.cliente_id
WHERE p.estado = 'Completado'
GROUP BY
    c.cliente_id,
    c.nombre,
    c.ciudad
ORDER BY gasto_total DESC
LIMIT 5;


-- ============================================================
-- 2.2 VENTAS TOTALES POR MES Y VARIACIÓN MENSUAL
-- ============================================================

-- Primero calculamos las ventas totales de cada mes.
-- Luego utilizamos LAG() para obtener las ventas del mes anterior
-- y calcular la variación porcentual.

WITH ventas_mensuales AS (
    SELECT
        DATE_TRUNC('month', fecha_pedido)::DATE AS mes,
        SUM(
            cantidad * precio_unitario
        ) AS ventas_totales
    FROM pedidos_limpios 
    WHERE estado = 'Completado'
    GROUP BY DATE_TRUNC('month', fecha_pedido)
),
ventas_con_mes_anterior AS (
    SELECT
        mes,
        ventas_totales,
        LAG(ventas_totales) OVER (
            ORDER BY mes
        ) AS ventas_mes_anterior
    FROM ventas_mensuales
)
SELECT
	TO_CHAR(mes, 'FMMonth') ||' '||
	EXTRACT (YEAR FROM mes) AS mes_anio,
    ventas_totales,
    COALESCE(ventas_mes_anterior, 0) AS ventas_mes_anterior,
    CASE
		WHEN ventas_mes_anterior IS NULL THEN 0
		ELSE ROUND(
		        (
		            (ventas_totales - ventas_mes_anterior)
		            / NULLIF(ventas_mes_anterior, 0)
		        ) * 100,
		        2
		     ) 
	END AS variacion_porcentual
FROM ventas_con_mes_anterior
ORDER BY mes;


-- ============================================================
-- 2.3 TRES PRODUCTOS MENOS VENDIDOS
-- ============================================================

-- Analizamos los productos con menor cantidad de unidades vendidas.
-- Además calculamos cantidad de pedidos e ingresos generados para esos productos.
--
-- Se consideran únicamente pedidos completados.
-- LEFT JOIN permite incluir productos sin ventas.

WITH ventas_por_producto AS (
    SELECT
        pr.producto_id,
        pr.nombre,
        pr.categoria,
        COALESCE(SUM(p.cantidad), 0) AS unidades_vendidas,
        COUNT(p.pedido_id) AS cantidad_pedidos,
        COALESCE(
    		SUM(p.cantidad * p.precio_unitario),
    		0
		) AS ingresos_generados
    FROM productos_limpios pr
    LEFT JOIN pedidos_limpios p
        ON pr.producto_id = p.producto_id
        AND p.estado = 'Completado'
    GROUP BY
        pr.producto_id,
        pr.nombre,
        pr.categoria
),
productos_rank AS (
    SELECT
        *,
        RANK() OVER (
            ORDER BY unidades_vendidas ASC
        ) AS ranking
    FROM ventas_por_producto
)
SELECT
    ranking,
    producto_id,
    nombre,
    categoria,
    unidades_vendidas,
    cantidad_pedidos,
    ingresos_generados
FROM productos_rank
WHERE ranking <= 3
ORDER BY ranking, producto_id;


-- ============================================================
-- 2.4 RANKING DE PRODUCTOS POR CATEGORÍA
-- ============================================================

-- Calculamos las unidades vendidas por producto y luego
-- establecemos un ranking dentro de cada categoría.
--
-- Solo consideramos pedidos completados.

WITH ventas_por_producto AS (
    SELECT
        pr.producto_id,
        pr.nombre,
        pr.categoria,
        SUM(p.cantidad) AS unidades_vendidas,
        SUM(p.cantidad * p.precio_unitario) AS ingresos_generados
    FROM productos_limpios pr
    LEFT JOIN pedidos_limpios p
        ON pr.producto_id = p.producto_id
        AND p.estado = 'Completado'
    GROUP BY
        pr.producto_id,
        pr.nombre,
        pr.categoria
),
ranking_por_categoria AS (
    SELECT
        *,
        RANK() OVER (
            PARTITION BY categoria
            ORDER BY unidades_vendidas DESC
        ) AS ranking_categoria
    FROM ventas_por_producto
)
SELECT
    categoria,
    ranking_categoria,
    producto_id,
    nombre,
    unidades_vendidas,
    ingresos_generados
FROM ranking_por_categoria
ORDER BY
    categoria,
    ranking_categoria;
  