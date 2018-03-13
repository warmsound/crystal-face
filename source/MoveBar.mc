using Toybox.WatchUi as Ui;
using Toybox.System as Sys;
using Toybox.Application as App;
using Toybox.ActivityMonitor as ActivityMonitor;

class MoveBar extends Ui.Drawable {

	private var mX, mY, mWidth, mHeight, mSeparator;
	private var mTailWidth;
	private var mBuffer;
	private var mBufferNeedsRecreate = true;
	private var mBufferNeedsRedraw = true;
	private var mLastMoveBarLevel;

	function initialize(params) {
		Drawable.initialize(params);
		
		mX = params[:x];
		mY = params[:y];
		mWidth = params[:width];
		mHeight = params[:height];
		mSeparator = params[:separator];

		mTailWidth = mHeight / 2;
	}

	function onSettingsChanged() {
		mBufferNeedsRecreate = true;
	}
	
	function draw(dc) {
		var themeColour = App.getApp().getProperty("ThemeColour");
		var meterBackgroundColour = App.getApp().getProperty("MeterBackgroundColour");
		var backgroundColour = App.getApp().getProperty("BackgroundColour");

		var info = ActivityMonitor.getInfo();
		var currentMoveBarLevel = info.moveBarLevel;

		// Recreate buffers only if this is the very first draw(), or if optimised colour palette has changed e.g. theme colour
		// change.
		if (mBufferNeedsRecreate) {
			mBuffer = new Graphics.BufferedBitmap({
				:width => mWidth,
				:height => mHeight,

				// First palette colour appears to determine initial colour of buffer.
				:palette => [Graphics.COLOR_TRANSPARENT, meterBackgroundColour, themeColour]
			});
			mBufferNeedsRecreate = false;
			mBufferNeedsRedraw = true; // Ensure newly-created buffer is drawn next.
		}

		// #7 Redraw buffer (only) if move bar level changes.
		if (currentMoveBarLevel != mLastMoveBarLevel) {
			mLastMoveBarLevel = currentMoveBarLevel;
			mBufferNeedsRedraw = true;
		}
		
		if (mBufferNeedsRedraw) {
			
			var barWidth = getBarWidth();
			var thisBarWidth;
			var thisBarColour = 0;
			var x = mTailWidth;
			var alwaysShowMoveBar = App.getApp().getProperty("AlwaysShowMoveBar");

			for (var i = 1; i < ActivityMonitor.MOVE_BAR_LEVEL_MAX; ++i) {

				// First bar is double width.
				if (i == 1) {
					thisBarWidth = 2 * barWidth;
				} else {
					thisBarWidth = barWidth;
				}

				// Move bar at this level or greater, so show regardless of AlwaysShowMoveBar setting.
				if (i <= currentMoveBarLevel) {
					thisBarColour = themeColour;

				// Move bar below this level, so only show if AlwaysShowMoveBar setting is true.
				} else if (alwaysShowMoveBar) {
					thisBarColour = meterBackgroundColour;

				// Otherwise, do not show this, or any higher level.
				} else {
					break;
				}

				Sys.println("drawBar " + i + " at x=" + x);
				drawBar(mBuffer.getDc(), thisBarColour, x, thisBarWidth);

				x += thisBarWidth + mSeparator;
			}

			mBufferNeedsRedraw = false;
		}

		// Draw whole move bar from buffer, vertically centred at mY.
		dc.setClip(mX, mY - (mHeight / 2), mWidth, mHeight);
		dc.drawBitmap(mX, mY - (mHeight / 2), mBuffer);
		dc.clearClip();		
	}

	function getBarWidth() {
		// Maximum number of bars actually shown.
		var numBars = ActivityMonitor.MOVE_BAR_LEVEL_MAX - ActivityMonitor.MOVE_BAR_LEVEL_MIN - 1;

		// Subtract tail width, and total separator width.
		var availableWidth = mWidth - mTailWidth - ((numBars - 1) * mSeparator);

		var barWidth = availableWidth / (numBars + /* First bar is double width */ 1);

		Sys.println("barWidth " + barWidth);
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

		points[0] = [x, halfHeight];
		points[1] = [x - mTailWidth, 0];
		points[2] = [x - mTailWidth + width, 0];
		points[3] = [x + width, halfHeight];
		points[4] = [x - mTailWidth + width - /* Inclusive? */ 1, mHeight];
		points[5] = [x - mTailWidth - /* Inclusive? */ 1, mHeight];

		dc.setColor(colour, Graphics.COLOR_TRANSPARENT);
		dc.fillPolygon(points);
	}
}