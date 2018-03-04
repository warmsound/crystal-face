using Toybox.Application as App;
using Toybox.WatchUi as Ui;

class CrystalApp extends App.AppBase {

	private var mView;
	private var THEMES = {
		0 => :THEME_BLUE_DARK,
		1 => :THEME_PINK_DARK,
		2 => :THEME_MONO_LIGHT
	};

	function initialize() {
		AppBase.initialize();
		updateThemeColours();
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

	// New app settings have been received so trigger a UI update
	function onSettingsChanged() {
		// Themes: explicitly set *Colour properties that have no corresponding (user-facing) setting.
		updateThemeColours();

		mView.onSettingsChanged();

		Ui.requestUpdate();
	}

	function updateThemeColours() {
		var theme = THEMES[App.getApp().getProperty("Theme")];

		// Theme-specific colours.
		switch (theme) {
			case :THEME_BLUE_DARK:
				App.getApp().setProperty("ThemeColour", Graphics.COLOR_BLUE);
				break;
			
			case :THEME_PINK_DARK:
				App.getApp().setProperty("ThemeColour", Graphics.COLOR_PINK);
				break;

			case :THEME_MONO_LIGHT:
				App.getApp().setProperty("ThemeColour", Graphics.COLOR_LT_GRAY);
				break;
		}

		// Light/dark-specific colours.
		switch (theme) {
			case :THEME_BLUE_DARK:
			case :THEME_PINK_DARK:
				App.getApp().setProperty("MonoLightColour", Graphics.COLOR_WHITE);
				App.getApp().setProperty("MonoDarkColour", Graphics.COLOR_LT_GRAY);

				App.getApp().setProperty("BackgroundColour", Graphics.COLOR_BLACK);
				break;

			case :THEME_MONO_LIGHT:
				App.getApp().setProperty("MonoLightColour", Graphics.COLOR_BLACK); // (Inverted.)
				App.getApp().setProperty("MonoDarkColour", Graphics.COLOR_DK_GRAY);
				
				App.getApp().setProperty("BackgroundColour", Graphics.COLOR_WHITE);
				break;
		}

		// Common colours.
		App.getApp().setProperty("MeterBackgroundColour", Graphics.COLOR_DK_GRAY);
	}

}