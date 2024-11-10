CREATE TABLE products (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100),
    description TEXT
);

INSERT INTO products (name, description) VALUES 
('Green Tea', 'Fresh and organic green tea leaves'),
('Black Coffee', 'Rich and strong black coffee beans'),
('Herbal Tea', 'Natural and healthy herbal tea mix');
