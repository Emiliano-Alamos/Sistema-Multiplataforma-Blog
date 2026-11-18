-- ============================================================================
-- SCRIPT DE CREACIÓN DE LA BASE DE DATOS
-- Proyecto: Blog de Educación Financiera (UTEQ) · App móvil Flutter + FastAPI
--
-- Crea la base y sus tres tablas. Es el MISMO esquema que crea el backend
-- (backend_API/models.py) al arrancar, y el que usa también la versión web.
--
-- Cómo usarlo (una sola vez), desde la consola de MySQL / MariaDB:
--     SOURCE ruta/a/database/base_de_datos.sql;
--
-- Si la base o las tablas ya existen, el script no las modifica ni borra datos.
-- El nombre de la base debe ser el mismo que DB_NAME en backend_API/.env.
-- ============================================================================

CREATE DATABASE IF NOT EXISTS `bd_aplicacion_movil_pro`
  DEFAULT CHARACTER SET utf8mb4
  COLLATE utf8mb4_general_ci;

USE `bd_aplicacion_movil_pro`;


-- ----------------------------------------------------------------------------
-- Tabla: usuario
-- pass:    contraseña encriptada con Argon2id (nunca se guarda en texto plano).
-- tip_usu: 1 = Administrador, 2 = Usuario general.
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `usuario` (
  `id_usr` int(11) NOT NULL AUTO_INCREMENT,
  `nom_usr` varchar(100) NOT NULL,
  `mail` varchar(150) NOT NULL,
  `pass` varchar(255) NOT NULL,
  `dir_usr` varchar(200) DEFAULT NULL,
  `tip_usu` int(11) NOT NULL,
  PRIMARY KEY (`id_usr`),
  UNIQUE KEY `mail` (`mail`),
  KEY `ix_usuario_id_usr` (`id_usr`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


-- ----------------------------------------------------------------------------
-- Tabla: blog (publicaciones)
-- desc:   lleva comillas invertidas porque es una palabra reservada de SQL.
-- tags:   UNA etiqueta de la lista fija del proyecto.
-- fecha:  fecha de publicación; si no se envía, la base pone la fecha de hoy.
-- usr_id: autor de la publicación. Puede quedar vacío (NULL).
--         ON DELETE SET NULL: si se elimina al autor, la publicación se
--         conserva y solo queda sin autor.
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `blog` (
  `id_blog` int(11) NOT NULL AUTO_INCREMENT,
  `titulo` varchar(150) NOT NULL,
  `desc` text DEFAULT NULL,
  `img` varchar(500) DEFAULT NULL,
  `tags` varchar(255) DEFAULT NULL,
  `fecha` date NOT NULL DEFAULT (CURRENT_DATE),
  `usr_id` int(11) DEFAULT NULL,
  PRIMARY KEY (`id_blog`),
  KEY `ix_blog_id_blog` (`id_blog`),
  KEY `usr_id` (`usr_id`),
  CONSTRAINT `blog_ibfk_1` FOREIGN KEY (`usr_id`)
      REFERENCES `usuario` (`id_usr`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


-- ----------------------------------------------------------------------------
-- Tabla: comentarios
-- estatus: 1 = visible, 0 = oculto. La app y la web crean y muestran los de 1.
-- Las llaves foráneas NO borran en cascada: el backend y la web eliminan
-- primero los comentarios y después al usuario o la publicación, dentro de
-- una transacción.
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `comentarios` (
  `id_com` int(11) NOT NULL AUTO_INCREMENT,
  `comentario` text NOT NULL,
  `fecha` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `estatus` int(11) NOT NULL,
  `usr_id` int(11) NOT NULL,
  `blog_id` int(11) NOT NULL,
  PRIMARY KEY (`id_com`),
  KEY `usr_id` (`usr_id`),
  KEY `blog_id` (`blog_id`),
  KEY `ix_comentarios_id_com` (`id_com`),
  CONSTRAINT `comentarios_ibfk_1` FOREIGN KEY (`usr_id`)
      REFERENCES `usuario` (`id_usr`),
  CONSTRAINT `comentarios_ibfk_2` FOREIGN KEY (`blog_id`)
      REFERENCES `blog` (`id_blog`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


-- ============================================================================
-- PRIMER ADMINISTRADOR
-- El registro desde la app siempre crea un Usuario general (tip_usu = 2).
-- Para tener el primer administrador: regístrate en la app y después ejecuta
-- esta instrucción con tu correo (quita los dos guiones):
--
--   UPDATE `usuario` SET `tip_usu` = 1 WHERE `mail` = 'tu_correo@ejemplo.com';
--
-- Ese administrador ya puede dar de alta a otros desde la app o desde la web.
-- ============================================================================


-- ============================================================================
-- SOLO PARA BASES ANTIGUAS (creadas antes de estas columnas)
-- Si tu tabla `blog` ya existía sin `fecha` o sin `usr_id`, ejecuta una sola
-- vez lo que te falte (quita los dos guiones):
--
--   ALTER TABLE `blog` ADD COLUMN `fecha` date NOT NULL DEFAULT (CURRENT_DATE);
--
--   ALTER TABLE `blog`
--     ADD COLUMN `usr_id` int(11) DEFAULT NULL,
--     ADD KEY `usr_id` (`usr_id`),
--     ADD CONSTRAINT `blog_ibfk_1` FOREIGN KEY (`usr_id`)
--         REFERENCES `usuario` (`id_usr`) ON DELETE SET NULL;
-- ============================================================================
