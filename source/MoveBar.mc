using Toybox.WatchUi as Ui;
using Toybox.System as Sys;
using Toybox.Application as App;
using Toybox.ActivityMonitor as ActivityMonitor;

private var MOVE_BAR_STYLE = {
	0 => :SHOW_ALL_SEGMENTS,
	1 => :SHOW_FILLED_SEGMENTS,
	2 => :HIDDEN
};

class MoveBar extends Ui.Drawable {

	private var mX, mY, mBaseWidth, mHeight, mSeparator;
	private var mTailWidth;	

	(:buffered) private var mBuffer;	
	(:buffered) private var mBufferNeedsRedraw = true;
	(:buffered) private var mLastMoveBarLevel;

	private var mBufferNeedsRecreate = true; // Used in common code: do not exclude.

	// If set to true, move bar should be horizontally centred on the DC, with left end at mX.
	// This is used when a watch face does not support per-second updates, and the seconds are therefore hidden in sleep mode.
	private var mIsFullWidth = false;

	// Either mBaseWidth, or a calculated full width.
	private var mCurrentWidth;

	function initialize(params) {
		Drawable.initialize(params);
		
		mX = params[:x];
		mY = params[:y];
		mBaseWidth = params[:width]; // mCurrentWidth calculated at start of draw(), when DC is available.
		mHeight = params[:height];
		mSeparator = params[:separator];

		mTailWidth = mHeight / 2;
	}

	function onSettingsChanged() {
		mBufferNeedsRecreate = true;
	}

	function setFullWidth(fullWidth) {
		if (mIsFullWidth != fullWidth) {
			mIsFullWidth = fullWidth;
			mBufferNeedsRecreate = true;
		}
	}
	
	function draw(dc) {
		if (MOVE_BAR_STYLE[App.getApp().getProperty("MoveBarStyle")] == :HIDDEN) {
			return;
		}

		var info = ActivityMonitor.getInfo();
		var currentMoveBarLevel = info.moveBarLevel;

		var themeColour = App.getApp().getProperty("ThemeColour");
		var meterBackgroundColour = App.getApp().getProperty("MeterBackgroundColour");

		// Calculate current width here, now that DC is accessible.
		if (mIsFullWidth) {
			mCurrentWidth = dc.getWidth() - (2 * mX) + mTailWidth; // Balance head/tail positions.
		} else {
			mCurrentWidth = mBaseWidth;
		}

		// #21 Force unbuffered drawing on fr735xt (CIQ 2.x) to reduce memory usage.
		if ((Graphics has :BufferedBitmap) && (Sys.getDeviceSettings().screenShape != Sys.SCREEN_SHAPE_SEMI_ROUND)) {
			drawBuffered(dc, currentMoveBarLevel, themeColour, meterBackgroundColour);
		} else {
			drawUnbuffered(dc, currentMoveBarLevel, themeColour, meterBackgroundColour);
		}		
	}

	function drawUnbuffered(dc, currentMoveBarLevel, themeColour, meterBackgroundColour) {
		// Draw bars vertically centred on mY.
		drawBars(dc, mX, mY - (mHeight / 2),  currentMoveBarLevel, themeColour, meterBackgroundColour);
	}

	(:buffered)
	function drawBuffered(dc, currentMoveBarLevel, themeColour, meterBackgroundColour) {
		// Recreate buffers if this is the very first draw(), if optimised colour palette has changed e.g. theme colour change, or
		// move bar width changes from base width to full width.
		if (mBufferNeedsRecreate) {
			recreateBuffer(themeColour, meterBackgroundColour);
		}

		// #7 Redraw buffer (only) if move bar level changes.
		if (currentMoveBarLevel != mLastMoveBarLevel) {
			mLastMoveBarLevel = currentMoveBarLevel;
			mBufferNeedsRedraw = true;
		}
		
		if (mBufferNeedsRedraw) {
			// Draw bars at top left of buffer.
			drawBars(mBuffer.getDc(), 0, 0, currentMoveBarLevel, themeColour, meterBackgroundColour);
			mBufferNeedsRedraw = false;
		}

		// Draw whole move bar from buffer, vertically centred at mY. 
		dc.setClip(mX, mY - (mHeight / 2), mCurrentWidth, mHeight);
		dc.drawBitmap(mX, mY - (mHeight / 2), mBuffer);
		dc.clearClip();	
	}

	(:buffered)
	function recreateBuffer(themeColour, meterBackgroundColour) {
		mBuffer = new Graphics.BufferedBitmap({
			:width => mCurrentWidth,
			:height => mHeight,

			// First palette colour appears to determine initial colour of buffer.
			:palette => [Graphics.COLOR_TRANSPARENT, meterBackgroundColour, themeColour]
		});
		mBufferNeedsRecreate = false;
		mBufferNeedsRedraw = true; // Ensure newly-created buffer is drawn next.
	}

	// Draw bars to supplied DC: screen or buffer, depending on drawing mode.
	// x and y are co-ordinates of top-left corner of move bar.
	function drawBars(dc, x, y, currentMoveBarLevel, themeColour, meterBackgroundColour) {
		var barWidth = getBarWidth();
		var thisBarWidth;
		var thisBarColour = 0;
		var barX = x + mTailWidth;
		var moveBarStyle = MOVE_BAR_STYLE[App.getApp().getProperty("MoveBarStyle")];

		for (var i = 1; i < ActivityMonitor.MOVE_BAR_LEVEL_MAX; ++i) {

			// First bar is double width.
			if (i == 1) {
				thisBarWidth = 2 * barWidth;
			} else {
				thisBarWidth = barWidth;
			}

			// Move bar at this level or greater, so show regardless of MoveBarStyle setting.
			if (i <= currentMoveBarLevel) {
				thisBarColour = themeColour;

			// Move bar below this level, so only show if MoveBarStyle setting is SHOW_ALL_SEGMENTS.
			} else if (moveBarStyle == :SHOW_ALL_SEGMENTS) {
				thisBarColour = meterBackgroundColour;

			// Otherwise, do not show this, or any higher level.
			} else {
				break;
			}

			Sys.println("drawBar " + i + " at x=" + x);
			drawBar(dc, thisBarColour, barX, y + (mHeight / 2), thisBarWidth);

			barX += thisBarWidth + mSeparator;
		}
	}

	function getBarWidth() {
		// Maximum number of bars actually shown.
		var numBars = ActivityMonitor.MOVE_BAR_LEVEL_MAX - ActivityMonitor.MOVE_BAR_LEVEL_MIN - 1;

		// Subtract tail width, and total separator width.
		var availableWidth = mCurrentWidth - mTailWidth - ((numBars - 1) * mSeparator);

		var barWidth = availableWidth / (numBars + /* First bar is double width */ 1);

		Sys.println("barWidth " + barWidth);
		return barWidth;
	}

	// ----------
	//  \        \
	//   x        x + width
	//  /        /
	// ----------
	//
	// x and y refer to bar origin, marked "x" in diagram above.
	function drawBar(dc, colour, x, y, width) {
		var points = new [6];
		var halfHeight = (mHeight / 2);

		points[0] = [x, y];
		points[1] = [x - mTailWidth, y - halfHeight];
		points[2] = [x - mTailWidth + width, y - halfHeight];
		points[3] = [x + width, y];
		points[4] = [x - mTailWidth + width - /* Inclusive? */ 1, y + halfHeight + /* Exclusive? */ 1];
		points[5] = [x - mTailWidth - /* Inclusive? */ 1, y + halfHeight + /* Exclusive? */ 1];

		dc.setColor(colour, Graphics.COLOR_TRANSPARENT);
		dc.fillPolygon(points);
	}
}