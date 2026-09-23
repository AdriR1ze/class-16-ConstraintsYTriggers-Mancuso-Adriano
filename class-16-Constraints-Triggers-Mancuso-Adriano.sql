
DROP TABLE IF EXISTS employees;

CREATE TABLE `employees` (
  `employeeNumber` int(11) NOT NULL,
  `lastName` varchar(50) NOT NULL,
  `firstName` varchar(50) NOT NULL,
  `extension` varchar(10) NOT NULL,
  `email` varchar(100) NOT NULL,
  `officeCode` varchar(10) NOT NULL,
  `reportsTo` int(11) DEFAULT NULL,
  `jobTitle` varchar(50) NOT NULL,
  PRIMARY KEY (`employeeNumber`)
);

INSERT INTO `employees`
(`employeeNumber`,`lastName`,`firstName`,`extension`,`email`,`officeCode`,`reportsTo`,`jobTitle`)
VALUES
(1002,'Murphy','Diane','x5800','dmurphy@classicmodelcars.com','1',NULL,'President'),
(1056,'Patterson','Mary','x4611','mpatterso@classicmodelcars.com','1',1002,'VP Sales'),
(1076,'Firrelli','Jeff','x9273','jfirrelli@classicmodelcars.com','1',1002,'VP Marketing');


-- =====================================================================
-- 1) Insertar un empleado con email NULL
-- =====================================================================
-- `email` fue declarado NOT NULL, por lo tanto esta sentencia falla:
--
-- ERROR 1048 (23000): Column 'email' cannot be null
--
-- El motor rechaza el INSERT completo, no se crea ninguna fila.
INSERT INTO employees
(employeeNumber, lastName, firstName, extension, email, officeCode, reportsTo, jobTitle)
VALUES
(1088, 'Smith', 'John', 'x1234', NULL, '1', 1002, 'Sales Rep');


-- =====================================================================
-- 2) UPDATE employeeNumber -20 / +20
-- =====================================================================

-- 2.a) Esta falla con "Duplicate entry ... for key 'employees.PRIMARY'"
-- porque employeeNumber es PRIMARY KEY y, al restar 20 fila por fila,
-- en algún punto intermedio dos filas terminan compitiendo por el mismo
-- valor de clave (el orden de procesamiento interno de filas no
-- garantiza que se eviten colisiones transitorias). MySQL revierte
-- toda la sentencia (ninguna fila queda modificada).
UPDATE employees SET employeeNumber = employeeNumber - 20;

-- 2.b) Esta en cambio SI funciona: al sumar 20, el orden ascendente en
-- que MySQL recorre las filas evita que dos filas tengan el mismo
-- valor de clave al mismo tiempo durante la operación.
UPDATE employees SET employeeNumber = employeeNumber + 20;


-- =====================================================================
-- 3) Columna age (16 a 70 años) con CHECK constraint
-- =====================================================================
ALTER TABLE employees
  ADD COLUMN age INT,
  ADD CONSTRAINT chk_employees_age CHECK (age BETWEEN 16 AND 70);

-- Pruebas:
-- OK
UPDATE employees SET age = 45 WHERE employeeNumber = 1002;
-- Debe fallar (CHECK constraint 'chk_employees_age' is violated)
-- UPDATE employees SET age = 12 WHERE employeeNumber = 1002;
-- UPDATE employees SET age = 90 WHERE employeeNumber = 1002;


-- =====================================================================
-- 4) Integridad referencial film / actor / film_actor (Sakila)
-- =====================================================================
-- film_actor es la tabla puente que resuelve la relación N:M entre
-- film y actor. Su definición (referencia, ya existe en sakila-schema.sql):
--
-- CREATE TABLE film_actor (
--   actor_id SMALLINT UNSIGNED NOT NULL,
--   film_id  SMALLINT UNSIGNED NOT NULL,
--   last_update TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
--                ON UPDATE CURRENT_TIMESTAMP,
--   PRIMARY KEY (actor_id, film_id),
--   KEY idx_fk_film_id (film_id),
--   CONSTRAINT fk_film_actor_actor FOREIGN KEY (actor_id)
--       REFERENCES actor (actor_id) ON DELETE RESTRICT ON UPDATE CASCADE,
--   CONSTRAINT fk_film_actor_film FOREIGN KEY (film_id)
--       REFERENCES film (film_id) ON DELETE RESTRICT ON UPDATE CASCADE
-- ) ENGINE=InnoDB;
--
-- Reglas de integridad referencial:
--  - actor_id y film_id en film_actor deben existir en actor.actor_id
--    y film.film_id respectivamente (no se puede insertar una fila
--    "huérfana" que apunte a un actor o película inexistente).
--  - PRIMARY KEY (actor_id, film_id) evita duplicar la misma relación.
--  - ON DELETE RESTRICT: no se puede borrar un actor o film mientras
--    tenga filas relacionadas en film_actor (hay que borrar primero
--    esas filas, o el borrado es rechazado).
--  - ON UPDATE CASCADE: si cambia el actor_id o film_id en la tabla
--    padre, el cambio se propaga automáticamente a film_actor.


-- =====================================================================
-- 5) Columna lastUpdate (+ bonus lastUpdateUser) con triggers
-- =====================================================================
ALTER TABLE employees
  ADD COLUMN lastUpdate DATETIME NULL,
  ADD COLUMN lastUpdateUser VARCHAR(100) NULL;

DELIMITER $$

DROP TRIGGER IF EXISTS employees_before_insert $$
CREATE TRIGGER employees_before_insert
BEFORE INSERT ON employees
FOR EACH ROW
BEGIN
    SET NEW.lastUpdate = NOW();
    SET NEW.lastUpdateUser = CURRENT_USER();
END$$

DROP TRIGGER IF EXISTS employees_before_update $$
CREATE TRIGGER employees_before_update
BEFORE UPDATE ON employees
FOR EACH ROW
BEGIN
    SET NEW.lastUpdate = NOW();
    SET NEW.lastUpdateUser = CURRENT_USER();
END$$

DELIMITER ;

-- Prueba
UPDATE employees SET jobTitle = 'VP Sales (LatAm)' WHERE employeeNumber = 1076 + 20;
SELECT employeeNumber, jobTitle, lastUpdate, lastUpdateUser FROM employees;


-- =====================================================================
-- 6) Triggers de Sakila que cargan film_text
-- =====================================================================
-- Estos triggers ya existen en sakila-schema.sql; se listan aquí con
-- su código fuente y explicación (no se re-crean automáticamente para
-- no chocar con la instalación estándar de Sakila).

-- ins_film: después de insertar una película, la copia a film_text.
-- CREATE TRIGGER ins_film AFTER INSERT ON film FOR EACH ROW
-- BEGIN
--     INSERT INTO film_text (film_id, title, description)
--     VALUES (new.film_id, new.title, new.description);
-- END;

-- upd_film: después de actualizar una película, si cambió el título o
-- la descripción, actualiza la fila correspondiente en film_text.
-- CREATE TRIGGER upd_film AFTER UPDATE ON film FOR EACH ROW
-- BEGIN
--     IF (old.title != new.title) OR (old.description != new.description)
--     THEN
--         UPDATE film_text
--         SET title = new.title, description = new.description, film_id = new.film_id
--         WHERE film_id = old.film_id;
--     END IF;
-- END;

-- del_film: después de borrar una película, borra la fila espejo en film_text.
-- CREATE TRIGGER del_film AFTER DELETE ON film FOR EACH ROW
-- BEGIN
--     DELETE FROM film_text WHERE film_id = old.film_id;
-- END;
