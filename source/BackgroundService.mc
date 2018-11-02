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

			// 1. City local time.
			if (pendingWebRequests["CityLocalTime"] != null) {
				makeWebRequest(
					"https://script.google.com/macros/s/AKfycbwPas8x0JMVWRhLaraJSJUcTkdznRifXPDovVZh8mviaf8cTw/exec",
					{
						"city" => App.getApp().getProperty("LocalTimeInCity")
					},
					method(:onReceiveCityLocalTime)
				);

			// 2. Weather.
			// TODO: Record API key used, to detect when user changes it in case of "invalid API key" response.
			} else if (pendingWebRequests["OpenWeatherMapCurrent"] != null) {
				makeWebRequest(
					"https://api.openweathermap.org/data/2.5/weather",
					{
						"lat" => App.getApp().getProperty("LastLocationLat"),
						"lon" => App.getApp().getProperty("LastLocationLng"),
						"appid" => "d72271af214d870eb94fe8f9af450db4"
					},
					method(:onReceiveOpenWeatherMapCurrent)
				);
			}
		} else {
			Sys.println("onTemporalEvent() called with no pending web requests!");
		}
	}

	function onReceiveCityLocalTime(responseCode, data) {

		// HTTP failure: return responseCode.
		// Otherwise, return data response.
		if (responseCode != 200) {
			data = {
				"httpError" => responseCode
			};
		}

		Bg.exit({
			"CityLocalTime" => data
		});
	}

	function onReceiveOpenWeatherMapCurrent(responseCode, data) {
		
		// HTTP failure: return responseCode.
		// Otherwise, return data response.
		if (responseCode != 200) {
			data = {
				"httpError" => responseCode
			};
		}

		Bg.exit({
			"OpenWeatherMapCurrent" => data
		});
	}

	function makeWebRequest(url, params, callback) {
		var options = {
			:method => Comms.HTTP_REQUEST_METHOD_GET,
			:headers => {
					"Content-Type" => Communications.REQUEST_CONTENT_TYPE_URL_ENCODED},
			:responseType => Comms.HTTP_RESPONSE_CONTENT_TYPE_JSON
		};

		Comms.makeWebRequest(url, params, options, callback);
	}
}
