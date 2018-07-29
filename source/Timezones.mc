using Toybox.WatchUi as Ui;
using Toybox.System as Sys;
using Toybox.Application as App;
using Toybox.Graphics as Gfx;
using Toybox.Time.Gregorian as Calendar;

(:timezones)
class Timezones extends Ui.Drawable {

	var mUtcOffset = new Time.Duration(-Sys.getClockTime().timeZoneOffset);
	
	var mTzLocations = [];
	var mTimeZones;
	
	var mTopY;
	var mBottomY;

	function initialize(params) {
		Drawable.initialize(params);

		mTopY = params[:topY];
		mBottomY = params[:bottomY];
		
		setupTimezones();
	}

	function onSettingsChanged() {
		setupTimezones();
	}

	function setupTimezones() {
		mTzLocations = [];
		
		mTimeZones = App.getApp().getProperty("timezones").toNumber();
		for (var i = 1; i <= mTimeZones; i++) {
			var name = App.getApp().getProperty("tz"+i+"_name");
			var offset = App.getApp().getProperty("tz"+i+"_offset").toNumber();
			var dst = App.getApp().getProperty("tz"+i+"_dst");
			if (name.equals("")) {
				continue;
			} else {

				//System.println("Name:<"+name+">");
				var TzOffset = [];	
				if (dst == true ) {
					offset = offset+1;
				}
				TzOffset.add(name);
				TzOffset.add(offset); 
				mTzLocations.add(TzOffset);
			}
		}
	}
	
	function draw(dc) {
		drawTimezones(dc);
	}

	function drawTimezones(dc){

		var clockTime = Sys.getClockTime();
		var now = Time.now();

		var tzString="";
		var row = 0;
		var zones = mTzLocations.size();

		var tzFont = Gfx.FONT_MEDIUM;

		//Get the width and height of an example timezone 
		var textSize = dc.getTextDimensions("MLB:20", tzFont);
		var textHeight = Gfx.getFontAscent(tzFont);
		var textWidth = textSize[0];
		
		//We want the timezones to appear symetrically on the watchface with
		//an equal amount above and below the local time
		//xGap calculates the space between the times on the same row and makes sure
		//that the gap on between the edges and the timezones are equal
		var xGap = (((dc.getWidth()) - (zones/2)*textWidth)/((zones/2)+1))+0.5*textWidth ;
		var xPosn = 0; 
		
		var y = mTopY;
		//System.println("Timezone position"+y);

		var utcNow = now.add(mUtcOffset);
		var utcInfo = Calendar.info(utcNow, Time.FORMAT_SHORT);
		
		for (var i = 0; i < zones; ++i) {
			
			var location = mTzLocations[i][0];
			var tzOffset = mTzLocations[i][1];
			var tzHour = utcInfo.hour + tzOffset;
			if (tzHour > 23){
				tzHour = tzHour - 24; 
			}
			if (tzHour < 0){
				tzHour = tzHour + 24;
			}
			
			tzString = location + ":" + tzHour.format("%02d");
		
			xPosn = xPosn + xGap; 
	
			dc.drawText(xPosn, y, tzFont, tzString, (Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER));
			xPosn = xPosn + 0.5*textWidth; 
		
			if( i==((zones/2)-1)){ 
				xPosn = 0;
				y = mBottomY;
			}
		}
	}
}