async function fetchProducts() {
    const response = await fetch("http://backend:3000/products");
    const products = await response.json();
    const productsDiv = document.getElementById("products");

    products.forEach(product => {
        const productElement = document.createElement("div");
        productElement.innerHTML = `<h2>${product.name}</h2><p>${product.description}</p>`;
        productsDiv.appendChild(productElement);
    });
}

fetchProducts();
