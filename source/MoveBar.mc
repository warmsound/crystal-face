using Toybox.WatchUi as Ui;
using Toybox.System as Sys;
using Toybox.Application as App;
using Toybox.ActivityMonitor as ActivityMonitor;
using Toybox.Graphics;

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

	// private enum /* MOVE_BAR_STYLE */ {
	// 	SHOW_ALL_SEGMENTS,
	// 	SHOW_FILLED_SEGMENTS,
	// 	HIDDEN
	// };

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
		if (App.getApp().getProperty("MoveBarStyle") == 2 /* HIDDEN */) {
			return;
		}

		var info = ActivityMonitor.getInfo();
		var currentMoveBarLevel = info.moveBarLevel;

		// Calculate current width here, now that DC is accessible.
		if (mIsFullWidth) {
			mCurrentWidth = dc.getWidth() - (2 * mX) + mTailWidth; // Balance head/tail positions.
		} else {
			mCurrentWidth = mBaseWidth;
		}

		// #21 Force unbuffered drawing on fr735xt (CIQ 2.x) to reduce memory usage.
		if ((Graphics has :BufferedBitmap) && (Sys.getDeviceSettings().screenShape != Sys.SCREEN_SHAPE_SEMI_ROUND)) {
			drawBuffered(dc, currentMoveBarLevel);
		} else {
			//drawUnbuffered(dc, currentMoveBarLevel);

			// Draw bars vertically centred on mY.
			drawBars(dc, mX, mY - (mHeight / 2),  currentMoveBarLevel);
		}		
	}

	(:buffered)
	function drawBuffered(dc, currentMoveBarLevel) {
		// Recreate buffers if this is the very first draw(), if optimised colour palette has changed e.g. theme colour change, or
		// move bar width changes from base width to full width.
		if (mBufferNeedsRecreate) {
			recreateBuffer();
		}

		// #7 Redraw buffer (only) if move bar level changes.
		if (currentMoveBarLevel != mLastMoveBarLevel) {
			mLastMoveBarLevel = currentMoveBarLevel;
			mBufferNeedsRedraw = true;
		}
		
		if (mBufferNeedsRedraw) {
			var bufferDc = mBuffer.getDc();

			// #85: Clear buffer before any redraw, so that move bar clears correctly in "Show Filled Segments" mode (no bars will
			// be drawn in this mode when move bar clears). Does not seem possible to clear with COLOR_TRANSPARENT, so use
			// background colour instead.
			bufferDc.setColor(Graphics.COLOR_TRANSPARENT, gBackgroundColour);
			bufferDc.clear();

			// Draw bars at top left of buffer.
			drawBars(bufferDc, 0, 0, currentMoveBarLevel);
			mBufferNeedsRedraw = false;
		}

		// Draw whole move bar from buffer, vertically centred at mY. 
		dc.setClip(mX, mY - (mHeight / 2), mCurrentWidth, mHeight);
		dc.drawBitmap(mX, mY - (mHeight / 2), mBuffer);
		dc.clearClip();	
	}

	(:buffered)
	function recreateBuffer() {
		mBuffer = new Graphics.BufferedBitmap({
			:width => mCurrentWidth,
			:height => mHeight,

			// First palette colour appears to determine initial colour of buffer.
			:palette => [gBackgroundColour, gMeterBackgroundColour, gThemeColour]
		});
		mBufferNeedsRecreate = false;
		mBufferNeedsRedraw = true; // Ensure newly-created buffer is drawn next.
	}

	// Draw bars to supplied DC: screen or buffer, depending on drawing mode.
	// x and y are co-ordinates of top-left corner of move bar.
	function drawBars(dc, x, y, currentMoveBarLevel) {
		var barWidth = getBarWidth();
		var thisBarWidth;
		var thisBarColour = 0;
		var barX = x + mTailWidth;
		var moveBarStyle = App.getApp().getProperty("MoveBarStyle");

		// One-based, to correspond with move bar level (zero means no bars).
		for (var i = 1; i <= ActivityMonitor.MOVE_BAR_LEVEL_MAX; ++i) {

			// First bar is double width.
			if (i == 1) {
				thisBarWidth = 2 * barWidth;
			} else {
				thisBarWidth = barWidth;
			}

			// Move bar at this level or greater, so show regardless of MoveBarStyle setting.
			if (i <= currentMoveBarLevel) {
				thisBarColour = gThemeColour;

			// Move bar below this level, so only show if MoveBarStyle setting is SHOW_ALL_SEGMENTS.
			} else if (moveBarStyle == 0 /* SHOW_ALL_SEGMENTS */) {
				thisBarColour = gMeterBackgroundColour;

			// Otherwise, do not show this, or any higher level.
			} else {
				break;
			}

			//Sys.println("drawBar " + i + " at x=" + barX);
			drawBar(dc, thisBarColour, barX, y + (mHeight / 2), thisBarWidth);

			barX += thisBarWidth + mSeparator;
		}
	}

	function getBarWidth() {
		// Maximum number of bars actually shown.
		var numBars = ActivityMonitor.MOVE_BAR_LEVEL_MAX - ActivityMonitor.MOVE_BAR_LEVEL_MIN;

		// Subtract tail width, and total separator width.
		var availableWidth = mCurrentWidth - mTailWidth - ((numBars - 1) * mSeparator);

		var barWidth = availableWidth / (numBars + /* First bar is double width */ 1);

		//Sys.println("barWidth " + barWidth);
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
		width = width - 1; // E.g. width 5 covers pixels 0 to 4.

		points[0] = [x                     , y];
		points[1] = [x - mTailWidth        , y - halfHeight];
		points[2] = [x - mTailWidth + width, y - halfHeight];
		points[3] = [x              + width, y];
		points[4] = [x - mTailWidth + width, y + halfHeight];
		points[5] = [x - mTailWidth        , y + halfHeight];

		dc.setColor(colour, Graphics.COLOR_TRANSPARENT);
		dc.fillPolygon(points);
	}
}