const express = require('express');
const app = express();
const PORT = 3000;

const products = [
    { name: 'Green Tea', description: 'Fresh and organic green tea leaves' },
    { name: 'Black Coffee', description: 'Rich and strong black coffee beans' },
    { name: 'Herbal Tea', description: 'Natural and healthy herbal tea mix' }
];

app.get('/products', (req, res) => {
    res.json(products);
});

app.listen(PORT, () => {
    console.log(`Backend server is running on port ${PORT}`);
});
