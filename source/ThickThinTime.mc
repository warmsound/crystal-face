using Toybox.WatchUi as Ui;
using Toybox.System as Sys;
using Toybox.Application as App;

class ThickThinTime extends Ui.Drawable {

    hidden var mHoursFont, mMinutesFont;

    function initialize(params) {
        Drawable.initialize(params);

        mHoursFont = Ui.loadResource(Rez.Fonts.HoursFont);
        mMinutesFont = Ui.loadResource(Rez.Fonts.MinutesFont);
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
   
        dc.drawText(
            dc.getWidth() / 2,
            dc.getHeight() / 2,
            mHoursFont,
            hours,
            Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER
        );
        
        dc.drawText(
            dc.getWidth() / 2,
            dc.getHeight() / 2,
            mMinutesFont,
            minutes,
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER
        );
        
        var minutesWidth = dc.getTextWidthInPixels(minutes, mHoursFont);
    }
}