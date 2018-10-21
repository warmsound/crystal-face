using Toybox.WatchUi as Ui;
using Toybox.System as Sys;
using Toybox.Application as App;
using Toybox.Time;
using Toybox.Time.Gregorian;

class DateLine extends Ui.Drawable {

	private var mX;
	private var mY;	
	private var mYLine2;

	private var mDayOfWeek;
	private var mDayOfWeekString;

	private var mMonth;
	private var mMonthString;

	private var mFont;

	function initialize(params) {
		Drawable.initialize(params);

		// Unfortunate: because fonts can't be overridden based on locale, we have to read in current locale as manually-specified
		// string, then override font in code.
		var dateFontOverride = Ui.loadResource(Rez.Strings.DATE_FONT_OVERRIDE);
		switch (dateFontOverride) {
			case "ZHS":
				mFont  = Ui.loadResource(Rez.Fonts.DateFontOverrideZHS);
				break;

			case "ZHT":
				mFont  = Ui.loadResource(Rez.Fonts.DateFontOverrideZHT);
				break;

			case "RUS":
				mFont  = Ui.loadResource(Rez.Fonts.DateFontOverrideRUS);
				break;

			default:
				mFont  = Ui.loadResource(Rez.Fonts.DateFont);
				break;
		}

		mX = params[:x];
		mY = params[:y];
		mYLine2 = params[:yLine2];
	}
	
	// Centre date string horizontally, then alternate between dark and light mono colours.
	function draw(dc) {

		// Supply DOW/month strings ourselves, rather than relying on Time.FORMAT_MEDIUM, as latter is inconsistent e.g. returns
		// "Thurs" instead of "Thu".
		// Load strings just-in-time, to save memory. They rarely change, so worthwhile trade-off.
		var now = Gregorian.info(Time.now(), Time.FORMAT_SHORT);

		var dayOfWeek = now.day_of_week;
		if (dayOfWeek != mDayOfWeek) {
			mDayOfWeek = dayOfWeek;
			switch (mDayOfWeek) {
				case 1:
					mDayOfWeekString = Ui.loadResource(Rez.Strings.Sun);
					break;
				case 2:
					mDayOfWeekString = Ui.loadResource(Rez.Strings.Mon);
					break;
				case 3:
					mDayOfWeekString = Ui.loadResource(Rez.Strings.Tue);
					break;
				case 4:
					mDayOfWeekString = Ui.loadResource(Rez.Strings.Wed);
					break;
				case 5:
					mDayOfWeekString = Ui.loadResource(Rez.Strings.Thu);
					break;
				case 6:
					mDayOfWeekString = Ui.loadResource(Rez.Strings.Fri);
					break;
				case 7:
					mDayOfWeekString = Ui.loadResource(Rez.Strings.Sat);
					break;
			}
			mDayOfWeekString = mDayOfWeekString.toUpper();
		}

		var month = now.month;
		if (month != mMonth) {
			mMonth = month;
			switch (mMonth) {
				case 1:
					mMonthString = Ui.loadResource(Rez.Strings.Jan);
					break;
				case 2:
					mMonthString = Ui.loadResource(Rez.Strings.Feb);
					break;
				case 3:
					mMonthString = Ui.loadResource(Rez.Strings.Mar);
					break;
				case 4:
					mMonthString = Ui.loadResource(Rez.Strings.Apr);
					break;
				case 5:
					mMonthString = Ui.loadResource(Rez.Strings.May);
					break;
				case 6:
					mMonthString = Ui.loadResource(Rez.Strings.Jun);
					break;
				case 7:
					mMonthString = Ui.loadResource(Rez.Strings.Jul);
					break;
				case 8:
					mMonthString = Ui.loadResource(Rez.Strings.Aug);
					break;
				case 9:
					mMonthString = Ui.loadResource(Rez.Strings.Sep);
					break;
				case 10:
					mMonthString = Ui.loadResource(Rez.Strings.Oct);
					break;
				case 11:
					mMonthString = Ui.loadResource(Rez.Strings.Nov);
					break;
				case 12:
					mMonthString = Ui.loadResource(Rez.Strings.Dec);
					break;
			}
			mMonthString = mMonthString.toUpper();
		}

		var day = now.day.format(INTEGER_FORMAT);

		var monoDarkColour = App.getApp().getProperty("MonoDarkColour");
		var monoLightColour = App.getApp().getProperty("MonoLightColour");

		// drawDoubleLine(dc, mDayOfWeekString, day, mMonthString);
		if (mYLine2 != null) {

			// Draw day of week, left-aligned at (mX, mY).
			dc.setColor(monoDarkColour, Graphics.COLOR_TRANSPARENT);
			dc.drawText(
				mX,
				mY,
				mFont,
				mDayOfWeekString,
				Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER
			);

			// Draw month, left-aligned at (mX, mYLine2).
			dc.drawText(
				mX,
				mYLine2,
				mFont,
				mMonthString,
				Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER
			);

			// Draw day, after day of week.
			dc.setColor(monoLightColour, Graphics.COLOR_TRANSPARENT);
			dc.drawText(
				mX + dc.getTextWidthInPixels(mDayOfWeekString + " ", mFont),
				mY,
				mFont,
				day,
				Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER
			);

		// drawSingleLine(dc, mDayOfWeekString, day, mMonthString);
		} else {

			var dateString = Lang.format("$1$ $2$ $3$", [mDayOfWeekString, day, mMonthString]);
			var length = dc.getTextWidthInPixels(dateString, mFont);
			var x = (dc.getWidth() / 2) - (length / 2);
			
			// Draw day of week.
			dc.setColor(monoDarkColour, Graphics.COLOR_TRANSPARENT);
			dc.drawText(
				x,
				mY,
				mFont,
				mDayOfWeekString,
				Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER
			);
			x += dc.getTextWidthInPixels(mDayOfWeekString + " ", mFont);

			// Draw day.
			dc.setColor(monoLightColour, Graphics.COLOR_TRANSPARENT);
			dc.drawText(
				x,
				mY,
				mFont,
				day,
				Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER
			);
			x += dc.getTextWidthInPixels(day + " ", mFont);

			// Draw month.
			dc.setColor(monoDarkColour, Graphics.COLOR_TRANSPARENT);
			dc.drawText(
				x,
				mY,
				mFont,
				mMonthString,
				Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER
			);
		}
	}
}