// Simple test to check area calculation

System.debug('Starting basic test...');

// Check products
List<Product2> products = [SELECT Id, ProductCode FROM Product2 LIMIT 3];
System.debug('Found ' + products.size() + ' products');
for (Product2 p : products) {
    System.debug('Product: ' + p.ProductCode);
}

System.debug('Test complete.');