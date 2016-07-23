var express = require('express');
var app = express();
//var bodyParser = require('body-parser');
//app.use(bodyParser.json());

app.get('/', function (req, res) {
  res.send("OK");
  console.log(new Date);
  console.log(req.query);
});

app.listen(8080, function () {
  console.log('listening 8080..');
});