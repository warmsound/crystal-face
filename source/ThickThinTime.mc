using Toybox.WatchUi as Ui;
using Toybox.System as Sys;
using Toybox.Application as App;

class ThickThinTime extends Ui.Drawable {

	private var mHighlightColour;
	private var mHoursFont, mMinutesFont, mSecondsFont;

	private var mSeconds00Width, mSecondsX, mSecondsY;
	private var mSecondsClipRect = {
			:x => 0,
			:y => 0,
			:width => 0,
			:height => 0
	};

	private var mAnteMeridiem, mPostMeridiem;

	function initialize(params) {
		Drawable.initialize(params);

		mHighlightColour = App.getApp().getProperty("HighlightColour");

		mHoursFont = Ui.loadResource(Rez.Fonts.HoursFont);
		mMinutesFont = Ui.loadResource(Rez.Fonts.MinutesFont);
		mSecondsFont = Ui.loadResource(Rez.Fonts.SecondsFont);

		mSecondsY = 155; // TODO: Define guide.

		mAnteMeridiem = Ui.loadResource(Rez.Strings.AnteMeridiem);
		mPostMeridiem = Ui.loadResource(Rez.Strings.PostMeridiem);
	}
	
	function draw(dc) {
		System.println("ThickThinTime.draw()");

		// See drawSeconds(), below.
		// Determine mSeconds00Width once, the first time a dc is available.
		if (mSeconds00Width == null) {
			mSeconds00Width = dc.getTextWidthInPixels("00", mSecondsFont);
		}

		drawHoursMinutes(dc);
		drawSeconds(dc);
	}

	function drawHoursMinutes(dc) {    		
		var clockTime = Sys.getClockTime();
		var hours = clockTime.hour;
		var minutes = clockTime.min.format("%02d");

		var is24Hour = Sys.getDeviceSettings().is24Hour;
		var isPm = true;

		if (is24Hour) {
			hours = hours.format("%02d");
		} else {
			if (hours > 12) {
				hours = hours % 12;
				isPm = true;
			}
			hours = hours.format("%d");
		}

		dc.setColor(mHighlightColour, Graphics.COLOR_TRANSPARENT);
   
		// Centre-justify the combined hours/minutes string, rather than right-justifying hours and left-justifying minutes, in
		// case hours width differs from minutes width significantly.
		// Also centre-justify vertically. Font line heights have been manually adjusted in .fnt metrics so that line height only
		// just encompasses numeric glyphs.
		var hoursWidth = dc.getTextWidthInPixels(hours, mHoursFont);
		var minutesWidth = dc.getTextWidthInPixels(minutes, mMinutesFont);
		var combinedWidth = hoursWidth + minutesWidth;
		var halfDCHeight = dc.getHeight() / 2;

		// Calculate X-position of each left-justified part.
		var hoursX = (dc.getWidth() / 2) - (combinedWidth / 2);
		var minutesX = hoursX + hoursWidth;

		// Draw hours.
		dc.drawText(
			hoursX,
			halfDCHeight,
			mHoursFont,
			hours,
			Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER
		);
		
		// Draw minutes.
		dc.drawText(
			minutesX,
			halfDCHeight,
			mMinutesFont,
			minutes,
			Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER
		);

		// Calculate and store X-position of seconds, to avoid having to recalculate when drawing seconds only.
		mSecondsX = minutesX + minutesWidth - mSeconds00Width;

		// If required, draw am/pm after minutes, vertically centred.
		if (!is24Hour) {
			
			var amPmText;
			if (isPm) {
				amPmText = mPostMeridiem;
			} else {
				amPmText = mAnteMeridiem;
			}

			dc.drawText(
				minutesX + minutesWidth,
				halfDCHeight,
				mSecondsFont,
				amPmText,
				Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER
			);
		}
	}

	// Called to draw seconds both as part of full draw(), but also onPartialUpdate() of watch face in low power mode.
	// When drawing seconds only, it is the caller's responsibility to clear the seconds background only by setting clip region,
	// but then clearing it before the new seconds text is drawn (which may be wider than previous text).
	// Seconds are aligned beneath minutes such that "00" right-aligns with right edge of minutes.
	// Seconds are drawn left-aligned to avoid left edge jumping around as seconds change.
	// Vertically centre-align with move bar guide.
	function drawSeconds(dc) {
		var clockTime = Sys.getClockTime();
		var seconds = clockTime.sec.format("%02d");

		dc.setColor(mHighlightColour, Graphics.COLOR_TRANSPARENT);

		dc.drawText(
			mSecondsX, // Recalculated in draw().
			mSecondsY,
			mSecondsFont,
			seconds,
			Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER
		);

		// Cache seconds clip rect for low power mode.
		var secondsDimensions = dc.getTextDimensions(seconds, mSecondsFont);

		mSecondsClipRect[:x] = mSecondsX;
		mSecondsClipRect[:y] = mSecondsY - (secondsDimensions[1] / 2); // Top-left corner of vertically centred text.
		mSecondsClipRect[:width] = secondsDimensions[0];
		mSecondsClipRect[:height] = secondsDimensions[1];
	}

	function getSecondsClipRect() {
		return mSecondsClipRect;
	}
}