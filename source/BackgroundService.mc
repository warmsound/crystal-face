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
		if (Storage.getValue("Tesla") == null || gTeslaComplication == true) {
			return;
		}

		var teslaInfo = Bg.getBackgroundData();
		if (teslaInfo == null) {
			teslaInfo = {};
		}		
		else {
			/*DEDUG*/ var keys = teslaInfo.keys();
			/*DEBUG*/ logMessage("onReceiveVehicleData: Buffer has keys " + keys);
		}

		var timeNow = Time.now().value();
		var createdAt;
		var expiresIn;

		// Get the unexpired token from the buffer if we have one, otherwise from Properties/Storage
		_token = teslaInfo.get("AccessToken");
		createdAt = teslaInfo.get("TokenCreatedAt");
		expiresIn = teslaInfo.get("TokenExpiresIn");
		if (_token != null && createdAt != null && expiresIn != null) {
			if (timeNow > createdAt + expiresIn) {
				_token = null;
			}
		}
		else {
			_token = null;
		}

		if (_token == null) {
			_token = $.getStringProperty("TeslaAccessToken","");
			createdAt = Storage.getValue("TeslaTokenCreatedAt");
			expiresIn = Storage.getValue("TeslaTokenExpiresIn");
		}

		if (_token != null && createdAt != null && expiresIn != null) {
			if (timeNow > createdAt + expiresIn) {
				_token = null;
			}
		}
		else {
			_token = null;
		}
		

		if (_token != null && _token.equals("") == false) {
			//DEBUG*/ var expireAt = new Time.Moment(createdAt + expiresIn);
			//DEBUG*/ var clockTime = Gregorian.info(expireAt, Time.FORMAT_MEDIUM);
			//DEBUG*/ var dateStr = clockTime.hour + ":" + clockTime.min.format("%02d") + ":" + clockTime.sec.format("%02d");
			//DEBUG*/ logMessage("initialize:Using token '" + _token.substring(0,10) + "...' which expires at " + dateStr);
			_token = "Bearer " + _token;
		}
		else {
			_token = null;
		}

		_vehicle_id = teslaInfo.get("VehicleID");
		if (_vehicle_id == null) {
			_vehicle_id = Storage.getValue("TeslaVehicleID");
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
				/*DEBUG*/ logMessage("onTemporalEvent: Doing city local time");
				makeWebRequest(
					"https://script.google.com/macros/s/AKfycbwPas8x0JMVWRhLaraJSJUcTkdznRifXPDovVZh8mviaf8cTw/exec",
					{
						"city" => $.getStringProperty("LocalTimeInCity","")
					},
					method(:onReceiveCityLocalTime)
				);

			} 

			// 2. Weather.
			if (pendingWebRequests["OpenWeatherMapCurrent"] != null) {
				var owmKeyOverride = $.getStringProperty("OWMKeyOverride","");
				var lat = $.getStringProperty("LastLocationLat","");
				var lon = $.getStringProperty("LastLocationLng","");

				if (lat != null && lon != null) {
					/*DEBUG*/ logMessage("onTemporalEvent: Doing OWM");
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
					Bg.exit(null);
				}

				if (_token == null) {					
					/*DEBUG*/ logMessage("onTemporalEvent:Generating Access Token");
					var refreshToken = $.getStringProperty("TeslaRefreshToken","");
					if (refreshToken != null) {
						makeTeslaWebPost(refreshToken, method(:onReceiveToken));
					} else {
						/*DEBUG*/ logMessage("onTemporalEvent:No refresh token!");
						Bg.exit({ "TeslaInfo" => { "httpErrorTesla" => 401, "httpInternalErrorTesla" => 401 } });
					}
					return;
				}

				if (_vehicle_id == null) {
					/*DEBUG*/ logMessage("onTemporalEvent:Getting vehicles");
					makeTeslaWebRequest("https://" + $.getStringProperty("TeslaServerAPILocation","") + "/api/1/vehicles", null, method(:onReceiveVehicles));
					return;
				}

				/*DEBUG*/ logMessage("onTemporalEvent: Getting vehicle data");
				makeTeslaWebRequest("https://" + $.getStringProperty("TeslaServerAPILocation","") + "/api/1/vehicles/" + _vehicle_id + "/vehicle_data", null, method(:onReceiveVehicleData));
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
		/*DEBUG*/ logMessage("onReceiveCityLocalTime: " + responseCode);
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
		/*DEBUG*/ logMessage("onReceiveOpenWeatherMapCurrent: " + responseCode);
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

		Bg.exit({ "OpenWeatherMapCurrent" => result });
	}

//****************************************************************
//******** REMVOVED THIS SECTION IF TESLA CODE NOT WANTED ********
//****************************************************************
	(:background_method)
    function onReceiveToken(responseCode, responseData) {
		/*DEBUG*/ logMessage("onReceiveToken: " + responseCode);

		var teslaInfo = Bg.getBackgroundData();
		if (teslaInfo == null) {
			teslaInfo = {};
		}		
		else {
			/*DEDUG*/ var keys = teslaInfo.keys();
			/*DEBUG*/ logMessage("onReceiveToken: Buffer has keys " + keys);
		}

        if (responseCode == 200) {
			teslaInfo.put("AccessToken", responseData["access_token"]);
			teslaInfo.put("RefreshToken", responseData["refresh_token"]);
			teslaInfo.put("TokenExpiresIn", responseData["expires_in"]);
			teslaInfo.put("TokenCreatedAt", Time.now().value());
        }

		teslaInfo.put("httpErrorTesla", 401);
		teslaInfo.put("httpInternalErrorTesla", responseCode);

		Bg.exit({ "TeslaInfo" => teslaInfo });
    }

	(:background_method)
    function onReceiveVehicles(responseCode, responseData) {
		/*DEBUG*/ logMessage("onReceiveVehicles: " + responseCode);

		var teslaInfo = Bg.getBackgroundData();
		if (teslaInfo == null) {
			teslaInfo = {};
		}		
		else {
			/*DEDUG*/ var keys = teslaInfo.keys();
			/*DEBUG*/ logMessage("onReceiveVehicles: Buffer has keys " + keys);
		}

        if (responseCode == 200) {
            var vehicles = responseData.get("response");
			var vehice_state;
			if (vehicles != null) {
				if (vehicles.size() > 0) {
					_vehicle_id = vehicles[0].get("id").toString();
					vehice_state = vehicles[0].get("state");
				} else {
					_vehicle_id = null;
					vehice_state = "NoVehicles";
				}
			}
			else {
				_vehicle_id = null;
				vehice_state = "NoVehicleResponse";
			}
			teslaInfo.put("VehicleID", _vehicle_id);
			teslaInfo.put("VehicleState",vehice_state);
        }

		teslaInfo.put("httpErrorTesla", (_vehicle_id == null ? 404 : 408));
		teslaInfo.put("httpInternalErrorTesla", responseCode);

		Bg.exit({ "TeslaInfo" => teslaInfo });
    }

	(:background_method)
    function onReceiveVehicleData(responseCode, responseData) {
		/*DEBUG*/ logMessage("onReceiveVehicleData: " + responseCode);
        /*DEBUG*/ var myStats = Sys.getSystemStats();
        /*DEBUG*/ logMessage("Total memory: " + myStats.totalMemory + " Used memory: " + myStats.usedMemory + " Free memory: " + myStats.freeMemory);

		var teslaInfo = Bg.getBackgroundData();
		if (teslaInfo == null) {
			teslaInfo = {};
		}		
		else {
			/*DEDUG*/ var keys = teslaInfo.keys();
			/*DEBUG*/ logMessage("onReceiveVehicleData: Buffer has keys " + keys);
		}

		teslaInfo.put("httpErrorTesla", responseCode);

        if (responseCode == 200) {
			teslaInfo.put("VehicleState", "online");

        	var response = responseData.get("response");
        	if (response != null) {
	        	var result = response.get("charge_state");
	        	if (result != null) {
					teslaInfo.put("BatteryLevel", result.get("battery_level"));
					teslaInfo.put("ChargingState", result.get("charging_state"));
					teslaInfo.put("PrecondEnabled", result.get("preconditioning_enabled"));
	        	}
	        	result = response.get("climate_state");
	        	if (result != null) {
					teslaInfo.put("InsideTemp", result.get("inside_temp"));
				}	        	
				
	        	result = response.get("vehicle_state");
	        	if (result != null) {
					teslaInfo.put("SentryEnabled", result.get("sentry_mode"));
				}	        	
        	}
	    }
		// If no vehicle (rare) or can't contact (much more frequent) is received, try to get a new vehicle (404) or retrieve its state (408)
		else if (responseCode == 404 || responseCode == 408) {
			// If Tesla can't find our vehicle by its ID, reset it and maybe we'll have better luck next time
			if (responseCode == 404) {
				teslaInfo.put("VehicleID", null);
				_vehicle_id = null;
			}
			/*DEBUG*/ logMessage("Requesting vehicles from onReceiveVehicleData");
			makeTeslaWebRequest("https://" + $.getStringProperty("TeslaServerAPILocation","") + "/api/1/vehicles", null, method(:onReceiveVehicles));
			return;
	    }
		// Our access token has expired, ask for a new one
		else if (responseCode == 401) {
			var refreshToken = $.getStringProperty("TeslaRefreshToken","");
			if (refreshToken != null) {
				/*DEBUG*/ logMessage("Requesting access token from onReceiveVehicleData");
				makeTeslaWebPost(refreshToken, method(:onReceiveToken));
				return;
			}
		}

		Bg.exit({ "TeslaInfo" => teslaInfo });
    }

	(:background_method)
    function makeTeslaWebPost(token, notify) {
        var url = "https://" + $.getStringProperty("TeslaServerAUTHLocation","") + "/oauth2/v3/token";
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
