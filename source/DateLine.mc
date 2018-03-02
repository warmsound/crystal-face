using Toybox.WatchUi as Ui;
using Toybox.System as Sys;
using Toybox.Application as App;
using Toybox.Time;
using Toybox.Time.Gregorian;

class DateLine extends Ui.Drawable {

	private var mY;
	private var mFont;	

	function initialize(params) {
		Drawable.initialize(params);

		mY = params[:y];
	}

	function setFont(font) {
		mFont = font;
	}
	
	// Centre date string horizontally, then alternate between dark and light mono colours.
	function draw(dc) {
		var now = Gregorian.info(Time.now(), Time.FORMAT_MEDIUM);

		var dayOfWeek = now.day_of_week.toUpper();
		var day = now.day.format("%d");
		var month = now.month.toUpper();

		var dateString = Lang.format("$1$ $2$ $3$", [dayOfWeek, day, month]);
		var length = dc.getTextWidthInPixels(dateString, mFont);
		var x = (dc.getWidth() / 2) - (length / 2);
		
		// Draw day of week.
		dc.setColor(App.getApp().getProperty("MonoDarkColour"), Graphics.COLOR_TRANSPARENT);
		dc.drawText(
			x,
			mY,
			mFont,
			dayOfWeek,
			Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER
		);
		x += dc.getTextWidthInPixels(dayOfWeek + " ", mFont);

		// Draw day.
		dc.setColor(App.getApp().getProperty("MonoLightColour"), Graphics.COLOR_TRANSPARENT);
		dc.drawText(
			x,
			mY,
			mFont,
			day,
			Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER
		);
		x += dc.getTextWidthInPixels(day + " ", mFont);

		// Draw month.
		dc.setColor(App.getApp().getProperty("MonoDarkColour"), Graphics.COLOR_TRANSPARENT);
		dc.drawText(
			x,
			mY,
			mFont,
			month,
			Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER
		);
	}
}