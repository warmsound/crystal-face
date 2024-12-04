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
	var _stop;
	var _bg_data;
	var _pendingWebRequests;

	(:background)
	function initialize() {
		/*DEBUG*/ logMessage("In ServiceDelegate");
		Sys.ServiceDelegate.initialize();

		if (_bg_data == null) {
			_bg_data = Bg.getBackgroundData();
			if (_bg_data == null) {
				_bg_data = {};
			}		
		}
		else {
			/*DEBUG*/ var keys = _bg_data.keys(); logMessage("initialize: _bg_data has keys " + keys);
		}

		_stop = false;

//****************************************************************
//******** REMVOVED THIS SECTION IF TESLA CODE NOT WANTED ********
//****************************************************************
		if (Storage.getValue("Tesla") == null || gTeslaComplication == true) {
			/*DEBUG*/ logMessage("returning because Storage.getValue(\"Tesla\") is " + Storage.getValue("Tesla") + " or gTeslaComplication is " + gTeslaComplication);
			return;
		}

		// Get the unexpired token from the buffer if we have one, otherwise from Properties/Storage
		var teslaInfo = _bg_data.get("TeslaInfo");
		if (teslaInfo != null) {
			_token = teslaInfo.get("AccessToken");
			_vehicle_id = teslaInfo.get("VehicleID");
		}

		if (_vehicle_id == null) {
			_vehicle_id = Storage.getValue("TeslaVehicleID");
		}

		if (_token == null) {
			_token = $.getStringProperty("TeslaAccessToken", null);
		}

		if (_token != null && _token.length() == 0) {
			_token = null;
		}

//****************************************************************
//******************** END OF REMVOVED SECTION *******************
//****************************************************************
	}

	// Read pending web requests, and call appropriate web request function.
	// This function determines priority of web requests, if multiple are pending.
	// Pending web request flag will be cleared only once the background data has been successfully received.
	(:background)
	function onTemporalEvent() {
		_pendingWebRequests = Storage.getValue("PendingWebRequests");

		/*DEBUG*/ logMessage("onTemporalEvent:_pendingWebRequests is '" + _pendingWebRequests + "'");
		/*DEBUG*/ var keys = _bg_data.keys(); logMessage("onTemporalEvent:_bg_data has '" + keys);
		/*DEBUG*/ if (_token != null) { logMessage("onTemporalEvent:Using token '" + _token.substring(0,20) + "...'"); } else { logMessage("onTemporalEvent:No token");}

		if (_pendingWebRequests != null) {
			if (_pendingWebRequests["OpenWeatherMapCurrent"] != null) {
				var owmKeyOverride = $.getStringProperty("OWMKeyOverride","");
				var lat = $.getStringProperty("LastLocationLat","");
				var lon = $.getStringProperty("LastLocationLng","");
				/*DEBUG*/ logMessage("onTemporalEvent:OWM with overide=" + owmKeyOverride + " lat=" + lat + " lon=" + lon);

				if (lat.length() > 0 && lon.length() > 0) {
					makeWebRequest(
						"https://api.openweathermap.org/data/2.5/weather",
//						"https://api.openweathermap.org/data/3.0/onecall",
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
//****************************************************************
//******** REMVOVED THIS SECTION IF TESLA CODE NOT WANTED ********
//****************************************************************
				else {
					doTesla();
				}
			}
			else {
				doTesla();
			}
//****************************************************************
//******************** END OF REMVOVED SECTION *******************
//****************************************************************
		}
		else {
			/*DEBUG*/ logMessage("onTemporalEvent() called with no pending web requests!");
		}
	}

	(:background)
	function onReceiveOpenWeatherMapCurrent(responseCode, data)
	{
		var result;
		
		/*DEBUG*/ logMessage("onReceiveOpenWeatherMapCurrent responseCode: " + responseCode);
		//DEBUG*/ logMessage("onReceiveOpenWeatherMapCurrent data: " + data);

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
				"icon" => data["weather"][0]["icon"],
				"name" => data["name"]
			};

		// HTTP error: do not save.
		}
		else {
			result = Storage.getValue("OpenWeatherMapCurrent");
			if (result) {
				result["cod"] = responseCode;
			} else {
				result = {
					"httpError" => responseCode
				};
			}
		}

		_bg_data.put("OpenWeatherMapCurrent", result);

		/*DEBUG*/ logMessage("onReceiveOpenWeatherMapCurrent: result=" + result);
//****************************************************************
//******** REMVOVED THIS SECTION IF TESLA CODE NOT WANTED ********
//****************************************************************
		doTesla(); // Call back so we get the next steps done right now
//****************************************************************
//********               DO THIS INSTEAD                  ********
//****************************************************************
		// try {
		// 	/*DEBUG*/ logMessage("onReceiveVehicles: Exiting with " + _bg_data);
		// 	Bg.exit(_bg_data);
		// }
		// catch (e) {
		// 	/*DEBUG*/ logMessage("onReceiveVehicles exit assertion " + e);
		// }

	}

//****************************************************************
//******** REMVOVED THIS SECTION IF TESLA CODE NOT WANTED ********
//****************************************************************
	(:background)
	function doTesla()
	{
		if (_pendingWebRequests["TeslaInfo"] != null && Storage.getValue("Tesla") != null) {
			if (_token == null) {
				/*DEBUG*/ logMessage("doTesla:Generating Access Token");
				var refreshToken = $.getStringProperty("TeslaRefreshToken","");
				if (refreshToken != null && refreshToken.length() > 0) {
					/*DEBUG*/ logMessage("doTesla:Get new Access token with Refresh token at '" + refreshToken.substring(0, 20) + "'...");
					makeTeslaWebPost(refreshToken, method(:onReceiveToken));
					return;
				} else {
					/*DEBUG*/ logMessage("doTesla:No refresh token!");
					_bg_data.put("TeslaInfo", { "httpErrorTesla" => 401, "httpInternalErrorTesla" => 401 } );
					//DEBUG*/ _bg_data.put({ "TeslaInfo" => { "httpErrorTesla" => 200, "httpInternalErrorTesla" => 200, "BatteryLevel" => 70, "ChargingState" => "Charging", "InsideTemp" => 21, "PrecondEnabled" => false, "SentryEnabled" => false, "VehicleID" => "12345678" , "VehicleState" => "online"} });
				}
			}
			else if (_vehicle_id == null) {
				/*DEBUG*/ logMessage("doTesla:Getting vehicles");
				makeTeslaWebRequest("https://" + $.getStringProperty("TeslaServerAPILocation","") + "/api/1/products?orders=true", Comms.HTTP_RESPONSE_CONTENT_TYPE_JSON, method(:onReceiveVehicles));
				return;
			}
			else {
				//DEBUG*/ logMessage("doTesla: Getting vehicle data");
				makeTeslaWebRequest("https://" + $.getStringProperty("TeslaServerAPILocation","") + "/api/1/vehicles/" + _vehicle_id + "/vehicle_data", Comms.HTTP_RESPONSE_CONTENT_TYPE_TEXT_PLAIN, method(:onReceiveVehicleData));
				return;
			}
		}

		try {
			/*DEBUG*/ logMessage("doTesla: Exiting with " + _bg_data);
			Bg.exit(_bg_data);
		}
		catch (e) {
			/*DEBUG*/ logMessage("doTesla exit assertion " + e);
		}
	}
//****************************************************************
//******************** END OF REMVOVED SECTION *******************
//****************************************************************

	(:background)
    function onReceiveToken(responseCode, responseData) {
		/*DEBUG*/ logMessage("onReceiveToken: " + responseCode);

		if (_bg_data == null) {
			_bg_data = Bg.getBackgroundData();
			if (_bg_data == null) {
				_bg_data = {};
			}
		}
		else {
			/*DEBUG*/ var keys = _bg_data.keys(); logMessage("onReceiveToken: _bg_data has keys " + keys);
		}

		var teslaInfo = _bg_data.get("TeslaInfo");
		if (teslaInfo == null) {
			teslaInfo = {};
		}

        if (responseCode == 200) {
			_token = responseData["access_token"];
			/*DEBUG*/ logMessage("onReceiveToken:Has token '" + _token.substring(0,20) + "...', calling back doTesla");
			teslaInfo.put("AccessToken", _token);
			teslaInfo.put("RefreshToken", responseData["refresh_token"]);
			teslaInfo.put("TokenExpiresIn", responseData["expires_in"]);
			teslaInfo.put("TokenCreatedAt", Time.now().value());

			_bg_data.put("TeslaInfo", teslaInfo);
			doTesla();
        }
		else {
			_bg_data.put("TeslaInfo", { "httpErrorTesla" => 401, "httpInternalErrorTesla" => responseCode } );
			try {
				/*DEBUG*/ logMessage("onReceiveVehicles: Exiting with " + _bg_data);
				Bg.exit(_bg_data);
			}
			catch (e) {
				/*DEBUG*/ logMessage("onReceiveVehicles exit assertion " + e);
			}
		}
    }

	(:background)
    function onReceiveVehicles(responseCode, responseData) {
		/*DEBUG*/ logMessage("onReceiveVehicles: " + responseCode);

		if (_bg_data == null) {
			_bg_data = Bg.getBackgroundData();
			if (_bg_data == null) {
				_bg_data = {};
			}
		}
		else {
			/*DEBUG*/ var keys = _bg_data.keys(); logMessage("onReceiveVehicles: _bg_data has keys " + keys);
		}

		var teslaInfo = _bg_data.get("TeslaInfo");
		if (teslaInfo == null) {
			teslaInfo = {};
		}

        if (responseCode == 200) {
            var vehicles = responseData.get("response");
			var vehice_state;
			if (vehicles != null) {
				var storVehicleIndex = Storage.getValue("TeslaVehicleIndex");
				if (storVehicleIndex == null || storVehicleIndex < 1) {
					storVehicleIndex = 0; // Base 0 so 0, not 1
				}
				else {
					storVehicleIndex--; // Array are zero based but we want user to start numbering from 1 for ease of use
				}
				if (vehicles.size() > 0) {
					if (vehicles.size() > storVehicleIndex) {
						_vehicle_id =  vehicles[storVehicleIndex].get("id").toString();
						vehice_state = vehicles[storVehicleIndex].get("state");
					}
					else {
						_vehicle_id = null;
						vehice_state = "VehicleNotFound";
					}
				}
				else {
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

			_bg_data.put("TeslaInfo", teslaInfo);

			/*DEBUG*/ logMessage("onReceiveVehicles:vehice_state=" + vehice_state);

			if (_vehicle_id != null) {
				doTesla();
				return;
			}
        }

		_bg_data.put("TeslaInfo", { "httpErrorTesla" => (_vehicle_id == null ? 404 : 408), "httpInternalErrorTesla" => responseCode } );

		try {
			/*DEBUG*/ logMessage("onReceiveVehicles: Exiting with " + _bg_data);
			Bg.exit(_bg_data);
		}
		catch (e) {
			/*DEBUG*/ logMessage("onReceiveVehicles exit assertion " + e);
		}
    }

	(:background)
    function onReceiveVehicleData(responseCode, responseData) {
		/*DEBUG*/ logMessage("onReceiveVehicleData: " + responseCode);
        /*DEBUG*/ var myStats = Sys.getSystemStats(); logMessage("Total memory: " + myStats.totalMemory + " Used memory: " + myStats.usedMemory + " Free memory: " + myStats.freeMemory);

		if (_bg_data == null) {
			_bg_data = Bg.getBackgroundData();
			if (_bg_data == null) {
				_bg_data = {};
			}
			else {
				/*DEBUG*/ var keys = _bg_data.keys(); logMessage("onReceiveVehicleData: _bg_data has keys " + keys);
			}
		}

		var teslaInfo = _bg_data.get("TeslaInfo");
		if (teslaInfo == null) {
			teslaInfo = {};
		}

		teslaInfo.put("httpErrorTesla", responseCode);

        if (responseCode == 200) {
			teslaInfo.remove("httpInternalErrorTesla");
			teslaInfo.put("VehicleState", "online");

            var pos = responseData.find("battery_level");
            var str = responseData.substring(pos + 15, pos + 20);
            var posEnd = str.find(",");
            teslaInfo.put("BatteryLevel", $.validateNumber(str.substring(0, posEnd), 0));

            pos = responseData.find("charging_state");
            str = responseData.substring(pos + 17, pos + 37);
            posEnd = str.find("\"");
            teslaInfo.put("ChargingState", $.validateString(str.substring(0, posEnd), ""));

            pos = responseData.find("inside_temp");
            str = responseData.substring(pos + 13, pos + 20);
            posEnd = str.find(",");
            teslaInfo.put("InsideTemp", $.validateNumber(str.substring(0, posEnd), 0));

            pos = responseData.find("sentry_mode");
            str = responseData.substring(pos + 13, pos + 20);
            posEnd = str.find(",");
            teslaInfo.put("SentryEnabled", $.validateString(str.substring(0, posEnd), "").equals("true"));

            pos = responseData.find("preconditioning_enabled");
            str = responseData.substring(pos + 25, pos + 32);
            posEnd = str.find(",");
            teslaInfo.put("PrecondEnabled", $.validateString(str.substring(0, posEnd), "").equals("true"));

			_bg_data.put("TeslaInfo", teslaInfo);
	    }
		// If no vehicle (rare) or can't contact (much more frequent) is received, try to get a new vehicle (404) or retrieve its state (408)
		else if (responseCode == 404 || responseCode == 408) {
			// If Tesla can't find our vehicle by its ID, reset it and maybe we'll have better luck next time
			if (responseCode == 404) {
				_vehicle_id = null;
				_bg_data.put("TeslaInfo", { "httpErrorTesla" => 404, "httpInternalErrorTesla" => responseCode, "VehicleID" => null } );
			}
			/*DEBUG*/ logMessage("Requesting vehicles from onReceiveVehicleData with _stop at " + _stop);
			if (_stop == false) { // We we're true, we already came back here for the next lines so don't get into an infinite loop
				_stop = true; // Don't get vehicle_data anymore if we fail again
				makeTeslaWebRequest("https://" + $.getStringProperty("TeslaServerAPILocation","") + "/api/1/products?orders=true", Comms.HTTP_RESPONSE_CONTENT_TYPE_JSON, method(:onReceiveVehicles));
				return;
			}
	    }
		// Our access token has expired, ask for a new one
		else if (responseCode == 401) {
			var refreshToken = $.getStringProperty("TeslaRefreshToken","");
			if (refreshToken != null) {
				/*DEBUG*/ logMessage("Requesting access token from onReceiveVehicleData with _stop at " + _stop);
				if (_stop == false) { // We we're true, we already came back here for the next lines so don't get into an infinite loop
					_stop = true; // Don't get vehicle_data anymore if we fail again
					makeTeslaWebPost(refreshToken, method(:onReceiveToken));
					return;
				}
				else {
					_bg_data.put("TeslaInfo", { "httpErrorTesla" => 401, "httpInternalErrorTesla" => responseCode } );
				}
			}
		}

		_bg_data.put("TeslaInfo", teslaInfo);

		try {
			/*DEBUG*/ logMessage("onReceiveVehicleData: Exiting with " + _bg_data);
			Bg.exit(_bg_data);
		}
		catch (e) {
			/*DEBUG*/ logMessage("onReceiveVehicleData exit assertion " + e);
		}
    }

	(:background)
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

	(:background)
    function makeTeslaWebRequest(url, method, callback) {
		var options = {
            :method => Comms.HTTP_REQUEST_METHOD_GET,
            :headers => {
              		"Authorization" => "Bearer " + _token,
					"User-Agent" => "Crystal-Tesla for Garmin",
					},
            :responseType => method
        };
		//DEBUG*/ logMessage("makeWebRequest url: '" + url + "'");
		//DEBUG*/ logMessage("makeWebRequest options: '" + options + "'");
		Comms.makeWebRequest(url, null, options, callback);
    }
//****************************************************************
//******************** END OF REMVOVED SECTION *******************
//****************************************************************

	(:background)
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
