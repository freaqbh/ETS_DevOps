const express = require('express');
const app = express();
const port = process.env.PORT || 3000;

app.get('/', (req, res) => {
    res.send('Hello World! Deploy Otomatis via JCasC Berhasil! 2');
});

// Endpoint untuk smoke test post-deployment
app.get('/health', (req, res) => {
    res.status(200).json({ status: 'healthy' });
});

app.listen(port, () => {
    console.log(`App running on port ${port}`);
});