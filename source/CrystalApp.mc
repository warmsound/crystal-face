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

		// Register for background temporal event as soon as possible.
		if (Sys has :ServiceDelegate) {
			var lastTime = Bg.getLastTemporalEventTime();
			if (lastTime != null) {
				// Events scheduled for a time in the past trigger immediately.
				var nextTime = lastTime.add(new Time.Duration(5 * 60));
				Bg.registerForTemporalEvent(nextTime);
			} else {
				Bg.registerForTemporalEvent(Time.now());
			}
		}

		return [mView];
	}

	function getView() {
		return mView;
	}

	// New app settings have been received so trigger a UI update
	function onSettingsChanged() {
		mView.onSettingsChanged();

		Ui.requestUpdate();
	}

	function getServiceDelegate() {
		return [new BackgroundService()];
	}

	function onBackgroundData(data) {
		Sys.println(data);
	}
}
