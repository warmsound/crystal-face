using Toybox.Background as Bg;
using Toybox.System as Sys;
using Toybox.Communications as Comms;

(:background)
class BackgroundService extends Sys.ServiceDelegate {
	
	function initialize() {
		Sys.ServiceDelegate.initialize();
	}

	function onTemporalEvent() {
		Sys.println("onTemporalEvent");
		makeRequest();
	}

	// set up the response callback function
	function onReceive(responseCode, data) {
		if (responseCode == 200) {
			Sys.println("Request Successful");
			Bg.exit(data);
		} else {
			Sys.println("Response: " + responseCode);
		}
	}

	function makeRequest() {
		var url = "https://script.google.com/macros/s/AKfycbwPas8x0JMVWRhLaraJSJUcTkdznRifXPDovVZh8mviaf8cTw/exec";

		var params = {
			"city" => "Cape Town"
		};

		var options = {
			:method => Comms.HTTP_REQUEST_METHOD_GET,
			:headers => {
					"Content-Type" => Communications.REQUEST_CONTENT_TYPE_URL_ENCODED},
			:responseType => Comms.HTTP_RESPONSE_CONTENT_TYPE_JSON
		};

		Sys.println("Making web request");
		Comms.makeWebRequest(url, params, options, method(:onReceive));
	}
}
