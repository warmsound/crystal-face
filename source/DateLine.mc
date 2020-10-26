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
	
	private var mWeekOfYear;
	private var mWeekOfYearLetter;
	private var mWeekOfYearString;

	private var mFont;

	function initialize(params) {
		Drawable.initialize(params);

		var rezFonts = Rez.Fonts;
		var resourceMap = {
			"ZHS" => rezFonts.DateFontOverrideZHS,
			"ZHT" => rezFonts.DateFontOverrideZHT,
			"RUS" => rezFonts.DateFontOverrideRUS
		};

		// Unfortunate: because fonts can't be overridden based on locale, we have to read in current locale as manually-specified
		// string, then override font in code.
		var dateFontOverride = Ui.loadResource(Rez.Strings.DATE_FONT_OVERRIDE);
		var dateFont = (resourceMap.hasKey(dateFontOverride)) ? resourceMap[dateFontOverride] : rezFonts.DateFont;
		mFont = Ui.loadResource(dateFont);

		mX = params[:x];
		mY = params[:y];
		mYLine2 = params[:yLine2];
		
		// Localized letter for week number
		mWeekOfYearLetter = "W";
	}
	
	// Centre date string horizontally, then alternate between dark and light mono colours.
	function draw(dc) {
		var rezStrings = Rez.Strings;
		var resourceArray;

		// Supply DOW/month strings ourselves, rather than relying on Time.FORMAT_MEDIUM, as latter is inconsistent e.g. returns
		// "Thurs" instead of "Thu".
		// Load strings just-in-time, to save memory. They rarely change, so worthwhile trade-off.
		var now = Gregorian.info(Time.now(), Time.FORMAT_SHORT);

		var dayOfWeek = now.day_of_week;
		if (dayOfWeek != mDayOfWeek) {
			mDayOfWeek = dayOfWeek;
			
			resourceArray = [
				rezStrings.Sun,
				rezStrings.Mon,
				rezStrings.Tue,
				rezStrings.Wed,
				rezStrings.Thu,
				rezStrings.Fri,
				rezStrings.Sat
				];
			mDayOfWeekString = Ui.loadResource(resourceArray[mDayOfWeek - 1]).toUpper();
			
			// Recalculate week number when dayOfWeek is reloaded
			mWeekOfYear = isoWeekNumber(now.year, now.month, now.day);
			mWeekOfYearString = Lang.format("$1$$2$", [mWeekOfYearLetter, mWeekOfYear]);
		}

		var month = now.month;
		if (month != mMonth) {
			mMonth = month;

			resourceArray = [
				rezStrings.Jan,
				rezStrings.Feb,
				rezStrings.Mar,
				rezStrings.Apr,
				rezStrings.May,
				rezStrings.Jun,
				rezStrings.Jul,
				rezStrings.Aug,
				rezStrings.Sep,
				rezStrings.Oct,
				rezStrings.Nov,
				rezStrings.Dec
				];
			mMonthString = Ui.loadResource(resourceArray[mMonth - 1]).toUpper();
		}
		
		var day = now.day.format(INTEGER_FORMAT);
		if (mYLine2 != null) {
			drawDoubleLine(dc, day);
		} else {
			drawSingleLine(dc, day);
		}
	}

	(:double_line_date)
	function drawDoubleLine(dc, day) {
		// Draw day of week, left-aligned at (mX, mY).
		dc.setColor(gMonoDarkColour, Graphics.COLOR_TRANSPARENT);
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
		dc.setColor(gMonoLightColour, Graphics.COLOR_TRANSPARENT);
		dc.drawText(
			mX + dc.getTextWidthInPixels(mDayOfWeekString + " ", mFont),
			mY,
			mFont,
			day,
			Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER
		);
		
		if (!App.getApp().getProperty("HideWeekNumber")) {
			// Draw week letter.
			var x = mX + dc.getTextWidthInPixels(mMonthString + " ", mFont);
			dc.setColor(gMonoLightColour, Graphics.COLOR_TRANSPARENT);
			dc.drawText(
				x,
				mYLine2,
				mFont,
				mWeekOfYearLetter,
				Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER
			);
			// Draw week number
			dc.setColor(gMonoDarkColour, Graphics.COLOR_TRANSPARENT);
			dc.drawText(
				x + dc.getTextWidthInPixels(mWeekOfYearLetter, mFont),
				mYLine2,
				mFont,
				mWeekOfYear,
				Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER
			);
		}
	}

	function drawSingleLine(dc, day) {
		var dateString = Lang.format("$1$ $2$ $3$", [mDayOfWeekString, day, mMonthString]);
		if (!App.getApp().getProperty("HideWeekNumber")) {
			dateString = Lang.format("$1$ $2$", [dateString, mWeekOfYearString]);	
		}
		var length = dc.getTextWidthInPixels(dateString, mFont);
		var x = (dc.getWidth() / 2) - (length / 2);
		
		// Draw day of week.
		dc.setColor(gMonoDarkColour, Graphics.COLOR_TRANSPARENT);
		dc.drawText(
			x,
			mY,
			mFont,
			mDayOfWeekString,
			Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER
		);
		x += dc.getTextWidthInPixels(mDayOfWeekString + " ", mFont);

		// Draw day.
		dc.setColor(gMonoLightColour, Graphics.COLOR_TRANSPARENT);
		dc.drawText(
			x,
			mY,
			mFont,
			day,
			Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER
		);
		x += dc.getTextWidthInPixels(day + " ", mFont);

		// Draw month.
		dc.setColor(gMonoDarkColour, Graphics.COLOR_TRANSPARENT);
		dc.drawText(
			x,
			mY,
			mFont,
			mMonthString,
			Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER
		);
			
		if (!App.getApp().getProperty("HideWeekNumber")) {
			// Draw week letter.
			x += dc.getTextWidthInPixels(mMonthString + " ", mFont);
			dc.setColor(gMonoLightColour, Graphics.COLOR_TRANSPARENT);
			dc.drawText(
				x,
				mY,
				mFont,
				mWeekOfYearLetter,
				Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER
			);
			// Draw week number
			x += dc.getTextWidthInPixels(mWeekOfYearLetter, mFont);
			dc.setColor(gMonoDarkColour, Graphics.COLOR_TRANSPARENT);
			dc.drawText(
				x,
				mY,
				mFont,
				mWeekOfYear,
				Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER
			);
		}
	}
	
	
	function julianDay(year, month, day) {
	    var a = (14 - month) / 12;
	    var y = (year + 4800 - a);
	    var m = (month + 12 * a - 3);
	    return day + ((153 * m + 2) / 5) + (365 * y) + (y / 4) - (y / 100) + (y / 400) - 32045;
	}

	function isLeapYear(year) {
	    if (year % 4 != 0) {
	        return false;
	    } else if (year % 100 != 0) {
	        return true;
	    } else if (year % 400 == 0) {
	        return true;
	    }
	
	    return false;
	}
	
	function isoWeekNumber(year, month, day) {
	    var firstDayOfYear = julianDay(year, 1, 1);
	    var givenDayOfYear = julianDay(year, month, day);
	
	    var dayOfWeek = (firstDayOfYear + 3) % 7; // days past thursday
	    var weekOfYear = (givenDayOfYear - firstDayOfYear + dayOfWeek + 4) / 7;
	
		// week is at end of this year or the beginning of next year
	    if (weekOfYear == 53) {
	
	        if (dayOfWeek == 6) {
	            return weekOfYear;
	        } else if (dayOfWeek == 5 && isLeapYear(year)) {
	            return weekOfYear;
	        } else {
	            return 1;
	        }
	    }
	
		// week is in previous year, try again under that year
	    else if (weekOfYear == 0) {
	        firstDayOfYear = julianDay(year - 1, 1, 1);
	
	        dayOfWeek = (firstDayOfYear + 3) % 7;
	
	        return (givenDayOfYear - firstDayOfYear + dayOfWeek + 4) / 7;
	    }
	
		// any old week of the year
	    else {
	        return weekOfYear;
	    }
	}
	
}