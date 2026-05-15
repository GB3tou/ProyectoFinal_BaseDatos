USE amazon_ecommerce;


-- INNER JOIN - Clientes con sus pedidos y el total gastado
SELECT
    c.id_cliente,
    CONCAT(c.nombre, ' ', c.apellido) AS cliente,
    p.id_pedido,
    p.fecha_pedido,
    p.total
FROM Clientes c
INNER JOIN Pedidos p ON c.id_cliente = p.id_cliente
ORDER BY c.id_cliente, p.fecha_pedido;

-- LEFT JOIN - Clientes que no tienen pedidos
SELECT
    c.id_cliente,
    CONCAT(c.nombre, ' ', c.apellido) AS cliente,
    c.email,
    p.id_pedido
FROM Clientes c
LEFT JOIN Pedidos p ON c.id_cliente = p.id_cliente
WHERE p.id_pedido IS NULL;

-- RIGHT JOIN - Productos que nunca han sido pedidos
SELECT
    pr.id_producto,
    pr.nombre AS producto,
    pr.precio,
    pp.id_pedido
FROM Pedido_Producto pp
RIGHT JOIN Productos pr ON pp.id_producto = pr.id_producto
WHERE pp.id_pedido IS NULL;

--  CROSS JOIN - Todas las combinaciones posibles de sucursales con proveedores 
SELECT
    s.id_sucursal,
    s.nombre AS sucursal,
    pr.id_proveedor,
    pr.nombre AS proveedor,
    pr.pais
FROM Sucursales s
CROSS JOIN Proveedores pr
ORDER BY s.id_sucursal, pr.id_proveedor;

--  View Pedido con nombre cliente, sucursal, dirección, total y estatus del envío
CREATE OR REPLACE VIEW vw_pedidos_completos AS
SELECT
    p.id_pedido,
    CONCAT(c.nombre, ' ', c.apellido) AS cliente,
    s.nombre AS sucursal,
    CONCAT(d.calle, ', ', d.ciudad, ', ', d.estado, ' CP ', d.codigo_postal) AS direccion,
    p.total,
    e.estatus AS estatus_envio
FROM Pedidos p
INNER JOIN Clientes c ON p.id_cliente = c.id_cliente
INNER JOIN Sucursales s ON p.id_sucursal = s.id_sucursal
INNER JOIN Direcciones d ON p.id_direccion = d.id_direccion
LEFT JOIN Envios e ON p.id_pedido = e.id_pedido;

-- Productos con inventario bajo

CREATE OR REPLACE VIEW vw_inventario_bajo AS
SELECT
    i.id_inventario,
    pr.id_producto,
    pr.nombre AS producto,
    s.nombre AS sucursal,
    i.cantidad,
    i.stock_minimo
FROM Inventario i
INNER JOIN Productos pr ON i.id_producto = pr.id_producto
INNER JOIN Sucursales s ON i.id_sucursal = s.id_sucursal
WHERE i.cantidad < i.stock_minimo;

-- Procedimiento guardado de registrar un nuevo pedido
DROP PROCEDURE IF EXISTS sp_registrar_pedido;
DELIMITER //
CREATE PROCEDURE sp_registrar_pedido(
    IN p_id_cliente INT,
    IN p_id_sucursal INT,
    IN p_id_direccion INT,
    IN p_total DECIMAL(10,2)
)
BEGIN
    INSERT INTO Pedidos (id_cliente, id_sucursal, id_direccion, fecha_pedido, total, estatus)
    VALUES (p_id_cliente, p_id_sucursal, p_id_direccion, NOW(), p_total, 'pendiente');
END //
DELIMITER ;


-- Cambia el estatus de una devolución a 'aprobada'
DROP PROCEDURE IF EXISTS sp_aprobar_devolucion;
DELIMITER //
CREATE PROCEDURE sp_aprobar_devolucion(
    IN p_id_devolucion INT
)
BEGIN
    UPDATE Devoluciones
    SET estatus = 'aprobada'
    WHERE id_devolucion = p_id_devolucion;
END //
DELIMITER ;

-- TRIGGER Después de insertar en
--    Pedido_Producto, resta la cantidad del inventario del
--    producto correspondiente 
DROP TRIGGER IF EXISTS trg_after_pedido;
DELIMITER //
CREATE TRIGGER trg_after_pedido
AFTER INSERT ON Pedido_Producto
FOR EACH ROW
BEGIN
    DECLARE v_id_sucursal INT;

    SELECT id_sucursal INTO v_id_sucursal
    FROM Pedidos
    WHERE id_pedido = NEW.id_pedido;

    UPDATE Inventario
    SET cantidad = cantidad - NEW.cantidad,
        fecha_actualizacion = NOW()
    WHERE id_producto = NEW.id_producto
        AND id_sucursal = v_id_sucursal;
END //
DELIMITER ;


-- Cuando un envío se marca como 'entregado', el pedido
-- correspondiente también pasa automáticamente a 'entregado'.
DROP TRIGGER IF EXISTS trg_after_envio;
DELIMITER //
CREATE TRIGGER trg_after_envio
AFTER UPDATE ON Envios
FOR EACH ROW
BEGIN
    IF NEW.estatus = 'entregado' AND OLD.estatus <> 'entregado' THEN
        UPDATE Pedidos
        SET estatus = 'entregado'
        WHERE id_pedido = NEW.id_pedido;
    END IF;
END //
DELIMITER ;

-- EVENT Cada 24 horas, cambia a
--     abandonado los carritos activos con más de 7 días sin
--     modificación
SET GLOBAL event_scheduler = ON;

DROP EVENT IF EXISTS evt_limpiar_carritos;
DELIMITER //
CREATE EVENT evt_limpiar_carritos
ON SCHEDULE EVERY 24 HOUR
DO
BEGIN
    DECLARE v_dias_limite INT DEFAULT 7;

    UPDATE Carritos
    SET estatus = 'abandonado'
    WHERE estatus = 'activo'
        AND DATEDIFF(NOW(), fecha_modificacion) > v_dias_limite;
END //
DELIMITER ;

--Users 
CREATE USER IF NOT EXISTS 'admin_amazon_ecommerce'@'localhost' IDENTIFIED BY 'AdminPass123!';
GRANT ALL PRIVILEGES ON amazon_ecommerce.* TO 'admin_amazon_ecommerce'@'localhost' WITH GRANT OPTION;


CREATE USER IF NOT EXISTS 'operativo_amazon_ecommerce'@'localhost' IDENTIFIED BY 'OperPass123!';
GRANT INSERT, UPDATE, SELECT ON amazon_ecommerce.* TO 'operativo_amazon_ecommerce'@'localhost';


CREATE USER IF NOT EXISTS 'consulta_amazon_ecommerce'@'localhost' IDENTIFIED BY 'ConsPass123!';
GRANT SELECT ON amazon_ecommerce.* TO 'consulta_amazon_ecommerce'@'localhost';


-- 15. CONSULTA ANALÍTICA Top 5 productos más vendidos 
WITH ventas_producto AS (
    SELECT
        pr.id_producto,
        pr.nombre AS producto,
        COUNT(pp.id_pedido) AS num_pedidos,
        SUM(pp.cantidad) AS unidades_vendidas,
        SUM(pp.cantidad * pp.precio_unitario) AS ingresos_totales
    FROM Productos pr
    INNER JOIN Pedido_Producto pp ON pr.id_producto = pp.id_producto
    GROUP BY pr.id_producto, pr.nombre
    HAVING SUM(pp.cantidad) > 0
)
SELECT
    id_producto,
    producto,
    num_pedidos,
    unidades_vendidas,
    ingresos_totales
FROM ventas_producto
ORDER BY unidades_vendidas DESC, ingresos_totales DESC
LIMIT 5;

-- CONSULTA ANALÍTICA Clientes con más devoluciones vs total de pedidos 
SELECT
    c.id_cliente,
    CONCAT(c.nombre, ' ', c.apellido) AS cliente,
    COUNT(p.id_pedido) AS total_pedidos,
    (SELECT COUNT(*) FROM Devoluciones d WHERE d.id_cliente = c.id_cliente) AS total_devoluciones,
    CASE
        WHEN (SELECT COUNT(*) FROM Devoluciones d WHERE d.id_cliente = c.id_cliente) >= 3 THEN 'Alto'
        WHEN (SELECT COUNT(*) FROM Devoluciones d WHERE d.id_cliente = c.id_cliente) >= 1 THEN 'Medio'
        ELSE 'Bajo'
    END AS nivel_devoluciones
FROM Clientes c
INNER JOIN Pedidos p ON c.id_cliente = p.id_cliente
GROUP BY c.id_cliente, c.nombre, c.apellido
HAVING total_devoluciones > 0
ORDER BY total_devoluciones DESC;

-- CONSULTA ANALÍTICA Ranking de sucursales por ventas mensuales 
SELECT
    s.nombre AS sucursal,
    MONTH(p.fecha_pedido) AS mes,
    SUM(p.total) AS ventas_mes,
    RANK() OVER (PARTITION BY MONTH(p.fecha_pedido) ORDER BY SUM(p.total) DESC) AS ranking,
    CASE
        WHEN SUM(p.total) >= 10000 THEN 'Alto'
        WHEN SUM(p.total) >= 5000 THEN 'Medio'
        ELSE 'Bajo'
    END AS nivel_ventas
FROM Sucursales s
INNER JOIN Pedidos p ON s.id_sucursal = p.id_sucursal
GROUP BY s.id_sucursal, s.nombre, MONTH(p.fecha_pedido)
ORDER BY mes, ranking;
