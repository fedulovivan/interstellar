var express = require('express');
var app = express();

app.get('/', function (req, res) {
  res.send("received " + req.query.cnt);	
  console.log(new Date);
  console.log(req.originalUrl);
});

app.listen(8080, function () {
  console.log('listening 8080..');
});