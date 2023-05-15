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

		if (Storage.getValue("Tesla") == null || gTeslaComplication == true) {
			return;
		}

		var teslaInfo = Bg.getBackgroundData();
		if (teslaInfo == null) {
			teslaInfo = {};
		}		
		else {
			/*DEDUG*/ var keys = teslaInfo.keys(); logMessage("onReceiveVehicleData: Buffer has keys " + keys);
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
			//DEBUG*/ var expireAt = new Time.Moment(createdAt + expiresIn); var clockTime = Gregorian.info(expireAt, Time.FORMAT_MEDIUM); var dateStr = clockTime.hour + ":" + clockTime.min.format("%02d") + ":" + clockTime.sec.format("%02d"); logMessage("initialize:Using token '" + _token.substring(0,10) + "...' which expires at " + dateStr);
			_token = "Bearer " + _token;
		}
		else {
			_token = null;
		}

		_vehicle_id = teslaInfo.get("VehicleID");
		if (_vehicle_id == null) {
			_vehicle_id = Storage.getValue("TeslaVehicleID");
		}

	}

	(:background_method)
	function onTemporalEvent() {
		if (!Sys.getDeviceSettings().phoneConnected) {
			Bg.exit(null);
		}

		if (_token == null) {					
			//DEBUG*/ logMessage("onTemporalEvent:Generating Access Token");
			var refreshToken = $.getStringProperty("TeslaRefreshToken","");
			if (refreshToken != null) {
				makeWebPost(refreshToken, method(:onReceiveToken));
			} else {
				//DEBUG*/ logMessage("onTemporalEvent:No refresh token!");
				Bg.exit({ "TeslaInfo" => { "httpErrorTesla" => 401, "httpInternalErrorTesla" => 401 } });
			}
			return;
		}

		if (_vehicle_id == null) {
			//DEBUG*/ logMessage("onTemporalEvent:Getting vehicles");
			makeWebRequest("https://" + $.getStringProperty("TeslaServerAPILocation","") + "/api/1/vehicles", null, method(:onReceiveVehicles));
			return;
		}

		//DEBUG*/ logMessage("onTemporalEvent: Getting vehicle data");
		makeWebRequest("https://" + $.getStringProperty("TeslaServerAPILocation","") + "/api/1/vehicles/" + _vehicle_id + "/vehicle_data", null, method(:onReceiveVehicleData));
	}

	(:background_method)
    function onReceiveToken(responseCode, responseData) {
		//DEBUG*/ logMessage("onReceiveToken: " + responseCode);

		var teslaInfo = Bg.getBackgroundData();
		if (teslaInfo == null) {
			teslaInfo = {};
		}		
		else {
			/*DEDUG*/ var keys = teslaInfo.keys(); logMessage("onReceiveToken: Buffer has keys " + keys);
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
		//DEBUG*/ logMessage("onReceiveVehicles: " + responseCode);

		var teslaInfo = Bg.getBackgroundData();
		if (teslaInfo == null) {
			teslaInfo = {};
		}		
		else {
			/*DEDUG*/ var keys = teslaInfo.keys(); logMessage("onReceiveVehicles: Buffer has keys " + keys);
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
		//DEBUG*/ logMessage("onReceiveVehicleData: " + responseCode);
        //DEBUG*/ var myStats = Sys.getSystemStats(); logMessage("Total memory: " + myStats.totalMemory + " Used memory: " + myStats.usedMemory + " Free memory: " + myStats.freeMemory);

		var teslaInfo = Bg.getBackgroundData();
		if (teslaInfo == null) {
			teslaInfo = {};
		}		
		else {
			/*DEDUG*/ var keys = teslaInfo.keys(); logMessage("onReceiveVehicleData: Buffer has keys " + keys);
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
			//DEBUG*/ logMessage("Requesting vehicles from onReceiveVehicleData");
			makeWebRequest("https://" + $.getStringProperty("TeslaServerAPILocation","") + "/api/1/vehicles", null, method(:onReceiveVehicles));
			return;
	    }
		// Our access token has expired, ask for a new one
		else if (responseCode == 401) {
			var refreshToken = $.getStringProperty("TeslaRefreshToken","");
			if (refreshToken != null) {
				//DEBUG*/ logMessage("Requesting access token from onReceiveVehicleData");
				makeWebPost(refreshToken, method(:onReceiveToken));
				return;
			}
		}

		Bg.exit({ "TeslaInfo" => teslaInfo });
    }

	(:background_method)
    function makeWebPost(token, notify) {
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
    function makeWebRequest(url, params, callback) {
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
}
