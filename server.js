var http = require('http'),
	server = http.createServer(function(req, res){
		//console.log(arguments);
		res.end('Hi!1:' + req.url);
	});

server.listen(8080, function(){
	console.log('listening 8080..');
});	

//1. connect to wifi
//2. set baudrate
//3. send requests