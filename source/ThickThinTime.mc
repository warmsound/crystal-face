using Toybox.WatchUi as Ui;
using Toybox.System as Sys;
using Toybox.Application as App;

class ThickThinTime extends Ui.Drawable {

    hidden var mHoursFont, mMinutesFont, mSecondsFont;

    function initialize(params) {
        Drawable.initialize(params);

        mHoursFont = Ui.loadResource(Rez.Fonts.HoursFont);
        mMinutesFont = Ui.loadResource(Rez.Fonts.MinutesFont);
        mSecondsFont = Ui.loadResource(Rez.Fonts.SecondsFont);
    }
    
    function draw(dc) {
        var clockTime = Sys.getClockTime();
        var hours = clockTime.hour;
        var minutes = clockTime.min.format("%02d");
        var seconds = clockTime.sec.format("%02d");

        var is24Hour = Sys.getDeviceSettings().is24Hour;
        var isPm = true;

        if (!is24Hour) {
            if (hours > 12) {
                hours = hours % 12;
                isPm = true;
            }
        }
        
        hours = hours.format("%02d");
        
        var highlightColour = App.getApp().getProperty("HighlightColour");
        dc.setColor(highlightColour, Graphics.COLOR_TRANSPARENT);        
   
        // Centre-justify the combined hours/minutes string, rather than right-justifying hours and left-justifying minutes, in
        // case hours width differs from minutes width significantly.
        // Also centre-justify vertically. Font line heights have been manually adjusted in .fnt metrics so that line height only
        // just encompasses numeric glyphs.
        var hoursWidth = dc.getTextWidthInPixels(hours, mHoursFont);
        var minutesWidth = dc.getTextWidthInPixels(minutes, mMinutesFont);
        var combinedWidth = hoursWidth + minutesWidth;

        // Calculate X-position of each left-justified part.
        var hoursX = (dc.getWidth() / 2) - (combinedWidth / 2);
        var minutesX = hoursX + hoursWidth;

        // Draw hours.
        dc.drawText(
            hoursX,
            dc.getHeight() / 2,
            mHoursFont,
            hours,
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER
        );
        
        // Draw minutes.
        dc.drawText(
            minutesX,
            dc.getHeight() / 2,
            mMinutesFont,
            minutes,
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER
        );

        // Seconds are left-aligned after minutes, and share the same baseline.
        var seconds00Width = dc.getTextWidthInPixels("00", mSecondsFont);
        
        dc.drawText(
            minutesX + minutesWidth - seconds00Width,
            155, // TODO: move bar and seconds guide.
            mSecondsFont,
            seconds,
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER
        );
    }
}