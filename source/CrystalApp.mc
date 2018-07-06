using Toybox.Application as App;
using Toybox.WatchUi as Ui;

class CrystalApp extends App.AppBase {

	private var mView;
	private var THEMES = [
		:THEME_BLUE_DARK,
		:THEME_PINK_DARK,
		:THEME_GREEN_DARK,
		:THEME_MONO_LIGHT,
		:THEME_CORNFLOWER_BLUE_DARK,
		:THEME_LEMON_CREAM_DARK,
		:THEME_DAYGLO_ORANGE_DARK,
		:THEME_RED_DARK,
		:THEME_MONO_DARK,
		:THEME_BLUE_LIGHT,
		:THEME_GREEN_LIGHT,
		:THEME_RED_LIGHT,
		:THEME_VIVID_YELLOW_DARK,
	];

	private var COLOUR_OVERRIDES = {
		-1 => :FROM_THEME,
		-2 => :MONO_HIGHLIGHT,
		-3 => :MONO
	};

	function initialize() {
		AppBase.initialize();
		updateThemeColours();
		updateHoursMinutesColours();
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
		var themeColour;
		switch (theme) {
			case :THEME_BLUE_DARK:
				themeColour = Graphics.COLOR_BLUE;
				break;
			
			case :THEME_PINK_DARK:
				themeColour = Graphics.COLOR_PINK;
				break;

			case :THEME_GREEN_DARK:
				themeColour = Graphics.COLOR_GREEN;
				break;

			case :THEME_MONO_LIGHT:
				themeColour = Graphics.COLOR_DK_GRAY;
				break;

			case :THEME_CORNFLOWER_BLUE_DARK:
				themeColour = 0x55AAFF;
				break;

			case :THEME_LEMON_CREAM_DARK:
				themeColour = 0xFFFFAA;
				break;

			case :THEME_VIVID_YELLOW_DARK:
				themeColour = 0xFFFF00;
				break;

			case :THEME_DAYGLO_ORANGE_DARK:
				themeColour = Graphics.COLOR_ORANGE;
				break;

			case :THEME_RED_DARK:
				themeColour = Graphics.COLOR_RED;
				break;

			case :THEME_MONO_DARK:
				themeColour = Graphics.COLOR_WHITE;
				break;

			case :THEME_BLUE_LIGHT:
				themeColour = Graphics.COLOR_DK_BLUE;
				break;

			case :THEME_GREEN_LIGHT:
				themeColour = Graphics.COLOR_DK_GREEN;
				break;

			case :THEME_RED_LIGHT:
				themeColour = Graphics.COLOR_DK_RED;
				break;
		}
		App.getApp().setProperty("ThemeColour", themeColour); 

		// Light/dark-specific colours.
		switch (theme) {
			case :THEME_BLUE_DARK:
			case :THEME_PINK_DARK:
			case :THEME_GREEN_DARK:
			case :THEME_CORNFLOWER_BLUE_DARK:
			case :THEME_LEMON_CREAM_DARK:
			case :THEME_VIVID_YELLOW_DARK:
			case :THEME_DAYGLO_ORANGE_DARK:
			case :THEME_RED_DARK:
			case :THEME_MONO_DARK:
				App.getApp().setProperty("MonoLightColour", Graphics.COLOR_WHITE);
				App.getApp().setProperty("MonoDarkColour", Graphics.COLOR_LT_GRAY);

				App.getApp().setProperty("MeterBackgroundColour", Graphics.COLOR_DK_GRAY);
				App.getApp().setProperty("BackgroundColour", Graphics.COLOR_BLACK);
				break;

			case :THEME_MONO_LIGHT:
			case :THEME_BLUE_LIGHT:
			case :THEME_GREEN_LIGHT:
			case :THEME_RED_LIGHT:
				App.getApp().setProperty("MonoLightColour", Graphics.COLOR_BLACK);
				App.getApp().setProperty("MonoDarkColour", Graphics.COLOR_DK_GRAY);
				
				App.getApp().setProperty("MeterBackgroundColour", Graphics.COLOR_LT_GRAY);
				App.getApp().setProperty("BackgroundColour", Graphics.COLOR_WHITE);
				break;
		}
	}

	function updateHoursMinutesColours() {

		// Hours colour.
		var hoursColour;
		switch (COLOUR_OVERRIDES[App.getApp().getProperty("HoursColourOverride")]) {
			case :FROM_THEME:
				hoursColour = App.getApp().getProperty("ThemeColour");
				break;

			case :MONO_HIGHLIGHT:
				hoursColour = App.getApp().getProperty("MonoLightColour");
				break;

			case :MONO:
				hoursColour = App.getApp().getProperty("MonoDarkColour");
				break;
		}
		App.getApp().setProperty("HoursColour", hoursColour);

		// Minutes colour.
		var minutesColour;
		switch (COLOUR_OVERRIDES[App.getApp().getProperty("MinutesColourOverride")]) {
			case :FROM_THEME:
				minutesColour = App.getApp().getProperty("ThemeColour");
				break;

			case :MONO_HIGHLIGHT:
				minutesColour = App.getApp().getProperty("MonoLightColour");
				break;

			case :MONO:
				minutesColour = App.getApp().getProperty("MonoDarkColour");
				break;
		}
		App.getApp().setProperty("MinutesColour", minutesColour);
	}

}