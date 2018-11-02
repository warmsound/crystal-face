using Toybox.Application as App;
using Toybox.Background as Bg;
using Toybox.System as Sys;
using Toybox.WatchUi as Ui;

(:background)
class CrystalApp extends App.AppBase {

	var mView;

	function initialize() {
		AppBase.initialize();		
	}

	// onStart() is called on application start up
	function onStart(state) {
	}

	// onStop() is called when your application is exiting
	function onStop(state) {
	}

	// Return the initial view of your application here
	function getInitialView() {
		mView = new CrystalView();
		return [mView];
	}

	function getView() {
		return mView;
	}

	// New app settings have been received so trigger a UI update
	function onSettingsChanged() {
		mView.onSettingsChanged();
		checkPendingWebRequests();
		Ui.requestUpdate();
	}

	// Determine if any web requests are needed.
	// If so, set approrpiate pendingWebRequests flag for use by BackgroundService, then register for
	// temporal event.
	// Currently called on initialisation, when settings change, and on exiting sleep.
	function checkPendingWebRequests() {

		// Attempt to updated stored location, to be used by Sunrise/Sunset, and Weather.
		var lat, lng;
		var location = Activity.getActivityInfo().currentLocation;
		if (location) {
			location = location.toDegrees(); // Array of Doubles.
			lat = location[0].toFloat();
			lng = location[1].toFloat();

			// Save current location, in case it goes "stale" and can not longer be retrieved from current activity.
			App.getApp().setProperty("LastLocationLat", lat);
			App.getApp().setProperty("LastLocationLng", lng);
		} else {
			lat = App.getApp().getProperty("LastLocationLat");
			lng = App.getApp().getProperty("LastLocationLng");
		}

		if (!((Sys has :ServiceDelegate) && (App has :Storage))) {
			return;
		}

		var pendingWebRequests = App.Storage.getValue("PendingWebRequests");
		if (pendingWebRequests == null) {
			pendingWebRequests = {};
		}

		// 1. City local time:
		// City has been specified.
		var city = App.getApp().getProperty("LocalTimeInCity");
		
		// #78 Setting with value of empty string may cause corresponding property to be null.
		if ((city != null) && (city.length() > 0)) {

			var cityLocalTime = App.Storage.getValue("CityLocalTime");

			// No existing data.
			if ((cityLocalTime == null) ||

			// Existing data is old.
			((cityLocalTime["next"] != null) && (Time.now().value() >= cityLocalTime["next"]["when"]))) {

				pendingWebRequests["CityLocalTime"] = true;
		
			// Existing data not for this city: delete it.
			// Error response from server: contains requestCity. Likely due to unrecognised city. Prevent requesting this
			// city again.
			} else if (!cityLocalTime["requestCity"].equals(city)) {

				App.Storage.deleteValue("CityLocalTime");
				pendingWebRequests["CityLocalTime"] = true;
			}
		}

		// 2. Weather:
		// Location must be available.
		if (lat != -360) {

			// Weather data field must be shown.
			if (mView.mDataFields.hasField(FIELD_TYPE_WEATHER)) {

				var owmCurrent = App.Storage.getValue("OpenWeatherMapCurrent");

				// No existing data.
				if (owmCurrent == null) {

					pendingWebRequests["OpenWeatherMapCurrent"] = true;

				// Successfully received weather data.
				} else if (owmCurrent["cod"] == 200) {

					// Existing data is older than an hour.
					if ((Time.now().value() > (owmCurrent["dt"] + 3600)) ||

					// Existing data not for this location.
					// Not a great test, as a degree of longitude varies betwee 69 (equator) and 0 (pole) miles, but simpler than
					// true distance calculation. 0.02 degree of latitude is just over a mile.
					(((lat - owmCurrent["coord"]["lat"]).abs() > 0.02) || ((lng - owmCurrent["coord"]["lon"]).abs() > 0.02))) {

						pendingWebRequests["OpenWeatherMapCurrent"] = true;
					}
				}
				// TODO: Else if "invalid API key" response, and user has since changed key.
				// TODO: Should we ever delete weather data?
			}
		}

		// If there are any pending requests:
		if (pendingWebRequests.keys().size() > 0) {

			// Register for background temporal event as soon as possible.
			var lastTime = Bg.getLastTemporalEventTime();
			if (lastTime) {
				// Events scheduled for a time in the past trigger immediately.
				var nextTime = lastTime.add(new Time.Duration(5 * 60));
				Bg.registerForTemporalEvent(nextTime);
			} else {
				Bg.registerForTemporalEvent(Time.now());
			}
		}

		App.Storage.setValue("PendingWebRequests", pendingWebRequests);
	}

	function getServiceDelegate() {
		return [new BackgroundService()];
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

	// Sample HTTP error:
	/*
	{
	"httpError":404
	}
	*/

	// Handle data received from BackgroundService.
	// On success, clear appropriate pendingWebRequests flag.
	// data is Dictionary with single key that indicates the data type received. This corresponds with App.Storage and
	// pendingWebRequests keys.
	function onBackgroundData(data) {
		var pendingWebRequests = App.Storage.getValue("PendingWebRequests");
		if (pendingWebRequests == null) {
			//Sys.println("onBackgroundData() called with no pending web requests!");
			pendingWebRequests = {};
		}

		var type = data.keys()[0]; // Type of received data.
		var storedData = App.Storage.getValue(type);
		var receivedData = data[type]; // The actual data received: strip away type key.
		
		// No value in showing any HTTP error to the user, so no need to modify stored data.
		// Leave pendingWebRequests flag set, and simply return early.
		if (receivedData["httpError"]) {
			return;
		}

		// New data received: overwrite stored data and clear pendingWebRequests flag.
		storedData = receivedData;
		pendingWebRequests.remove(type);
		App.Storage.setValue("PendingWebRequests", pendingWebRequests);
		App.Storage.setValue(type, storedData);
		Ui.requestUpdate();
	}
}

	// Sample incorrect API key:
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

	// Sample forecast:
	/*
	{
		"cod":"200",
		"message":0.004,
		"cnt":40,
		"list":[
			{
				"dt":1540749600,
				"main":{
					"temp":278.26,
					"temp_min":278.134,
					"temp_max":278.26,
					"pressure":1021.99,
					"sea_level":1032.16,
					"grnd_level":1021.99,
					"humidity":75,
					"temp_kf":0.13
				},
				"weather":[
					{
						"id":800,
						"main":"Clear",
						"description":"clear sky",
						"icon":"01n"
					}
				],
				"clouds":{
					"all":0
				},
				"wind":{
					"speed":5.66,
					"deg":23.5008
				},
				"rain":{

				},
				"sys":{
					"pod":"n"
				},
				"dt_txt":"2018-10-28 18:00:00"
			},
			{
				"dt":1540760400,
				"main":{
					"temp":276.19,
					"temp_min":276.096,
					"temp_max":276.19,
					"pressure":1020.86,
					"sea_level":1031.06,
					"grnd_level":1020.86,
					"humidity":82,
					"temp_kf":0.1
				},
				"weather":[
					{
						"id":800,
						"main":"Clear",
						"description":"clear sky",
						"icon":"01n"
					}
				],
				"clouds":{
					"all":0
				},
				"wind":{
					"speed":5.01,
					"deg":17.5015
				},
				"rain":{

				},
				"sys":{
					"pod":"n"
				},
				"dt_txt":"2018-10-28 21:00:00"
			},
			{
				"dt":1540771200,
				"main":{
					"temp":274.45,
					"temp_min":274.384,
					"temp_max":274.45,
					"pressure":1019.39,
					"sea_level":1029.73,
					"grnd_level":1019.39,
					"humidity":85,
					"temp_kf":0.07
				},
				"weather":[
					{
						"id":800,
						"main":"Clear",
						"description":"clear sky",
						"icon":"01n"
					}
				],
				"clouds":{
					"all":0
				},
				"wind":{
					"speed":4.61,
					"deg":22.0009
				},
				"rain":{

				},
				"sys":{
					"pod":"n"
				},
				"dt_txt":"2018-10-29 00:00:00"
			},
			{
				"dt":1540782000,
				"main":{
					"temp":273.98,
					"temp_min":273.949,
					"temp_max":273.98,
					"pressure":1017.37,
					"sea_level":1027.72,
					"grnd_level":1017.37,
					"humidity":93,
					"temp_kf":0.03
				},
				"weather":[
					{
						"id":500,
						"main":"Rain",
						"description":"light rain",
						"icon":"10n"
					}
				],
				"clouds":{
					"all":56
				},
				"wind":{
					"speed":4.12,
					"deg":18.5054
				},
				"rain":{
					"3h":0.235
				},
				"sys":{
					"pod":"n"
				},
				"dt_txt":"2018-10-29 03:00:00"
			},
			{
				"dt":1540792800,
				"main":{
					"temp":273.926,
					"temp_min":273.926,
					"temp_max":273.926,
					"pressure":1015.56,
					"sea_level":1025.83,
					"grnd_level":1015.56,
					"humidity":93,
					"temp_kf":0
				},
				"weather":[
					{
						"id":500,
						"main":"Rain",
						"description":"light rain",
						"icon":"10n"
					}
				],
				"clouds":{
					"all":0
				},
				"wind":{
					"speed":3.9,
					"deg":18.5052
				},
				"rain":{
					"3h":0.04
				},
				"sys":{
					"pod":"n"
				},
				"dt_txt":"2018-10-29 06:00:00"
			},
			{
				"dt":1540803600,
				"main":{
					"temp":276.001,
					"temp_min":276.001,
					"temp_max":276.001,
					"pressure":1014.04,
					"sea_level":1024.19,
					"grnd_level":1014.04,
					"humidity":86,
					"temp_kf":0
				},
				"weather":[
					{
						"id":800,
						"main":"Clear",
						"description":"clear sky",
						"icon":"01d"
					}
				],
				"clouds":{
					"all":0
				},
				"wind":{
					"speed":3.51,
					"deg":21.5021
				},
				"rain":{

				},
				"sys":{
					"pod":"d"
				},
				"dt_txt":"2018-10-29 09:00:00"
			},
			{
				"dt":1540814400,
				"main":{
					"temp":280.794,
					"temp_min":280.794,
					"temp_max":280.794,
					"pressure":1010.95,
					"sea_level":1020.91,
					"grnd_level":1010.95,
					"humidity":83,
					"temp_kf":0
				},
				"weather":[
					{
						"id":800,
						"main":"Clear",
						"description":"clear sky",
						"icon":"01d"
					}
				],
				"clouds":{
					"all":0
				},
				"wind":{
					"speed":4.12,
					"deg":19.0021
				},
				"rain":{

				},
				"sys":{
					"pod":"d"
				},
				"dt_txt":"2018-10-29 12:00:00"
			},
			{
				"dt":1540825200,
				"main":{
					"temp":281.121,
					"temp_min":281.121,
					"temp_max":281.121,
					"pressure":1007.65,
					"sea_level":1017.59,
					"grnd_level":1007.65,
					"humidity":72,
					"temp_kf":0
				},
				"weather":[
					{
						"id":800,
						"main":"Clear",
						"description":"clear sky",
						"icon":"01d"
					}
				],
				"clouds":{
					"all":0
				},
				"wind":{
					"speed":5.26,
					"deg":28.5029
				},
				"rain":{

				},
				"sys":{
					"pod":"d"
				},
				"dt_txt":"2018-10-29 15:00:00"
			},
			{
				"dt":1540836000,
				"main":{
					"temp":277.433,
					"temp_min":277.433,
					"temp_max":277.433,
					"pressure":1005.87,
					"sea_level":1015.95,
					"grnd_level":1005.87,
					"humidity":77,
					"temp_kf":0
				},
				"weather":[
					{
						"id":800,
						"main":"Clear",
						"description":"clear sky",
						"icon":"01n"
					}
				],
				"clouds":{
					"all":0
				},
				"wind":{
					"speed":4.21,
					"deg":20.5012
				},
				"rain":{

				},
				"sys":{
					"pod":"n"
				},
				"dt_txt":"2018-10-29 18:00:00"
			},
			{
				"dt":1540846800,
				"main":{
					"temp":274.719,
					"temp_min":274.719,
					"temp_max":274.719,
					"pressure":1003.34,
					"sea_level":1013.58,
					"grnd_level":1003.34,
					"humidity":91,
					"temp_kf":0
				},
				"weather":[
					{
						"id":800,
						"main":"Clear",
						"description":"clear sky",
						"icon":"01n"
					}
				],
				"clouds":{
					"all":0
				},
				"wind":{
					"speed":4.36,
					"deg":355.001
				},
				"rain":{

				},
				"sys":{
					"pod":"n"
				},
				"dt_txt":"2018-10-29 21:00:00"
			},
			{
				"dt":1540857600,
				"main":{
					"temp":274.296,
					"temp_min":274.296,
					"temp_max":274.296,
					"pressure":1001.35,
					"sea_level":1011.49,
					"grnd_level":1001.35,
					"humidity":89,
					"temp_kf":0
				},
				"weather":[
					{
						"id":500,
						"main":"Rain",
						"description":"light rain",
						"icon":"10n"
					}
				],
				"clouds":{
					"all":64
				},
				"wind":{
					"speed":4.87,
					"deg":353.003
				},
				"rain":{
					"3h":0.01
				},
				"sys":{
					"pod":"n"
				},
				"dt_txt":"2018-10-30 00:00:00"
			},
			{
				"dt":1540868400,
				"main":{
					"temp":274.859,
					"temp_min":274.859,
					"temp_max":274.859,
					"pressure":997.93,
					"sea_level":1008.1,
					"grnd_level":997.93,
					"humidity":90,
					"temp_kf":0
				},
				"weather":[
					{
						"id":500,
						"main":"Rain",
						"description":"light rain",
						"icon":"10n"
					}
				],
				"clouds":{
					"all":44
				},
				"wind":{
					"speed":5.25,
					"deg":329.002
				},
				"rain":{
					"3h":0.04
				},
				"sys":{
					"pod":"n"
				},
				"dt_txt":"2018-10-30 03:00:00"
			},
			{
				"dt":1540879200,
				"main":{
					"temp":275.767,
					"temp_min":275.767,
					"temp_max":275.767,
					"pressure":996.06,
					"sea_level":1006.02,
					"grnd_level":996.06,
					"humidity":95,
					"temp_kf":0
				},
				"weather":[
					{
						"id":500,
						"main":"Rain",
						"description":"light rain",
						"icon":"10n"
					}
				],
				"clouds":{
					"all":88
				},
				"wind":{
					"speed":5.36,
					"deg":313.002
				},
				"rain":{
					"3h":0.21
				},
				"sys":{
					"pod":"n"
				},
				"dt_txt":"2018-10-30 06:00:00"
			},
			{
				"dt":1540890000,
				"main":{
					"temp":276.819,
					"temp_min":276.819,
					"temp_max":276.819,
					"pressure":995.02,
					"sea_level":1005.02,
					"grnd_level":995.02,
					"humidity":94,
					"temp_kf":0
				},
				"weather":[
					{
						"id":500,
						"main":"Rain",
						"description":"light rain",
						"icon":"10d"
					}
				],
				"clouds":{
					"all":92
				},
				"wind":{
					"speed":5.38,
					"deg":295.501
				},
				"rain":{
					"3h":1.76
				},
				"sys":{
					"pod":"d"
				},
				"dt_txt":"2018-10-30 09:00:00"
			},
			{
				"dt":1540900800,
				"main":{
					"temp":280.189,
					"temp_min":280.189,
					"temp_max":280.189,
					"pressure":995.26,
					"sea_level":1005.21,
					"grnd_level":995.26,
					"humidity":93,
					"temp_kf":0
				},
				"weather":[
					{
						"id":500,
						"main":"Rain",
						"description":"light rain",
						"icon":"10d"
					}
				],
				"clouds":{
					"all":92
				},
				"wind":{
					"speed":3.93,
					"deg":285.001
				},
				"rain":{
					"3h":0.93
				},
				"sys":{
					"pod":"d"
				},
				"dt_txt":"2018-10-30 12:00:00"
			},
			{
				"dt":1540911600,
				"main":{
					"temp":281.005,
					"temp_min":281.005,
					"temp_max":281.005,
					"pressure":996.54,
					"sea_level":1006.45,
					"grnd_level":996.54,
					"humidity":96,
					"temp_kf":0
				},
				"weather":[
					{
						"id":500,
						"main":"Rain",
						"description":"light rain",
						"icon":"10d"
					}
				],
				"clouds":{
					"all":92
				},
				"wind":{
					"speed":4.46,
					"deg":282.501
				},
				"rain":{
					"3h":0.56
				},
				"sys":{
					"pod":"d"
				},
				"dt_txt":"2018-10-30 15:00:00"
			},
			{
				"dt":1540922400,
				"main":{
					"temp":279.992,
					"temp_min":279.992,
					"temp_max":279.992,
					"pressure":998.94,
					"sea_level":1008.95,
					"grnd_level":998.94,
					"humidity":96,
					"temp_kf":0
				},
				"weather":[
					{
						"id":500,
						"main":"Rain",
						"description":"light rain",
						"icon":"10n"
					}
				],
				"clouds":{
					"all":68
				},
				"wind":{
					"speed":3.71,
					"deg":274.501
				},
				"rain":{
					"3h":0.15
				},
				"sys":{
					"pod":"n"
				},
				"dt_txt":"2018-10-30 18:00:00"
			},
			{
				"dt":1540933200,
				"main":{
					"temp":278.908,
					"temp_min":278.908,
					"temp_max":278.908,
					"pressure":1001.68,
					"sea_level":1011.62,
					"grnd_level":1001.68,
					"humidity":97,
					"temp_kf":0
				},
				"weather":[
					{
						"id":500,
						"main":"Rain",
						"description":"light rain",
						"icon":"10n"
					}
				],
				"clouds":{
					"all":88
				},
				"wind":{
					"speed":3.76,
					"deg":242.001
				},
				"rain":{
					"3h":0.03
				},
				"sys":{
					"pod":"n"
				},
				"dt_txt":"2018-10-30 21:00:00"
			},
			{
				"dt":1540944000,
				"main":{
					"temp":277.839,
					"temp_min":277.839,
					"temp_max":277.839,
					"pressure":1003.57,
					"sea_level":1013.56,
					"grnd_level":1003.57,
					"humidity":94,
					"temp_kf":0
				},
				"weather":[
					{
						"id":500,
						"main":"Rain",
						"description":"light rain",
						"icon":"10n"
					}
				],
				"clouds":{
					"all":32
				},
				"wind":{
					"speed":2.41,
					"deg":198.003
				},
				"rain":{
					"3h":0.06
				},
				"sys":{
					"pod":"n"
				},
				"dt_txt":"2018-10-31 00:00:00"
			},
			{
				"dt":1540954800,
				"main":{
					"temp":274.11,
					"temp_min":274.11,
					"temp_max":274.11,
					"pressure":1003.48,
					"sea_level":1013.64,
					"grnd_level":1003.48,
					"humidity":88,
					"temp_kf":0
				},
				"weather":[
					{
						"id":803,
						"main":"Clouds",
						"description":"broken clouds",
						"icon":"04n"
					}
				],
				"clouds":{
					"all":64
				},
				"wind":{
					"speed":1.33,
					"deg":100.007
				},
				"rain":{

				},
				"sys":{
					"pod":"n"
				},
				"dt_txt":"2018-10-31 03:00:00"
			},
			{
				"dt":1540965600,
				"main":{
					"temp":277.311,
					"temp_min":277.311,
					"temp_max":277.311,
					"pressure":1003.08,
					"sea_level":1013.09,
					"grnd_level":1003.08,
					"humidity":93,
					"temp_kf":0
				},
				"weather":[
					{
						"id":500,
						"main":"Rain",
						"description":"light rain",
						"icon":"10n"
					}
				],
				"clouds":{
					"all":92
				},
				"wind":{
					"speed":4.41,
					"deg":113.501
				},
				"rain":{
					"3h":0.2
				},
				"sys":{
					"pod":"n"
				},
				"dt_txt":"2018-10-31 06:00:00"
			},
			{
				"dt":1540976400,
				"main":{
					"temp":281.199,
					"temp_min":281.199,
					"temp_max":281.199,
					"pressure":1003.19,
					"sea_level":1013.2,
					"grnd_level":1003.19,
					"humidity":95,
					"temp_kf":0
				},
				"weather":[
					{
						"id":500,
						"main":"Rain",
						"description":"light rain",
						"icon":"10d"
					}
				],
				"clouds":{
					"all":80
				},
				"wind":{
					"speed":5.51,
					"deg":138.502
				},
				"rain":{
					"3h":0.38
				},
				"sys":{
					"pod":"d"
				},
				"dt_txt":"2018-10-31 09:00:00"
			},
			{
				"dt":1540987200,
				"main":{
					"temp":283.859,
					"temp_min":283.859,
					"temp_max":283.859,
					"pressure":1002.77,
					"sea_level":1012.56,
					"grnd_level":1002.77,
					"humidity":93,
					"temp_kf":0
				},
				"weather":[
					{
						"id":803,
						"main":"Clouds",
						"description":"broken clouds",
						"icon":"04d"
					}
				],
				"clouds":{
					"all":76
				},
				"wind":{
					"speed":7.27,
					"deg":144.508
				},
				"rain":{

				},
				"sys":{
					"pod":"d"
				},
				"dt_txt":"2018-10-31 12:00:00"
			},
			{
				"dt":1540998000,
				"main":{
					"temp":284.73,
					"temp_min":284.73,
					"temp_max":284.73,
					"pressure":1001.43,
					"sea_level":1011.2,
					"grnd_level":1001.43,
					"humidity":84,
					"temp_kf":0
				},
				"weather":[
					{
						"id":500,
						"main":"Rain",
						"description":"light rain",
						"icon":"10d"
					}
				],
				"clouds":{
					"all":92
				},
				"wind":{
					"speed":8.21,
					"deg":155.502
				},
				"rain":{
					"3h":0.07
				},
				"sys":{
					"pod":"d"
				},
				"dt_txt":"2018-10-31 15:00:00"
			},
			{
				"dt":1541008800,
				"main":{
					"temp":285.14,
					"temp_min":285.14,
					"temp_max":285.14,
					"pressure":1000.85,
					"sea_level":1010.72,
					"grnd_level":1000.85,
					"humidity":86,
					"temp_kf":0
				},
				"weather":[
					{
						"id":500,
						"main":"Rain",
						"description":"light rain",
						"icon":"10n"
					}
				],
				"clouds":{
					"all":92
				},
				"wind":{
					"speed":9.96,
					"deg":173.501
				},
				"rain":{
					"3h":0.41
				},
				"sys":{
					"pod":"n"
				},
				"dt_txt":"2018-10-31 18:00:00"
			},
			{
				"dt":1541019600,
				"main":{
					"temp":284.62,
					"temp_min":284.62,
					"temp_max":284.62,
					"pressure":1003.25,
					"sea_level":1013.15,
					"grnd_level":1003.25,
					"humidity":88,
					"temp_kf":0
				},
				"weather":[
					{
						"id":500,
						"main":"Rain",
						"description":"light rain",
						"icon":"10n"
					}
				],
				"clouds":{
					"all":88
				},
				"wind":{
					"speed":6.91,
					"deg":217.002
				},
				"rain":{
					"3h":0.12
				},
				"sys":{
					"pod":"n"
				},
				"dt_txt":"2018-10-31 21:00:00"
			},
			{
				"dt":1541030400,
				"main":{
					"temp":279.587,
					"temp_min":279.587,
					"temp_max":279.587,
					"pressure":1006.72,
					"sea_level":1016.72,
					"grnd_level":1006.72,
					"humidity":85,
					"temp_kf":0
				},
				"weather":[
					{
						"id":801,
						"main":"Clouds",
						"description":"few clouds",
						"icon":"02n"
					}
				],
				"clouds":{
					"all":24
				},
				"wind":{
					"speed":5.27,
					"deg":265.501
				},
				"rain":{

				},
				"sys":{
					"pod":"n"
				},
				"dt_txt":"2018-11-01 00:00:00"
			},
			{
				"dt":1541041200,
				"main":{
					"temp":276.096,
					"temp_min":276.096,
					"temp_max":276.096,
					"pressure":1008.3,
					"sea_level":1018.36,
					"grnd_level":1008.3,
					"humidity":92,
					"temp_kf":0
				},
				"weather":[
					{
						"id":800,
						"main":"Clear",
						"description":"clear sky",
						"icon":"01n"
					}
				],
				"clouds":{
					"all":0
				},
				"wind":{
					"speed":2.91,
					"deg":264.5
				},
				"rain":{

				},
				"sys":{
					"pod":"n"
				},
				"dt_txt":"2018-11-01 03:00:00"
			},
			{
				"dt":1541052000,
				"main":{
					"temp":272.462,
					"temp_min":272.462,
					"temp_max":272.462,
					"pressure":1009.35,
					"sea_level":1019.57,
					"grnd_level":1009.35,
					"humidity":83,
					"temp_kf":0
				},
				"weather":[
					{
						"id":800,
						"main":"Clear",
						"description":"clear sky",
						"icon":"02n"
					}
				],
				"clouds":{
					"all":8
				},
				"wind":{
					"speed":1.65,
					"deg":181.505
				},
				"rain":{

				},
				"sys":{
					"pod":"n"
				},
				"dt_txt":"2018-11-01 06:00:00"
			},
			{
				"dt":1541062800,
				"main":{
					"temp":277.232,
					"temp_min":277.232,
					"temp_max":277.232,
					"pressure":1010.1,
					"sea_level":1020.25,
					"grnd_level":1010.1,
					"humidity":87,
					"temp_kf":0
				},
				"weather":[
					{
						"id":800,
						"main":"Clear",
						"description":"clear sky",
						"icon":"01d"
					}
				],
				"clouds":{
					"all":0
				},
				"wind":{
					"speed":2.14,
					"deg":139.007
				},
				"rain":{

				},
				"sys":{
					"pod":"d"
				},
				"dt_txt":"2018-11-01 09:00:00"
			},
			{
				"dt":1541073600,
				"main":{
					"temp":282.834,
					"temp_min":282.834,
					"temp_max":282.834,
					"pressure":1009.13,
					"sea_level":1019.11,
					"grnd_level":1009.13,
					"humidity":83,
					"temp_kf":0
				},
				"weather":[
					{
						"id":500,
						"main":"Rain",
						"description":"light rain",
						"icon":"10d"
					}
				],
				"clouds":{
					"all":76
				},
				"wind":{
					"speed":4.27,
					"deg":150.501
				},
				"rain":{
					"3h":0.03
				},
				"sys":{
					"pod":"d"
				},
				"dt_txt":"2018-11-01 12:00:00"
			},
			{
				"dt":1541084400,
				"main":{
					"temp":283.022,
					"temp_min":283.022,
					"temp_max":283.022,
					"pressure":1007.74,
					"sea_level":1017.57,
					"grnd_level":1007.74,
					"humidity":79,
					"temp_kf":0
				},
				"weather":[
					{
						"id":500,
						"main":"Rain",
						"description":"light rain",
						"icon":"10d"
					}
				],
				"clouds":{
					"all":92
				},
				"wind":{
					"speed":5.11,
					"deg":157.005
				},
				"rain":{
					"3h":0.15
				},
				"sys":{
					"pod":"d"
				},
				"dt_txt":"2018-11-01 15:00:00"
			},
			{
				"dt":1541095200,
				"main":{
					"temp":281.652,
					"temp_min":281.652,
					"temp_max":281.652,
					"pressure":1007.81,
					"sea_level":1017.82,
					"grnd_level":1007.81,
					"humidity":72,
					"temp_kf":0
				},
				"weather":[
					{
						"id":500,
						"main":"Rain",
						"description":"light rain",
						"icon":"10n"
					}
				],
				"clouds":{
					"all":88
				},
				"wind":{
					"speed":4.31,
					"deg":147.001
				},
				"rain":{
					"3h":0.12
				},
				"sys":{
					"pod":"n"
				},
				"dt_txt":"2018-11-01 18:00:00"
			},
			{
				"dt":1541106000,
				"main":{
					"temp":280.975,
					"temp_min":280.975,
					"temp_max":280.975,
					"pressure":1007.98,
					"sea_level":1017.93,
					"grnd_level":1007.98,
					"humidity":89,
					"temp_kf":0
				},
				"weather":[
					{
						"id":500,
						"main":"Rain",
						"description":"light rain",
						"icon":"10n"
					}
				],
				"clouds":{
					"all":92
				},
				"wind":{
					"speed":3.91,
					"deg":131.502
				},
				"rain":{
					"3h":0.46
				},
				"sys":{
					"pod":"n"
				},
				"dt_txt":"2018-11-01 21:00:00"
			},
			{
				"dt":1541116800,
				"main":{
					"temp":281.335,
					"temp_min":281.335,
					"temp_max":281.335,
					"pressure":1008.32,
					"sea_level":1018.3,
					"grnd_level":1008.32,
					"humidity":92,
					"temp_kf":0
				},
				"weather":[
					{
						"id":500,
						"main":"Rain",
						"description":"light rain",
						"icon":"10n"
					}
				],
				"clouds":{
					"all":88
				},
				"wind":{
					"speed":3.41,
					"deg":129
				},
				"rain":{
					"3h":0.34
				},
				"sys":{
					"pod":"n"
				},
				"dt_txt":"2018-11-02 00:00:00"
			},
			{
				"dt":1541127600,
				"main":{
					"temp":281.358,
					"temp_min":281.358,
					"temp_max":281.358,
					"pressure":1008.73,
					"sea_level":1018.74,
					"grnd_level":1008.73,
					"humidity":94,
					"temp_kf":0
				},
				"weather":[
					{
						"id":500,
						"main":"Rain",
						"description":"light rain",
						"icon":"10n"
					}
				],
				"clouds":{
					"all":88
				},
				"wind":{
					"speed":2.96,
					"deg":127.501
				},
				"rain":{
					"3h":0.04
				},
				"sys":{
					"pod":"n"
				},
				"dt_txt":"2018-11-02 03:00:00"
			},
			{
				"dt":1541138400,
				"main":{
					"temp":281.253,
					"temp_min":281.253,
					"temp_max":281.253,
					"pressure":1009.74,
					"sea_level":1019.74,
					"grnd_level":1009.74,
					"humidity":97,
					"temp_kf":0
				},
				"weather":[
					{
						"id":500,
						"main":"Rain",
						"description":"light rain",
						"icon":"10n"
					}
				],
				"clouds":{
					"all":76
				},
				"wind":{
					"speed":2.67,
					"deg":124.506
				},
				"rain":{
					"3h":0.16
				},
				"sys":{
					"pod":"n"
				},
				"dt_txt":"2018-11-02 06:00:00"
			},
			{
				"dt":1541149200,
				"main":{
					"temp":282.701,
					"temp_min":282.701,
					"temp_max":282.701,
					"pressure":1011.19,
					"sea_level":1021.2,
					"grnd_level":1011.19,
					"humidity":96,
					"temp_kf":0
				},
				"weather":[
					{
						"id":500,
						"main":"Rain",
						"description":"light rain",
						"icon":"10d"
					}
				],
				"clouds":{
					"all":80
				},
				"wind":{
					"speed":3.21,
					"deg":138.001
				},
				"rain":{
					"3h":0.06
				},
				"sys":{
					"pod":"d"
				},
				"dt_txt":"2018-11-02 09:00:00"
			},
			{
				"dt":1541160000,
				"main":{
					"temp":286.033,
					"temp_min":286.033,
					"temp_max":286.033,
					"pressure":1011.07,
					"sea_level":1020.84,
					"grnd_level":1011.07,
					"humidity":93,
					"temp_kf":0
				},
				"weather":[
					{
						"id":500,
						"main":"Rain",
						"description":"light rain",
						"icon":"10d"
					}
				],
				"clouds":{
					"all":48
				},
				"wind":{
					"speed":3.83,
					"deg":184.003
				},
				"rain":{
					"3h":0.0099999999999998
				},
				"sys":{
					"pod":"d"
				},
				"dt_txt":"2018-11-02 12:00:00"
			},
			{
				"dt":1541170800,
				"main":{
					"temp":286.284,
					"temp_min":286.284,
					"temp_max":286.284,
					"pressure":1010.16,
					"sea_level":1019.97,
					"grnd_level":1010.16,
					"humidity":81,
					"temp_kf":0
				},
				"weather":[
					{
						"id":500,
						"main":"Rain",
						"description":"light rain",
						"icon":"10d"
					}
				],
				"clouds":{
					"all":92
				},
				"wind":{
					"speed":6.05,
					"deg":201.506
				},
				"rain":{
					"3h":0.035
				},
				"sys":{
					"pod":"d"
				},
				"dt_txt":"2018-11-02 15:00:00"
			}
		],
		"city":{
			"id":2647138,
			"name":"Hemel Hempstead",
			"coord":{
				"lat":51.7537,
				"lon":-0.4752
			},
			"country":"GB",
			"population":85629
		}
	}
	*/
