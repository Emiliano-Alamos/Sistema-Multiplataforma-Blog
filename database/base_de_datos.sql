-- ============================================================================
-- SCRIPT DE CREACIÓN DE LA BASE DE DATOS
-- Proyecto: Blog de Tecnologías Emergentes (UTEQ)
-- Tecnologías: Flutter, FastAPI y MySQL
--
-- Este script crea la base de datos y sus tres tablas principales.
-- La aplicación web y móvil comparten la misma información.
--
-- Para ejecutarlo desde MySQL:
-- SOURCE ruta/a/database/base_de_datos.sql;
--
-- Si las tablas ya existen, no se eliminan ni se modifican.
-- ============================================================================

CREATE DATABASE IF NOT EXISTS `bd_aplicacion_movil` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;

USE `bd_aplicacion_movil`;

-- ============================================================================
-- TABLA: USUARIO
--
-- Almacena los datos de las cuentas registradas.
-- pass: contraseña protegida mediante hash Argon2id.
-- tip_usu: 1 = Administrador, 2 = Usuario general.
-- ============================================================================

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
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_general_ci;

-- ============================================================================
-- TABLA: BLOG
--
-- Almacena las publicaciones sobre tecnologías emergentes.
--
-- titulo: nombre de la publicación.
-- desc: contenido o descripción.
-- img: dirección de la fotografía.
-- tags: etiquetas separadas por comas, como IA, Robótica o Tecnología.
-- fecha: fecha de publicación.
-- usr_id: usuario que creó la publicación.
--
-- Si se elimina el autor, la publicación se conserva.
-- ============================================================================

CREATE TABLE IF NOT EXISTS `blog` (
    `id_blog` int(11) NOT NULL AUTO_INCREMENT,
    `titulo` varchar(150) NOT NULL,
    `desc` text DEFAULT NULL,
    `img` varchar(500) DEFAULT NULL,
    `tags` varchar(255) DEFAULT NULL,
    `fecha` date NOT NULL DEFAULT(CURRENT_DATE),
    `usr_id` int(11) DEFAULT NULL,
    PRIMARY KEY (`id_blog`),
    KEY `ix_blog_id_blog` (`id_blog`),
    KEY `usr_id` (`usr_id`),
    CONSTRAINT `blog_ibfk_1` FOREIGN KEY (`usr_id`) REFERENCES `usuario` (`id_usr`) ON DELETE SET NULL
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_general_ci;

-- ============================================================================
-- TABLA: COMENTARIOS
--
-- Guarda los comentarios asociados a usuarios y publicaciones.
--
-- estatus:
-- 1 = Comentario visible.
-- 0 = Comentario oculto por el administrador.
--
-- Las relaciones impiden eliminar registros con comentarios asociados
-- sin resolver previamente esas relaciones.
-- ============================================================================

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
    CONSTRAINT `comentarios_ibfk_1` FOREIGN KEY (`usr_id`) REFERENCES `usuario` (`id_usr`),
    CONSTRAINT `comentarios_ibfk_2` FOREIGN KEY (`blog_id`) REFERENCES `blog` (`id_blog`)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_general_ci;

-- ============================================================================
-- PRIMER ADMINISTRADOR
--
-- El registro público crea usuarios generales (tip_usu = 2).
--
-- Para autorizar al primer administrador:
-- 1. Registrar una cuenta desde la aplicación.
-- 2. Ejecutar la siguiente consulta con el correo correspondiente.
-- 3. Cerrar sesión y volver a ingresar.
--
-- UPDATE `usuario`
-- SET `tip_usu` = 1
-- WHERE `mail` = 'tu_correo@ejemplo.com';
-- ============================================================================

-- ============================================================================
-- ACTUALIZACIÓN DE BASES ANTIGUAS
--
-- Solo utilizar estas instrucciones si una base anterior no tiene
-- los campos fecha o usr_id en la tabla blog.
--
-- ALTER TABLE `blog`
-- ADD COLUMN `fecha` date NOT NULL DEFAULT (CURRENT_DATE);
--
-- ALTER TABLE `blog`
-- ADD COLUMN `usr_id` int(11) DEFAULT NULL,
-- ADD KEY `usr_id` (`usr_id`),
-- ADD CONSTRAINT `blog_ibfk_1`
-- FOREIGN KEY (`usr_id`)
-- REFERENCES `usuario` (`id_usr`)
-- ON DELETE SET NULL;
-- ============================================================================