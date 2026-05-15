DROP DATABASE IF EXISTS ecommerce;
CREATE DATABASE ecommerce CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE ecommerce;

SET FOREIGN_KEY_CHECKS=0;

-- 1. Clientes
CREATE TABLE Clientes (
id_cliente INT AUTO_INCREMENT PRIMARY KEY,
nombre VARCHAR(100) NOT NULL,
apellido VARCHAR(100) NOT NULL,
email VARCHAR(150) NOT NULL UNIQUE,
telefono VARCHAR(20),
fecha_registro DATE NOT NULL DEFAULT (CURRENT_DATE),
estatus ENUM('activo','inactivo') NOT NULL DEFAULT 'activo'
);

-- 2. Sucursales
CREATE TABLE Sucursales (
id_sucursal INT AUTO_INCREMENT PRIMARY KEY,
nombre VARCHAR(100) NOT NULL,
direccion VARCHAR(255) NOT NULL,
ciudad VARCHAR(100) NOT NULL,
telefono VARCHAR(20),
estatus ENUM('activa','inactiva') NOT NULL DEFAULT 'activa'
);

-- 3. Proveedores
CREATE TABLE Proveedores (
id_proveedor INT AUTO_INCREMENT PRIMARY KEY,
nombre VARCHAR(150) NOT NULL,
contacto VARCHAR(100),
email VARCHAR(150) NOT NULL,
telefono VARCHAR(20),
direccion VARCHAR(255),
pais VARCHAR(80) NOT NULL
);

-- 4. Productos
CREATE TABLE Productos (
id_producto INT AUTO_INCREMENT PRIMARY KEY,
id_proveedor INT NOT NULL,
nombre VARCHAR(150) NOT NULL,
descripcion TEXT,
precio DECIMAL(10,2) NOT NULL,
categoria VARCHAR(100) NOT NULL,
estatus ENUM('activo','inactivo') NOT NULL DEFAULT 'activo',
CONSTRAINT fk_productos_proveedor FOREIGN KEY (id_proveedor) REFERENCES Proveedores(id_proveedor)
);

-- 5. Direcciones
CREATE TABLE Direcciones (
id_direccion INT AUTO_INCREMENT PRIMARY KEY,
id_cliente INT NOT NULL,
calle VARCHAR(200) NOT NULL,
ciudad VARCHAR(100) NOT NULL,
estado VARCHAR(100) NOT NULL,
codigo_postal VARCHAR(10) NOT NULL,
es_principal BOOLEAN NOT NULL DEFAULT FALSE,
CONSTRAINT fk_direcciones_cliente FOREIGN KEY (id_cliente) REFERENCES Clientes(id_cliente)
);

-- 6. Pedidos
CREATE TABLE Pedidos (
id_pedido INT AUTO_INCREMENT PRIMARY KEY,
id_cliente INT NOT NULL,
id_sucursal INT NOT NULL,
id_direccion INT NOT NULL,
fecha_pedido DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
estatus ENUM('pendiente','enviado','entregado','cancelado') NOT NULL DEFAULT 'pendiente',
total DECIMAL(10,2) NOT NULL,
CONSTRAINT fk_pedidos_cliente FOREIGN KEY (id_cliente) REFERENCES Clientes(id_cliente),
CONSTRAINT fk_pedidos_sucursal FOREIGN KEY (id_sucursal) REFERENCES Sucursales(id_sucursal),
CONSTRAINT fk_pedidos_direccion FOREIGN KEY (id_direccion) REFERENCES Direcciones(id_direccion)
);

-- 7. Pagos
CREATE TABLE Pagos (
id_pago INT AUTO_INCREMENT PRIMARY KEY,
id_pedido INT NOT NULL UNIQUE,
id_cliente INT NOT NULL,
monto DECIMAL(10,2) NOT NULL,
metodo ENUM('tarjeta','transferencia','efectivo','paypal') NOT NULL,
estatus ENUM('pendiente','completado','fallido') NOT NULL DEFAULT 'pendiente',
fecha_pago DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
CONSTRAINT fk_pagos_pedido FOREIGN KEY (id_pedido) REFERENCES Pedidos(id_pedido),
CONSTRAINT fk_pagos_cliente FOREIGN KEY (id_cliente) REFERENCES Clientes(id_cliente)
);

-- 8. Envios
CREATE TABLE Envios (
id_envio INT AUTO_INCREMENT PRIMARY KEY,
id_pedido INT NOT NULL,
transportista VARCHAR(100) NOT NULL,
numero_tracking VARCHAR(100),
estatus ENUM('preparando','en_camino','entregado') NOT NULL DEFAULT 'preparando',
fecha_estimada DATE,
fecha_entrega DATE,
CONSTRAINT fk_envios_pedido FOREIGN KEY (id_pedido) REFERENCES Pedidos(id_pedido)
);

-- 9. Inventario
CREATE TABLE Inventario (
id_inventario INT AUTO_INCREMENT PRIMARY KEY,
id_producto INT NOT NULL,
id_sucursal INT NOT NULL,
cantidad INT NOT NULL DEFAULT 0,
stock_minimo INT NOT NULL DEFAULT 5,
fecha_actualizacion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
UNIQUE KEY uq_inventario_prod_suc (id_producto, id_sucursal),
CONSTRAINT fk_inventario_producto FOREIGN KEY (id_producto) REFERENCES Productos(id_producto),
CONSTRAINT fk_inventario_sucursal FOREIGN KEY (id_sucursal) REFERENCES Sucursales(id_sucursal)
);

-- 10. Carritos
CREATE TABLE Carritos (
id_carrito INT AUTO_INCREMENT PRIMARY KEY,
id_cliente INT NOT NULL,
fecha_creacion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
fecha_modificacion DATETIME,
estatus ENUM('activo','abandonado','convertido') NOT NULL DEFAULT 'activo',
canal ENUM('web','mobile','app') NOT NULL DEFAULT 'web',
CONSTRAINT fk_carritos_cliente FOREIGN KEY (id_cliente) REFERENCES Clientes(id_cliente)
);

-- 11. Resenas
CREATE TABLE Resenas (
id_resena INT AUTO_INCREMENT PRIMARY KEY,
id_cliente INT NOT NULL,
id_producto INT NOT NULL,
calificacion TINYINT NOT NULL CHECK (calificacion BETWEEN 1 AND 5),
comentario TEXT,
fecha DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
CONSTRAINT fk_resenas_cliente FOREIGN KEY (id_cliente) REFERENCES Clientes(id_cliente),
CONSTRAINT fk_resenas_producto FOREIGN KEY (id_producto) REFERENCES Productos(id_producto)
);

-- 12. Devoluciones
CREATE TABLE Devoluciones (
id_devolucion INT AUTO_INCREMENT PRIMARY KEY,
id_pedido INT NOT NULL,
id_cliente INT NOT NULL,
id_producto INT NOT NULL,
motivo TEXT NOT NULL,
estatus ENUM('solicitada','aprobada','rechazada') NOT NULL DEFAULT 'solicitada',
fecha_solicitud DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
CONSTRAINT fk_devoluciones_pedido FOREIGN KEY (id_pedido) REFERENCES Pedidos(id_pedido),
CONSTRAINT fk_devoluciones_cliente FOREIGN KEY (id_cliente) REFERENCES Clientes(id_cliente),
CONSTRAINT fk_devoluciones_producto FOREIGN KEY (id_producto) REFERENCES Productos(id_producto)
);

-- 13. Pedido_Producto
CREATE TABLE Pedido_Producto (
id_pedido INT NOT NULL,
id_producto INT NOT NULL,
cantidad INT NOT NULL,
precio_unitario DECIMAL(10,2) NOT NULL,
PRIMARY KEY (id_pedido, id_producto),
CONSTRAINT fk_pedprod_pedido FOREIGN KEY (id_pedido) REFERENCES Pedidos(id_pedido),
CONSTRAINT fk_pedprod_producto FOREIGN KEY (id_producto) REFERENCES Productos(id_producto)
);

-- 14. Wishlist
CREATE TABLE Wishlist (
id_cliente INT NOT NULL,
id_producto INT NOT NULL,
fecha_agregado DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
PRIMARY KEY (id_cliente, id_producto),
CONSTRAINT fk_wishlist_cliente FOREIGN KEY (id_cliente) REFERENCES Clientes(id_cliente),
CONSTRAINT fk_wishlist_producto FOREIGN KEY (id_producto) REFERENCES Productos(id_producto)
);

-- 15. Carrito_Producto
CREATE TABLE Carrito_Producto (
id_carrito INT NOT NULL,
id_producto INT NOT NULL,
cantidad INT NOT NULL DEFAULT 1,
PRIMARY KEY (id_carrito, id_producto),
CONSTRAINT fk_carprod_carrito FOREIGN KEY (id_carrito) REFERENCES Carritos(id_carrito),
CONSTRAINT fk_carprod_producto FOREIGN KEY (id_producto) REFERENCES Productos(id_producto)
);

SET FOREIGN_KEY_CHECKS=1;
