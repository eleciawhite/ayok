// Log the URLs we need
server.log("Turn LED On: " + http.agenturl() + "?led=1");
server.log("Turn LED Off: " + http.agenturl() + "?led=0");
 
function requestHandler(request, response) {
  try {
    if ("name" in request.query) {
        server.log("Hug sent by " + request.query.name);
                // convert the led query parameter to an integer
                
        local rgb = [request.query.r.tointeger(),
                    request.query.g.tointeger(),
                    request.query.b.tointeger()];
 
        device.send("hug", rgb); 
        
    }

    // send a response back saying everything was OK.
    response.send(200, "Thank you!");
  } catch (ex) {
    response.send(500, "Internal Server Error: " + ex);
  }
}
 
// register the HTTP handler
http.onrequest(requestHandler);