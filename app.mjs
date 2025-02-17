import express from 'express';

const app = express();

const inventoryItems = [
    { id: "1", item: "Item_1", price: "$1.84", sku: "7bd1bbfcb932eb074039de6c328bf466dad50479", description: "New Shimmer! It's a dessert topping and a floor wax!" },
    { id: "2", item: "Item_2", price: "$4.15", sku: "0f08eca48ef464118a328701927002c9790fdc49", description: "Romano Tours - European Catalog" },
    { id: "3", item: "Item_3", price: "$5.82", sku: "a452c87245844fb12a3f0503830ea1c27805551b", description: "Canis Cologne for Dogs" },
    { id: "4", item: "Item_4", price: "$5.18", sku: "9960f6f5c2a1f7413c1dc416b6d58cc937ef9acb", description: "Chia Head - Nice green hair just like a Chia Pet" },
    { id: "5", item: "Item_5", price: "$2.01", sku: "f2223fe1710fae70f781b5480b7e08c6047d134a", description: "Epoxy-Dent — The strongest denture cream permitted by law" },
    { id: "6", item: "Item_6", price: "$4.37", sku: "4a187ce508a7f99c2f9b6941f989790a3f7642b9", description: "Happy Fun Ball" },
    { id: "7", item: "Item_7", price: "$5.33", sku: "1b08b936fe8e5fd1cf9f76ecb42c05214283c66f", description: "Jiffy Pop Air Bag" },
    { id: "8", item: "Item_8", price: "$4.07", sku: "37b995b1763f722feaf93be737919f098e9f154c", description: "Milsford Spring Water" },
    { id: "9", item: "Item_9", price: "$3.43", sku: "67bddfd6b853d04473fb4c4567cf04dd78e6a211", description: "Swiffer Sleepers" },
    { id: "10", item: "Item_10", price: "$2.16", sku: "c4f7620640ab26dd704790341590a404330cd210", description: "Yard-a-Pult" }
];

app.get('/status', (req, res) => {
    res.send('OK');
});

app.get('/inventory', (req, res) => {
    res.json(inventoryItems);
});

app.get('/inventory/:id', (req, res) => {
    const itemId = req.params.id;
    if (req.headers['x-compute'] === 'true') {
        processCpu(1000*itemId);
    }
    // getFaultyItemById(itemId, res);
    getItemById(itemId, res);
});

const getFaultyItemById = (itemId, res) => {
    if (itemId % 2 === 0) {
        const message = 'Internal Server Error for DEMO, id received is an even number';
        console.error(message);
        res.status(500).send({ error: message });
        return;
    }
    getItemById(itemId, res);
};

const getItemById = (itemId, res) => {
    const item = inventoryItems.find(i => i.id === itemId);
    if (item) {
        const message = `Item with id ${itemId} found`;
        console.log(message);
        res.json(item);
        return;
    }
    const message = `Item with id ${itemId} not found`;
    console.error(message);
    res.status(404).send({ error: message });
};

const processCpu = (duration) => {
    console.log(`Processing CPU for ${duration}ms`);
    const startTime = new Date().getTime()
    var now = new Date().getTime()
    while((now - startTime) < duration) {
        for (let i = 0; i < 50; i++) {
            for (let j = 0; j < i * 50; j++) {
                now / Math.pow(Math.PI, Math.ceil(Math.random() * 10))
            }
        }
        now = new Date().getTime()
    }
}

export default app;
