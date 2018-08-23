using Toybox.Background as Bg;
using Toybox.System as Sys;

(:background)
class BackgroundService extends Sys.ServiceDelegate {
	
	function initialize() {
		Sys.ServiceDelegate.initialize();
	}

	function onTemporalEvent() {
		Sys.println("onTemporalEvent");
		Bg.exit(42);
	}
}
