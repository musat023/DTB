
DROP DATABASE IF EXISTS sportovni_potreby;
CREATE DATABASE sportovni_potreby
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;
USE sportovni_potreby;


CREATE TABLE categories (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(100) NOT NULL UNIQUE,
  description TEXT
) ENGINE=InnoDB;

CREATE TABLE manufacturers (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(150) NOT NULL UNIQUE,
  contact_info TEXT
) ENGINE=InnoDB;


CREATE TABLE products (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(200) NOT NULL,
  sku VARCHAR(100) NOT NULL UNIQUE,
  category_id INT UNSIGNED NOT NULL,
  manufacturer_id INT UNSIGNED NOT NULL,
  price DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  description TEXT,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_products_category FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_products_manufacturer FOREIGN KEY (manufacturer_id) REFERENCES manufacturers(id) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT chk_price_nonneg CHECK (price >= 0)
) ENGINE=InnoDB;


CREATE TABLE stock_items (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  product_id INT UNSIGNED NOT NULL,
  quantity INT NOT NULL DEFAULT 0,
  location VARCHAR(100) DEFAULT 'Hlavní sklad',
  last_updated TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT fk_stock_product FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT chk_quantity_nonneg CHECK (quantity >= 0),
  CONSTRAINT uq_product_location UNIQUE (product_id, location)
) ENGINE=InnoDB;


CREATE INDEX idx_products_category ON products(category_id);
CREATE INDEX idx_products_manufacturer ON products(manufacturer_id);
CREATE INDEX idx_stock_product ON stock_items(product_id);


INSERT INTO categories (name, description) VALUES
  ('Oblečení', 'Sportovní oděv, trička, bundy, termoprádlo'),
  ('Náčiní', 'Různé sportovní náčiní'),
  ('Kola', 'Bicykly a komponenty'),
  ('Helmy', 'Ochranné helmy');

INSERT INTO manufacturers (name, contact_info) VALUES
  ('SportCo', 'sportco@example.com, +420 111 222 333'),
  ('BikeMaster', 'bikemaster@example.com'),
  ('HelmetKing', 'helmetking@example.com');


INSERT INTO products (name, sku, category_id, manufacturer_id, price, description)
VALUES ('Cyklistický dres Pro', 'SKU-DRS-001', (SELECT id FROM categories WHERE name='Oblečení'), (SELECT id FROM manufacturers WHERE name='SportCo'), 899.00, 'Lehký dres pro cyklisty');

INSERT INTO stock_items (product_id, quantity, location)
VALUES ((SELECT id FROM products WHERE sku='SKU-DRS-001'), 20, 'Hlavní sklad');


DROP PROCEDURE IF EXISTS insert_product_with_stock;
DELIMITER $$
CREATE PROCEDURE insert_product_with_stock(
  IN p_name VARCHAR(200),
  IN p_sku VARCHAR(100),
  IN p_category_id INT,
  IN p_manufacturer_id INT,
  IN p_price DECIMAL(10,2),
  IN p_description TEXT,
  IN p_init_quantity INT,
  IN p_location VARCHAR(100)
)
BEGIN

  DECLARE v_product_id INT DEFAULT NULL;
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN

    ROLLBACK;

    SELECT 'ERROR' AS status, 'RollBack executed due to SQL exception' AS message;
  END;


  START TRANSACTION;

  INSERT INTO products (name, sku, category_id, manufacturer_id, price, description)
  VALUES (p_name, p_sku, p_category_id, p_manufacturer_id, p_price, p_description);

  SET v_product_id = LAST_INSERT_ID();


  INSERT INTO stock_items (product_id, quantity, location)
  VALUES (v_product_id, COALESCE(p_init_quantity, 0), COALESCE(p_location, 'Hlavní sklad'));


  COMMIT;


  SELECT 'OK' AS status, v_product_id AS inserted_product_id;
END$$
DELIMITER ;


CALL insert_product_with_stock('Helma Ultra', 'SKU-HELM-100', (SELECT id FROM categories WHERE name='Helmy'), (SELECT id FROM manufacturers WHERE name='HelmetKing'), 1299.00, 'Lehká helma s větráním', 15, 'Hlavní sklad');


SELECT p.id, p.name, p.sku, c.name AS category, m.name AS manufacturer, p.price
FROM products p
JOIN categories c ON p.category_id = c.id
JOIN manufacturers m ON p.manufacturer_id = m.id
WHERE p.sku IN ('SKU-HELM-100', 'SKU-DRS-001');

SELECT * FROM stock_items WHERE product_id = (SELECT id FROM products WHERE sku='SKU-HELM-100');


CALL insert_product_with_stock('Fake Dres', 'SKU-DRS-001', (SELECT id FROM categories WHERE name='Oblečení'), (SELECT id FROM manufacturers WHERE name='SportCo'), 100.00, 'Tohle by mělo selhat kvůli duplicitnímu SKU', 5, 'Vedlejší sklad');


SELECT * FROM products WHERE name = 'Fake Dres';
SELECT * FROM stock_items WHERE location = 'Vedlejší sklad';


CALL insert_product_with_stock('Náramek fitness', 'SKU-BAND-001', (SELECT id FROM categories WHERE name='Náčiní'), (SELECT id FROM manufacturers WHERE name='SportCo'), 499.00, 'Fitness náramek', NULL, NULL);

SELECT p.id, p.name, p.sku, s.quantity, s.location
FROM products p JOIN stock_items s ON p.id = s.product_id
WHERE p.sku = 'SKU-BAND-001';

