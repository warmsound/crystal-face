using Toybox.Background as Bg;
using Toybox.System as Sys;
using Toybox.Communications as Comms;
using Toybox.Application as App;
using Toybox.Time;
using Toybox.Time.Gregorian;

(:background)
class BackgroundService extends Sys.ServiceDelegate {

    var _token;
    var _vehicle_id;

	(:background_method)
	function initialize() {
		Sys.ServiceDelegate.initialize();

		// If we don't have a phone connected, don't go any further.
//		if (!Sys.getDeviceSettings().phoneConnected) {
//logMessage("initialize: No phone connected");
//			return;
//		}

		if (App.getApp().getProperty("Tesla") == null) {
//logMessage("initialize: Not requesting Tesla stuff, bailing out");
			return;
		}

		// Need to get a token since we can't OAUTH from a watch face :-(
		// If someone can do it, be my guest. I spent too much time on this already
		_token = App.getApp().getProperty("TeslaAccessToken");

		var createdAt = App.getApp().getProperty("TeslaTokenCreatedAt");
		if (createdAt == null) {
			createdAt = 0;
		}

		var expiresIn = App.getApp().getProperty("TeslaTokenExpiresIn");
		if (expiresIn == null) {
			expiresIn = 0;
		}
		
		var timeNow = Time.now().value();
		var interval = 5 * 60;
		var answer = (timeNow + interval < createdAt + expiresIn);

		if (_token != null && _token.equals("") == false && answer == true) {
			var expireAt = new Time.Moment(createdAt + expiresIn);
			var clockTime = Gregorian.info(expireAt, Time.FORMAT_MEDIUM);
			var dateStr = clockTime.hour + ":" + clockTime.min.format("%02d") + ":" + clockTime.sec.format("%02d");
//2022-04-04 logMessage("initialize:Using token '" + _token.substring(0,10) + "...' which expires at " + dateStr);
			_token = "Bearer " + _token;
		}
		else {
//2022-04-04 logMessage("initialize:Generating Access Token");
			var refreshToken = App.getApp().getProperty("TeslaRefreshToken");
			if (refreshToken != null) {
				makeTeslaWebPost(refreshToken, method(:onReceiveToken));
			} else {
//2022-04-04 logMessage("initialize:No refresh token!");
			}
			return;
		}

        _vehicle_id = App.getApp().getProperty("TeslaVehicleID");
		if (_vehicle_id == null) {
//2022-04-04 logMessage("initialize:Getting vehicle_id");
			makeTeslaWebRequest("https://owner-api.teslamotors.com/api/1/vehicles", null, method(:onReceiveVehicles));
		} else {
//2022-04-04 logMessage("initialize:Asking vehicle data for " + _vehicle_id);
			makeTeslaWebRequest("https://owner-api.teslamotors.com/api/1/vehicles/" + _vehicle_id.toString() + "/vehicle_data", null, method(:onReceiveVehicleData));
		}
	}

	// Read pending web requests, and call appropriate web request function.
	// This function determines priority of web requests, if multiple are pending.
	// Pending web request flag will be cleared only once the background data has been successfully received.
	(:background_method)
	function onTemporalEvent() {
		var pendingWebRequests = App.getApp().getProperty("PendingWebRequests");
//2022-04-04 logMessage("onTemporalEvent:PendingWebRequests is '" + pendingWebRequests + "'");
		if (pendingWebRequests != null) {

			// 1. City local time.
			if (pendingWebRequests["CityLocalTime"] != null) {
//logMessage("onTemporalEvent: doing city event");
				makeWebRequest(
					"https://script.google.com/macros/s/AKfycbwPas8x0JMVWRhLaraJSJUcTkdznRifXPDovVZh8mviaf8cTw/exec",
					{
						"city" => App.getApp().getProperty("LocalTimeInCity")
					},
					method(:onReceiveCityLocalTime)
				);

			// 2. Weather.
			} 
			if (pendingWebRequests["OpenWeatherMapCurrent"] != null) {
//logMessage("onTemporalEvent: doing weather event");
				var owmKeyOverride = App.getApp().getProperty("OWMKeyOverride");
				makeWebRequest(
					"https://api.openweathermap.org/data/2.5/weather",
					{
						"lat" => App.getApp().getProperty("LastLocationLat"),
						"lon" => App.getApp().getProperty("LastLocationLng"),

						// Polite request from Vince, developer of the Crystal Watch Face:
						//
						// Please do not abuse this API key, or else I will be forced to make thousands of users of Crystal
						// sign up for their own Open Weather Map free account, and enter their key in settings - a much worse
						// user experience for everyone.
						//
						// Crystal has been registered with OWM on the Open Source Plan, which lifts usage limits for free, so
						// that everyone benefits. However, these lifted limits only apply to the Current Weather API, and *not*
						// the One Call API. Usage of this key for the One Call API risks blocking the key for everyone.
						//
						// If you intend to use this key in your own app, especially for the One Call API, please create your own
						// OWM account, and own key. You should be able to apply for the Open Source Plan to benefit from the same
						// lifted limits as Crystal. Thank you.
						"appid" => ((owmKeyOverride != null) && (owmKeyOverride.length() == 0)) ? "2651f49cb20de925fc57590709b86ce6" : owmKeyOverride,

						"units" => "metric" // Celcius.
					},
					method(:onReceiveOpenWeatherMapCurrent)
				);

			// 3. Tesla
			}
			if (pendingWebRequests["TeslaInfo"] != null && App.getApp().getProperty("Tesla") != null) {
//2022-04-04 logMessage("onTemporalEvent: WebRequest for vehicle id " + _vehicle_id);
				if (!Sys.getDeviceSettings().phoneConnected) {
//2022-04-04 logMessage("onTemporalEvent: No phone connected");
//					pendingWebRequests["TeslaInfo"] = null;
					return;
				}
					
//logMessage("onTemporalEvent:TeslaInfo with vehicle_id at " + _vehicle_id);

				if (_vehicle_id) {
//logMessage("onTemporalEvent:Calling makeTeslaWebRequest to get vehicle data");
					makeTeslaWebRequest("https://owner-api.teslamotors.com/api/1/vehicles/" + _vehicle_id.toString() + "/vehicle_data", null, method(:onReceiveVehicleData));
				} else {
//logMessage("onTemporalEvent:NOT calling makeTeslaWebRequest for vehicle data because of null vehicle_id");
//					pendingWebRequests["TeslaInfo"] = null;
				}
			}
		} /* else {
			Sys.println("onTemporalEvent() called with no pending web requests!");
		} */
	}

	// Sample time zone data:
	/*
	{
	"requestCity":"london",
	"city":"London",
	"current":{
		"gmtOffset":3600,
		"dst":true
		},
	"next":{
		"when":1540688400,
		"gmtOffset":0,
		"dst":false
		}
	}
	*/

	// Sample error when city is not found:
	/*
	{
	"requestCity":"atlantis",
	"error":{
		"code":2, // CITY_NOT_FOUND
		"message":"City \"atlantis\" not found."
		}
	}
	*/
	(:background_method)
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

	// Sample invalid API key:
	/*
	{
		"cod":401,
		"message": "Invalid API key. Please see http://openweathermap.org/faq#error401 for more info."
	}
	*/

	// Sample current weather:
	/*
	{
		"coord":{
			"lon":-0.46,
			"lat":51.75
		},
		"weather":[
			{
				"id":521,
				"main":"Rain",
				"description":"shower rain",
				"icon":"09d"
			}
		],
		"base":"stations",
		"main":{
			"temp":281.82,
			"pressure":1018,
			"humidity":70,
			"temp_min":280.15,
			"temp_max":283.15
		},
		"visibility":10000,
		"wind":{
			"speed":6.2,
			"deg":10
		},
		"clouds":{
			"all":0
		},
		"dt":1540741800,
		"sys":{
			"type":1,
			"id":5078,
			"message":0.0036,
			"country":"GB",
			"sunrise":1540709390,
			"sunset":1540744829
		},
		"id":2647138,
		"name":"Hemel Hempstead",
		"cod":200
	}
	*/
	(:background_method)
	function onReceiveOpenWeatherMapCurrent(responseCode, data) {
		var result;
		
		// Useful data only available if result was successful.
		// Filter and flatten data response for data that we actually need.
		// Reduces runtime memory spike in main app.
		if (responseCode == 200) {
			result = {
				"cod" => data["cod"],
				"lat" => data["coord"]["lat"],
				"lon" => data["coord"]["lon"],
				"dt" => data["dt"],
				"temp" => data["main"]["temp"],
				"humidity" => data["main"]["humidity"],
				"icon" => data["weather"][0]["icon"]
			};

		// HTTP error: do not save.
		} else {
			result = {
				"httpError" => responseCode
			};
		}

		Bg.exit({
			"OpenWeatherMapCurrent" => result
		});
	}

	(:background_method)
    function onReceiveToken(responseCode, data) {
		var result;

//2022-04-04 logMessage("onReceiveToken responseCode is " + responseCode);
//logMessage("onReceiveToken data  is " + data);
        if (responseCode == 200) {
        	result = { "Token" => data };
        } else {
			result = { "httpErrorTesla" => responseCode };
	    }
		Bg.exit({ "TeslaInfo" => result });
    }

	(:background_method)
    function onReceiveVehicles(responseCode, data) {
		var result;

//2022-04-04 logMessage("onReceiveVehicles responseCode is " + responseCode + " with data " + data);
        if (responseCode == 200) {
            var vehicles = data.get("response");
            if (vehicles.size() > 0) {
                _vehicle_id = vehicles[0].get("id");
	        } else {
	            _vehicle_id = 0;
		    }
			result = { "vehicle_id" => _vehicle_id};

        } else {
			result = { "httpErrorTesla" => responseCode };
	    }

		Bg.exit({ "TeslaInfo" => result });
    }

	(:background_method)
    function onReceiveVehicleData(responseCode, data) {
		var results;
		var result = "N/A";
		var batterieLevel = "N/A";
		var chargingState = "Disconnected";
		var insideTemp = "N/A";
		var precondEnabled = "N/A";
		var sentryEnabled = "N/A";

//2022-04-04 logMessage("onReceiveVehicleData responseCode is " + responseCode);
        if (responseCode == 200) {
        	results = data.get("response");
        	if (results != null) {
	        	result = results.get("charge_state");
	        	if (result != null) {
		        	batterieLevel = result.get("battery_level");
		        	chargingState = result.get("charging_state");
		        	precondEnabled = result.get("preconditioning_enabled");
	        	}
	        	result = results.get("climate_state");
	        	if (result != null) {
		        	insideTemp = result.get("inside_temp");
				}	        	
				
	        	result = results.get("vehicle_state");
	        	if (result != null) {
		        	sentryEnabled = result.get("sentry_mode");
				}	        	
				
				result = {
					"battery_level" => batterieLevel,
					"charging_state" => chargingState
				};
        	}

			result = { "battery_state" => result, "inside_temp" => insideTemp, "preconditioning" => precondEnabled, "sentry_enabled" => sentryEnabled, "vehicle_id" => _vehicle_id };
        } else {
			result = { "httpErrorTesla" => responseCode };
	    }

//2022-04-04 logMessage("onReceiveVehicleData received " + result);

		Bg.exit({ "TeslaInfo" => result });
    }

	(:background_method)
	function makeWebRequest(url, params, callback) {
		var options = {
			:method => Comms.HTTP_REQUEST_METHOD_GET,
			:headers => {
					"Content-Type" => Communications.REQUEST_CONTENT_TYPE_URL_ENCODED},
			:responseType => Comms.HTTP_RESPONSE_CONTENT_TYPE_JSON
		};
		Comms.makeWebRequest(url, params, options, callback);
	}

	(:background_method)
    function makeTeslaWebRequest(url, params, callback) {
		var options = {
            :method => Comms.HTTP_REQUEST_METHOD_GET,
            :headers => {
              		"Authorization" => _token},
            :responseType => Comms.HTTP_RESPONSE_CONTENT_TYPE_JSON
        };
//logMessage("makeTeslaWebRequest with url='" + url + "' params='" + params + "' options='" + options + "'");
//logMessage("url=" + url + "\nparams=" + params + "\noptions=" + options);
		Comms.makeWebRequest(url, params, options, callback);
    }

	(:background_method)
    function makeTeslaWebPost(token, notify) {
        var url = "https://auth.tesla.com/oauth2/v3/token";
        Communications.makeWebRequest(
            url,
            {
				"grant_type" => "refresh_token",
				"client_id" => "ownerapi",
				"refresh_token" => token,
				"scope" => "openid email offline_access"
            },
            {
                :method => Communications.HTTP_REQUEST_METHOD_POST,
                :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
            },
            notify
        );
    }

(:debug)
function logMessage(message) {
	var clockTime = Gregorian.info(Time.now(), Time.FORMAT_MEDIUM);
	var dateStr = clockTime.hour + ":" + clockTime.min.format("%02d") + ":" + clockTime.sec.format("%02d");
	Sys.println(dateStr + " : " + message);
}

(:release)
function logMessage(output) {
}
}
