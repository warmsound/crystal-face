using Toybox.Background as Bg;
using Toybox.System as Sys;
using Toybox.Communications as Comms;
using Toybox.Application as App;

(:background)
class BackgroundService extends Sys.ServiceDelegate {
	
	function initialize() {
		Sys.ServiceDelegate.initialize();
	}

	function onTemporalEvent() {
		Sys.println("onTemporalEvent");
		requestTimeZone();
	}

	function onReceiveTimeZone(responseCode, data) {
		if (responseCode == 200) {
			Sys.println("Request Successful");
			Bg.exit(data);
		} else {
			Sys.println("Response: " + responseCode);
		}
	}

	function requestTimeZone() {
		var url = "https://script.google.com/macros/s/AKfycbwPas8x0JMVWRhLaraJSJUcTkdznRifXPDovVZh8mviaf8cTw/exec";

		var timeZone1City = App.getApp().getProperty("TimeZone1City");
		var params = {
			"city" => timeZone1City
		};

		var options = {
			:method => Comms.HTTP_REQUEST_METHOD_GET,
			:headers => {
					"Content-Type" => Communications.REQUEST_CONTENT_TYPE_URL_ENCODED},
			:responseType => Comms.HTTP_RESPONSE_CONTENT_TYPE_JSON
		};

		Sys.println("Making web request");
		Comms.makeWebRequest(url, params, options, method(:onReceiveTimeZone));
	}
}
