using Toybox.Background as Bg;
using Toybox.System as Sys;
using Toybox.Communications as Comms;
using Toybox.Application as App;
using Toybox.Time;
using Toybox.Time.Gregorian;
using Toybox.Application.Storage;
using Toybox.Application.Properties;

(:background)
class BackgroundService extends Sys.ServiceDelegate {

    var _token;
    var _vehicle_id;

	(:background_method)
	function initialize() {
		Sys.ServiceDelegate.initialize();

//****************************************************************
//******** REMVOVED THIS SECTION IF TESLA CODE NOT WANTED ********
//****************************************************************
		if (Storage.getValue("Tesla") == null) {
			return;
		}

		// Need to get a token since we can't OAUTH from a watch face :-(
		// If someone can do it, be my guest. I spent too much time on this already
		_token = Properties.getValue("TeslaAccessToken");

		var createdAt = Storage.getValue("TeslaTokenCreatedAt");
		if (createdAt == null) {
			createdAt = 0;
		}

		var expiresIn = Storage.getValue("TeslaTokenExpiresIn");
		if (expiresIn == null) {
			expiresIn = 0;
		}
		
		var timeNow = Time.now().value();
		var interval = 5 * 60;
		var answer = (timeNow + interval < createdAt + expiresIn);

		if (_token != null && _token.equals("") == false && answer == true) {
//2023-03-05 var expireAt = new Time.Moment(createdAt + expiresIn);
//2023-03-05 var clockTime = Gregorian.info(expireAt, Time.FORMAT_MEDIUM);
//2023-03-05 var dateStr = clockTime.hour + ":" + clockTime.min.format("%02d") + ":" + clockTime.sec.format("%02d");
//2023-03-05 logMessage("initialize:Using token '" + _token.substring(0,10) + "...' which expires at " + dateStr);
			_token = "Bearer " + _token;
		}
		else {
			//2023-03-05 logMessage("initialize:Generating Access Token");
			var refreshToken = Properties.getValue("TeslaRefreshToken");
			if (refreshToken != null) {
				makeTeslaWebPost(refreshToken, method(:onReceiveToken));
			} else {
				//2023-03-05 logMessage("initialize:No refresh token!");
			}
			return;
		}

        _vehicle_id = Storage.getValue("TeslaVehicleID");
		if (_vehicle_id == null) {
			makeTeslaWebRequest("https://" + Properties.getValue("TeslaServerAPILocation") + "/api/1/vehicles", null, method(:onReceiveVehicles));
		} else {
			makeTeslaWebRequest("https://" + Properties.getValue("TeslaServerAPILocation") + "/api/1/vehicles/" + _vehicle_id.toString() + "/vehicle_data", null, method(:onReceiveVehicleData));
		}
//****************************************************************
//******************** END OF REMVOVED SECTION *******************
//****************************************************************
	}

	// Read pending web requests, and call appropriate web request function.
	// This function determines priority of web requests, if multiple are pending.
	// Pending web request flag will be cleared only once the background data has been successfully received.
	(:background_method)
	function onTemporalEvent() {
		var pendingWebRequests = Storage.getValue("PendingWebRequests");
		//2023-03-05 logMessage("onTemporalEvent:PendingWebRequests is '" + pendingWebRequests + "'");
		if (pendingWebRequests != null) {

			// 1. City local time.
			if (pendingWebRequests["CityLocalTime"] != null) {
				makeWebRequest(
					"https://script.google.com/macros/s/AKfycbwPas8x0JMVWRhLaraJSJUcTkdznRifXPDovVZh8mviaf8cTw/exec",
					{
						"city" => Properties.getValue("LocalTimeInCity")
					},
					method(:onReceiveCityLocalTime)
				);

			} 

			// 2. Weather.
			if (pendingWebRequests["OpenWeatherMapCurrent"] != null) {
				var owmKeyOverride = Properties.getValue("OWMKeyOverride");
				var lat = Properties.getValue("LastLocationLat");
				var lon = Properties.getValue("LastLocationLng");

				if (lat != null && lon != null) {
					makeWebRequest(
						"https://api.openweathermap.org/data/2.5/weather",
						{
							"lat" => lat,
							"lon" => lon,

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
							"appid" => ((owmKeyOverride == null) || (owmKeyOverride.length() == 0)) ? "2651f49cb20de925fc57590709b86ce6" : owmKeyOverride,

							"units" => "metric" // Celcius.
						},
						method(:onReceiveOpenWeatherMapCurrent)
					);
				}
			}

			// 3. Tesla
			if (pendingWebRequests["TeslaInfo"] != null && Storage.getValue("Tesla") != null) {
				if (!Sys.getDeviceSettings().phoneConnected) {
					return;
				}
					
				if (_vehicle_id) {
					makeTeslaWebRequest("https://" + Properties.getValue("TeslaServerAPILocation") + "/api/1/vehicles/" + _vehicle_id.toString() + "/vehicle_data", null, method(:onReceiveVehicleData));
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
			result = Storage.getValue("OpenWeatherMapCurrent");
			if (result) {
				result["cod"] = responseCode;
			} else {
				result = {
					"httpError" => responseCode
				};
			}

			/*var clockTime = Gregorian.info(Time.now(), Time.FORMAT_MEDIUM);
			var dateStr = clockTime.year + " " + clockTime.month + " " + clockTime.day + " " + clockTime.hour + ":" + clockTime.min.format("%02d") + ":" + clockTime.sec.format("%02d");
			Sys.println(dateStr + " : httpError=" + responseCode);*/
		}

		Bg.exit({
			"OpenWeatherMapCurrent" => result
		});
	}

//****************************************************************
//******** REMVOVED THIS SECTION IF TESLA CODE NOT WANTED ********
//****************************************************************
	(:background_method)
    function onReceiveToken(responseCode, data) {
		var result;

		//2023-03-05 logMessage("onReceiveToken responseCode is " + responseCode);
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

		//2023-03-05 logMessage("onReceiveVehicles responseCode is " + responseCode + " with data " + data);
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

		//2023-03-05 logMessage("onReceiveVehicleData responseCode is " + responseCode);
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

		Bg.exit({ "TeslaInfo" => result });
    }

	(:background_method)
    function makeTeslaWebPost(token, notify) {
        var url = "https://" + Properties.getValue("TeslaServerAUTHLocation") + "/oauth2/v3/token";
        Comms.makeWebRequest(
            url,
            {
				"grant_type" => "refresh_token",
				"client_id" => "ownerapi",
				"refresh_token" => token,
				"scope" => "openid email offline_access"
            },
            {
                :method => Comms.HTTP_REQUEST_METHOD_POST,
                :responseType => Comms.HTTP_RESPONSE_CONTENT_TYPE_JSON
            },
            notify
        );
    }

	(:background_method)
    function makeTeslaWebRequest(url, params, callback) {
		var options = {
            :method => Comms.HTTP_REQUEST_METHOD_GET,
            :headers => {
              		"Authorization" => _token,
					"User-Agent" => "Crystal-Tesla for Garmin",
					},
            :responseType => Comms.HTTP_RESPONSE_CONTENT_TYPE_JSON
        };
		//2023-03-05 logMessage("makeWebRequest url: '" + url + "'");
		Comms.makeWebRequest(url, params, options, callback);
    }
//****************************************************************
//******************** END OF REMVOVED SECTION *******************
//****************************************************************

	(:background_method)
	function makeWebRequest(url, params, callback) {
		var options = {
			:method => Comms.HTTP_REQUEST_METHOD_GET,
			:headers => {
					"Content-Type" => Comms.REQUEST_CONTENT_TYPE_URL_ENCODED},
			:responseType => Comms.HTTP_RESPONSE_CONTENT_TYPE_JSON
		};
		Comms.makeWebRequest(url, params, options, callback);
	}
}
