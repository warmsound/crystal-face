using Toybox.WatchUi as Ui;
using Toybox.System as Sys;
using Toybox.Application as App;
using Toybox.Time;
using Toybox.Time.Gregorian;

class DateLine extends Ui.Drawable {

	private var mX;
	private var mY;	
	private var mYLine2;

	private var mDayOfWeekStrings;
	private var mMonthStrings;

	private var mFont;

	function initialize(params) {
		Drawable.initialize(params);

		mDayOfWeekStrings = [
			Ui.loadResource(Rez.Strings.Sun),
			Ui.loadResource(Rez.Strings.Mon),
			Ui.loadResource(Rez.Strings.Tue),
			Ui.loadResource(Rez.Strings.Wed),
			Ui.loadResource(Rez.Strings.Thu),
			Ui.loadResource(Rez.Strings.Fri),
			Ui.loadResource(Rez.Strings.Sat),
		];

		mMonthStrings = [
			Ui.loadResource(Rez.Strings.Jan),
			Ui.loadResource(Rez.Strings.Feb),
			Ui.loadResource(Rez.Strings.Mar),
			Ui.loadResource(Rez.Strings.Apr),
			Ui.loadResource(Rez.Strings.May),
			Ui.loadResource(Rez.Strings.Jun),
			Ui.loadResource(Rez.Strings.Jul),
			Ui.loadResource(Rez.Strings.Aug),
			Ui.loadResource(Rez.Strings.Sep),
			Ui.loadResource(Rez.Strings.Oct),
			Ui.loadResource(Rez.Strings.Nov),
			Ui.loadResource(Rez.Strings.Dec),
		];

		mX = params[:x];
		mY = params[:y];
		mYLine2 = params[:yLine2];
	}

	function setFont(font) {
		mFont = font;
	}
	
	// Centre date string horizontally, then alternate between dark and light mono colours.
	function draw(dc) {

		// Supply DOW/month strings ourselves, rather than relying on Time.FORMAT_MEDIUM, as latter is inconsistent e.g. returns
		// "Thurs" instead of "Thu".
		var now = Gregorian.info(Time.now(), Time.FORMAT_SHORT);

		var dayOfWeek = mDayOfWeekStrings[now.day_of_week - 1].toUpper(); // DOWs are zero-based, starting Sunday.
		var day = now.day.format("%d");
		var month = mMonthStrings[now.month - 1].toUpper(); // Months are zero-based, starting January.

		if (mYLine2 != null) {
			drawDoubleLine(dc, dayOfWeek, day, month);
		} else {
			drawSingleLine(dc, dayOfWeek, day, month);
		}
	}

	function drawSingleLine(dc, dayOfWeek, day, month) {
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

	function drawDoubleLine(dc, dayOfWeek, day, month) {

		// Draw day of week, left-aligned at (mX, mY).
		dc.setColor(App.getApp().getProperty("MonoDarkColour"), Graphics.COLOR_TRANSPARENT);
		dc.drawText(
			mX,
			mY,
			mFont,
			dayOfWeek,
			Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER
		);

		// Draw day, left-aligned at (mX, mYLine2).
		dc.setColor(App.getApp().getProperty("MonoLightColour"), Graphics.COLOR_TRANSPARENT);
		dc.drawText(
			mX,
			mYLine2,
			mFont,
			day,
			Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER
		);

		// Draw month after day.
		dc.setColor(App.getApp().getProperty("MonoDarkColour"), Graphics.COLOR_TRANSPARENT);
		dc.drawText(
			mX + dc.getTextWidthInPixels(day + " ", mFont),
			mYLine2,
			mFont,
			month,
			Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER
		);
	}
}