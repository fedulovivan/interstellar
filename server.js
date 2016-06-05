var express = require('express');
var app = express();

app.get('/', function (req, res) {
  res.send(new Date);
  console.log(req.query, new Date);

});

app.listen(8080, function () {
  console.log('listening 8080..');
});

//1. connect to wifi
//2. set baudrate
//3. send requests