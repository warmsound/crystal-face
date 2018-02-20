using Toybox.WatchUi as Ui;
using Toybox.System as Sys;
using Toybox.Application as App;
using Toybox.ActivityMonitor as ActivityMonitor;

class MoveBar extends Ui.Drawable {

	private var mX, mY, mWidth, mHeight, mSeparator;

	function initialize(params) {
		Drawable.initialize(params);
		
		mX = params[:x];
		mY = params[:y];
		mWidth = params[:width];
		mHeight = params[:height];
		mSeparator = params[:separator];
	}
	
	function draw(dc) {
		var info = ActivityMonitor.getInfo();
		var moveBarLevel = info.moveBarLevel;
		var barWidth = getBarWidth();
		var thisBarWidth;
		var thisBarColour;
		var x = mX;

		if (App.getApp().getProperty("AlwaysShowMoveBar")) {
			for (var i = 1; i <= ActivityMonitor.MOVE_BAR_LEVEL_MAX; ++i) {
				if (i == 1) {
					thisBarWidth = 2 * barWidth;
				} else {
					thisBarWidth = barWidth;
				}

				if (i <= moveBarLevel) {
					thisBarColour = App.getApp().getProperty("ThemeColour");
				} else {
					thisBarColour = App.getApp().getProperty("MonoDarkColour");
				}

				drawBar(dc, thisBarColour, x, thisBarWidth);

				x += thisBarWidth + mSeparator;
			}
		}
	}

	function getBarWidth() {
		// Maximum number of bars actually shown.
		var numBars = ActivityMonitor.MOVE_BAR_LEVEL_MAX - ActivityMonitor.MOVE_BAR_LEVEL_MIN - 1;

		// Subtract total separator width;
		var availableWidth = mWidth - ((numBars - 1) * mSeparator);

		var barWidth = availableWidth / (numBars + /* First bar double width */ 1);

		return barWidth;
	}

	// ----------
	//  \        \
	//   x        x + width
	//  /        /
	// ----------
	function drawBar(dc, colour, x, width) {
		var points = new [6];
		var halfHeight = (mHeight / 2);

		points[0] = [x, mY];
		points[1] = [x - halfHeight, mY - halfHeight];
		points[2] = [x - halfHeight + width, mY - halfHeight];
		points[3] = [x + width, mY];
		points[4] = [x - halfHeight + width - /* Inclusive? */ 1, mY + halfHeight + /* Exclusive? */ 1];
		points[5] = [x - halfHeight - /* Inclusive? */ 1, mY + halfHeight + /* Exclusive? */ 1];

		dc.setColor(colour, Graphics.COLOR_TRANSPARENT);
		dc.fillPolygon(points);
	}
}