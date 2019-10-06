using Toybox.WatchUi as Ui;
using Toybox.System as Sys;
using Toybox.Application as App;
using Toybox.Time;
using Toybox.Time.Gregorian;

// Draw time, line, date, battery.
// Combine stripped down versions of ThickThinTime and DateLine.
// Change vertical offset every minute to comply with burn-in protection requirements.
class AlwaysOnDisplay extends Ui.Drawable {

	private var mBurnInYOffsets;
	private var mHoursFont, mMinutesFont, mSecondsFont, mDateFont, mBatteryFont;

	// Wide rectangle: time should be moved up slightly to centre within available space.
	private var mAdjustY = 0;

	private var mTimeY;
	private var mLineY;
	private var mLineWidth;
	private var mLineStroke;
	private var mDataY;
	private var mDataLeft;

	private var AM_PM_X_OFFSET = 2;

	private var mDayOfWeek;
	private var mDayOfWeekString;

	private var mMonth;
	private var mMonthString;

	function initialize(params) {
		Drawable.initialize(params);

		mBurnInYOffsets = params[:burnInYOffsets];

		if (params[:adjustY] != null) {
			mAdjustY = params[:adjustY];
		}

		if (params[:amPmOffset] != null) {
			AM_PM_X_OFFSET = params[:amPmOffset];
		}

		mTimeY = params[:timeY];
		mLineY = params[:lineY];
		mLineWidth = params[:lineWidth];
		//mLineStroke = params[:lineStroke];
		mDataY = params[:dataY];
		mDataLeft = params[:dataLeft];

		mHoursFont = Ui.loadResource(Rez.Fonts.AlwaysOnHoursFont);
		mMinutesFont = Ui.loadResource(Rez.Fonts.AlwaysOnMinutesFont);
		mSecondsFont = Ui.loadResource(Rez.Fonts.AlwaysOnSecondsFont);
		mBatteryFont = Ui.loadResource(Rez.Fonts.AlwaysOnBatteryFont);

		var rezFonts = Rez.Fonts;
		var resourceMap = {
			"ZHS" => rezFonts.AlwaysOnDateFontOverrideZHS,
			"ZHT" => rezFonts.AlwaysOnDateFontOverrideZHT,
			"RUS" => rezFonts.AlwaysOnDateFontOverrideRUS
		};

		// Unfortunate: because fonts can't be overridden based on locale, we have to read in current locale as manually-specified
		// string, then override font in code.
		var dateFontOverride = Ui.loadResource(Rez.Strings.DATE_FONT_OVERRIDE);
		var dateFont = (resourceMap.hasKey(dateFontOverride)) ? resourceMap[dateFontOverride] : rezFonts.AlwaysOnDateFont;
		mDateFont = Ui.loadResource(dateFont);
	}
	
	function draw(dc) {

		// TIME.
		var clockTime = Sys.getClockTime();
		var formattedTime = App.getApp().getFormattedTime(clockTime.hour, clockTime.min);
		formattedTime[:amPm] = formattedTime[:amPm].toUpper();

		// Change vertical offset every minute.
		var burnInYOffset = mBurnInYOffsets[clockTime.min % mBurnInYOffsets.size()] + (clockTime.min - 30);

		var hours = formattedTime[:hour];
		var minutes = formattedTime[:min];
		var amPmText = formattedTime[:amPm];

		var halfDCWidth = dc.getWidth() / 2;		

		// Centre combined hours and minutes text (not the same as right-aligning hours and left-aligning minutes).
		// Font has tabular figures (monospaced numbers) even across different weights, so does not matter which of hours or
		// minutes font is used to calculate total width. 
		var totalWidth = dc.getTextWidthInPixels(hours + minutes, mHoursFont);
		var x = halfDCWidth - (totalWidth / 2);
		var y = mTimeY + mAdjustY + burnInYOffset;

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);

		// Hours.		
		dc.drawText(
			x,
			y,
			mHoursFont,
			hours,
			Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER
		);
		x += dc.getTextWidthInPixels(hours, mHoursFont);

		// Minutes.
		dc.drawText(
			x,
			y,
			mMinutesFont,
			minutes,
			Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER
		);

		// If required, draw AM/PM after minutes, vertically centred.
		if (amPmText.length() > 0) {
			x += dc.getTextWidthInPixels(minutes, mMinutesFont);
			dc.drawText(
				x + AM_PM_X_OFFSET, // Breathing space between minutes and AM/PM.
				y,
				mSecondsFont,
				amPmText,
				Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER
			);
		}

		// LINE.
		y = mLineY + burnInYOffset;
		dc.setPenWidth(/* mLineStroke */ 2);		
		dc.drawLine(halfDCWidth - (mLineWidth / 2), y, halfDCWidth + (mLineWidth / 2), y);

		// DATA.
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

		// Date.
		y = mDataY + burnInYOffset;	
		dc.drawText(
			mDataLeft,
			y,
			mDateFont,
			Lang.format("$1$ $2$ $3$", [mDayOfWeekString, day, mMonthString]),
			Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER
		);

		// Battery.
		var battery = Math.floor(Sys.getSystemStats().battery);
		dc.drawText(
			dc.getWidth() - mDataLeft,
			y,
			mBatteryFont,
			battery.format(INTEGER_FORMAT) + "%",
			Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER
		);
	}
}