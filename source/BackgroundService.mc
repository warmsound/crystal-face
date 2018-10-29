using Toybox.Background as Bg;
using Toybox.System as Sys;
using Toybox.Communications as Comms;
using Toybox.Application as App;

(:background)
class BackgroundService extends Sys.ServiceDelegate {
	
	function initialize() {
		Sys.ServiceDelegate.initialize();
	}

	// Read pending web requests, and call appropriate web request function.
	// This function determines priority of web requests, if multiple are pending.
	// Pending web request flag will be cleared only once the background data has been successfully received.
	function onTemporalEvent() {
		//Sys.println("onTemporalEvent");
		var pendingWebRequests = App.Storage.getValue("PendingWebRequests");
		if (pendingWebRequests != null) {
			if (pendingWebRequests["CityLocalTime"] != null) {
				requestCityLocalTime();
			}
		} else {
			Sys.println("onTemporalEvent() called with no pending web requests!");
		}
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

	function requestCityLocalTime() {
		var url = "https://script.google.com/macros/s/AKfycbwPas8x0JMVWRhLaraJSJUcTkdznRifXPDovVZh8mviaf8cTw/exec";

		var city = App.getApp().getProperty("LocalTimeInCity");

		// #78 Setting with value of empty string may cause corresponding property to be null.
		// Safety check only, as normally would only expect requestCityLocalTime() to be called when city is set.
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
