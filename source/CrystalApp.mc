using Toybox.Application as App;
using Toybox.WatchUi as Ui;

class CrystalApp extends App.AppBase {

	private var mView;
	private var THEMES = {
		0 => :THEME_BLUE_DARK,
		1 => :THEME_PINK_DARK,
		2 => :THEME_GREEN_DARK,
		3 => :THEME_MONO_LIGHT,
		4 => :THEME_CORNFLOWER_BLUE_DARK,
		5 => :THEME_LEMON_CREAM_DARK,
		6 => :THEME_DAYGLO_ORANGE_DARK,
		7 => :THEME_RED_DARK,
		8 => :THEME_MONO_DARK,
	};

	private var COLOUR_OVERRIDES = {
		-1 => :FROM_THEME,
		-2 => :MONO_HIGHLIGHT,
		-3 => :MONO
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

		// Update hours/minutes colours after theme colours have been set.
		updateHoursMinutesColours();

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

			case :THEME_GREEN_DARK:
				App.getApp().setProperty("ThemeColour", Graphics.COLOR_GREEN);
				break;

			case :THEME_MONO_LIGHT:
				App.getApp().setProperty("ThemeColour", Graphics.COLOR_DK_GRAY);
				break;

			case :THEME_CORNFLOWER_BLUE_DARK:
				App.getApp().setProperty("ThemeColour", 0x55AAFF);
				break;

			case :THEME_LEMON_CREAM_DARK:
				App.getApp().setProperty("ThemeColour", 0xFFFFAA);
				break;

			case :THEME_DAYGLO_ORANGE_DARK:
				App.getApp().setProperty("ThemeColour", Graphics.COLOR_ORANGE);
				break;

			case :THEME_RED_DARK:
				App.getApp().setProperty("ThemeColour", Graphics.COLOR_RED);
				break;

			case :THEME_MONO_DARK:
				App.getApp().setProperty("ThemeColour", Graphics.COLOR_WHITE);
				break;
		}

		// Light/dark-specific colours.
		switch (theme) {
			case :THEME_BLUE_DARK:
			case :THEME_PINK_DARK:
			case :THEME_GREEN_DARK:
			case :THEME_CORNFLOWER_BLUE_DARK:
			case :THEME_LEMON_CREAM_DARK:
			case :THEME_DAYGLO_ORANGE_DARK:
			case :THEME_RED_DARK:
			case :THEME_MONO_DARK:
				App.getApp().setProperty("MonoLightColour", Graphics.COLOR_WHITE);
				App.getApp().setProperty("MonoDarkColour", Graphics.COLOR_LT_GRAY);

				App.getApp().setProperty("MeterBackgroundColour", Graphics.COLOR_DK_GRAY);
				App.getApp().setProperty("BackgroundColour", Graphics.COLOR_BLACK);
				break;

			case :THEME_MONO_LIGHT:
				App.getApp().setProperty("MonoLightColour", Graphics.COLOR_BLACK);
				App.getApp().setProperty("MonoDarkColour", Graphics.COLOR_DK_GRAY);
				
				App.getApp().setProperty("MeterBackgroundColour", Graphics.COLOR_LT_GRAY);
				App.getApp().setProperty("BackgroundColour", Graphics.COLOR_WHITE);
				break;
		}
	}

	function updateHoursMinutesColours() {

		// Hours colour.
		switch (COLOUR_OVERRIDES[App.getApp().getProperty("HoursColourOverride")]) {
			case :FROM_THEME:
				App.getApp().setProperty("HoursColour", App.getApp().getProperty("ThemeColour"));
				break;

			case :MONO_HIGHLIGHT:
				App.getApp().setProperty("HoursColour", App.getApp().getProperty("MonoLightColour"));
				break;

			case :MONO:
				App.getApp().setProperty("HoursColour", App.getApp().getProperty("MonoDarkColour"));
				break;
		}

		// Minutes colour.
		switch (COLOUR_OVERRIDES[App.getApp().getProperty("MinutesColourOverride")]) {
			case :FROM_THEME:
				App.getApp().setProperty("MinutesColour", App.getApp().getProperty("ThemeColour"));
				break;

			case :MONO_HIGHLIGHT:
				App.getApp().setProperty("MinutesColour", App.getApp().getProperty("MonoLightColour"));
				break;

			case :MONO:
				App.getApp().setProperty("MinutesColour", App.getApp().getProperty("MonoDarkColour"));
				break;
		}
	}

}