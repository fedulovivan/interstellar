var express = require('express');
var bodyParser = require('body-parser');
var app = express();
app.use(bodyParser.json());

app.post('/', function (req, res) {
  res.send("OK"); // have to send response
  console.log(new Date);
  console.log(req.query);
  console.log(req.body);
});

app.listen(8080, function () {
  console.log('listening 8080..');
});