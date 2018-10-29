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
		//Sys.println("onTemporalEvent");
		requestTimeZone();
	}

	function onReceiveTimeZone(responseCode, data) {

		// HTTP success: return data response.
		if (responseCode == 200) {
			//Sys.println("Request Successful");
			Bg.exit(data);

		// HTTP failure: return responseCode.
		} else {
			//Sys.println("Response: " + responseCode);
			Bg.exit({
				"error" => {
					"responseCode" => responseCode
				}
			});
		}
	}

	function requestTimeZone() {
		var url = "https://script.google.com/macros/s/AKfycbwPas8x0JMVWRhLaraJSJUcTkdznRifXPDovVZh8mviaf8cTw/exec";

		var city = App.getApp().getProperty("LocalTimeInCity");

		// #78 Setting with value of empty string may cause corresponding property to be null.
		// Safety check only, as normally would only expect requestTimeZone() to be called when city is set.
		if (city == null) {
			return;
		}

		var params = {
			"city" => city
		};

		var options = {
			:method => Comms.HTTP_REQUEST_METHOD_GET,
			:headers => {
					"Content-Type" => Communications.REQUEST_CONTENT_TYPE_URL_ENCODED},
			:responseType => Comms.HTTP_RESPONSE_CONTENT_TYPE_JSON
		};

		//Sys.println("Making web request");
		Comms.makeWebRequest(url, params, options, method(:onReceiveTimeZone));
	}
}
