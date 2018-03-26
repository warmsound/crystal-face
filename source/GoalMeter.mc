using Toybox.WatchUi as Ui;
using Toybox.System as Sys;
using Toybox.Application as App;

// Buffered drawing behaviour:
// - On initialisation: calculate clip width (non-trivial for arc shape); create buffers for empty and filled segments.
// - On setting current/max values: if max changes, re-calculate segment layout and set dirty buffer flag; if current changes, re-
//   calculate fill height.
// - On draw: if buffers are dirty, redraw them and clear flag; clip appropriate portion of each buffer to screen. Each buffer
//   contains all segments in appropriate colour, with separators. Maximum of 2 draws to screen on each draw() cycle.
class GoalMeter extends Ui.Drawable {

	private var mSide; // :left, :right.
	private var mShape; // :arc, :line.
	private var mStroke; // Stroke width.
	private var mWidth; // Clip width of meter.
	private var mHeight; // Clip height of meter.
	private var mSeparator; // Stroke width of separator bars.

	private var mFilledBuffer; // Bitmap buffer containing all full segments;
	private var mEmptyBuffer; // Bitmap buffer containing all empty segments;
	private var mSegments; // Array of segment heights, in pixels, excluding separators.
	private var mFillHeight; // Total height of filled segments, in pixels, including separators.

	private var mBuffersNeedRecreate = true; // Buffers need to be recreated on next draw() cycle.
	private var mBuffersNeedRedraw = true; // Buffers need to be redrawn on next draw() cycle.

	private var mCurrentValue;
	private var mMaxValue;

	private const SEGMENT_SCALES = [1, 10, 100, 1000, 10000];
	private const MIN_WHOLE_SEGMENT_HEIGHT = 5;

	function initialize(params) {
		Drawable.initialize(params);

		mSide = params[:side];
		mShape = params[:shape];
		mStroke = params[:stroke];
		mHeight = params[:height];
		mSeparator = params[:separator];

		mWidth = getWidth();
	}

	function setValues(current, max) {

		// If max value changes, recalculate and cache segment layout, and set mBuffersNeedRedraw flag. Can't redraw buffers here,
		// as we don't have reference to screen DC, in order to determine its dimensions - do this later, in draw() (already in
		// draw cycle, so no real benefit in fetching screen width). Clear current value to force recalculation of fillHeight.
		if (max != mMaxValue) {
			mMaxValue = max;
			mCurrentValue = null;

			mSegments = getSegments();
			mBuffersNeedRedraw = true;
		}

		// If current value changes, recalculate fill height, ahead of draw().
		if (current != mCurrentValue) {
			mCurrentValue = current;
			mFillHeight = getFillHeight(mSegments);			
		}		
	}

	function onSettingsChanged() {
		mBuffersNeedRecreate = true;
	}

	// Redraw buffers if dirty, then draw from buffer to screen: from filled buffer up to fill height, then from empty buffer for
	// remaining height.
	function draw(dc) {
		var left;
		var top;

		var clipBottom;
		var clipTop;
		var clipHeight;		

		var dcHeight = dc.getHeight();

		var meterBackgroundColour = App.getApp().getProperty("MeterBackgroundColour");
		var themeColour = App.getApp().getProperty("ThemeColour");		

		// Recreate buffers only if this is the very first draw(), or if optimised colour palette has changed e.g. theme colour
		// change.
		if (mBuffersNeedRecreate) {
			mEmptyBuffer = createSegmentBuffer(meterBackgroundColour);
			mFilledBuffer = createSegmentBuffer(themeColour);
			mBuffersNeedRecreate = false;
			mBuffersNeedRedraw = true; // Ensure newly-created buffers are drawn next.
		}

		// Redraw buffers only if maximum value changes.
		if (mBuffersNeedRedraw) {
			drawBuffer(dc, mEmptyBuffer.getDc(), meterBackgroundColour, mSegments);			
			drawBuffer(dc, mFilledBuffer.getDc(), themeColour, mSegments);			
			mBuffersNeedRedraw = false;
		}

		if (mSide == :left) {
			left = 0;
		} else {
			left = dc.getWidth() - mWidth;
		}

		top = (dcHeight - mHeight) / 2;

		// Draw filled segments.		
		clipBottom = dcHeight - top;
		clipTop = clipBottom - mFillHeight - 1;
		clipHeight = clipBottom - clipTop;

		if (clipHeight > 0) {
			dc.setClip(left, clipTop, mWidth, clipHeight);
			dc.drawBitmap(left, top, mFilledBuffer);
		}

		// Draw unfilled segments.
		clipBottom = clipTop;
		clipTop = top;
		clipHeight = clipBottom - clipTop;

		if (clipHeight > 0) {
			dc.setClip(left, clipTop, mWidth, clipHeight);
			dc.drawBitmap(left, top, mEmptyBuffer);
		}

		dc.clearClip();
	}

	function getWidth() {
		var width;
		
		var halfScreenWidth;
		var innerRadius;

		if (mShape == :arc) {
			halfScreenWidth = Sys.getDeviceSettings().screenWidth / 2; // DC not available; OK to use screenWidth from settings?
			innerRadius = halfScreenWidth - mStroke; 
			width = halfScreenWidth - Math.sqrt(Math.pow(innerRadius, 2) - Math.pow(mHeight / 2, 2));
			width = Math.ceil(width); // Round up to cover partial pixels.
		} else {
			width = mStroke;
		}

		return width;
	}

	// Use restricted palette, to conserve memory (four buffers per watchface).
	function createSegmentBuffer(fillColour) {
		return new Graphics.BufferedBitmap({
			:width => mWidth,
			:height => mHeight,

			// First palette colour appears to determine initial colour of buffer.
			:palette => [App.getApp().getProperty("BackgroundColour"), fillColour]
		});
	}

	// bufferDc is the same size as meter clip rectangle: mWidth calculated on initialisation, mHeight from layout param.
	function drawBuffer(screenDc, bufferDc, fillColour, segments) {
		var halfScreenDcWidth = screenDc.getWidth() / 2.0;
		var bufferDcWidth = bufferDc.getWidth();
		var halfBufferDcHeight = bufferDc.getHeight() / 2.0;

		var circleCentreX;
		var radius;

		var separatorY;

		// Draw meter fill.
		bufferDc.setColor(fillColour, Graphics.COLOR_TRANSPARENT /* Graphics.COLOR_RED */);
		//bufferDc.clear();
		bufferDc.setPenWidth(mStroke);

		if (mShape == :arc) {

			if (mSide == :left) {
				circleCentreX = halfScreenDcWidth; // Beyond right edge of bufferDc.
			} else {
				circleCentreX = mWidth - halfScreenDcWidth; // Beyond left edge of bufferDc.
			}

			radius = halfScreenDcWidth - (mStroke / 2.0);

			// Previously attempted to use drawArc() to minimise drawing calculations, but does not track edge of round screen as
			// well as drawCircle() - different algorithms!
			bufferDc.drawCircle(circleCentreX, halfBufferDcHeight, radius);

		} else {
			bufferDc.fillRectangle(0, 0, mWidth, mHeight);
		}

		// Draw separators: horizontal transparent lines across meter fill.
		// Drawing transparent lines should be faster than drawing clipped filled arcs.
		bufferDc.setColor(App.getApp().getProperty("BackgroundColour"), Graphics.COLOR_TRANSPARENT);
		bufferDc.setPenWidth(mSeparator);

		// Skip segment, draw separator, skip separator... starting from the bottom, working upwards.
		separatorY = bufferDc.getHeight();
		for (var i = 0; i < segments.size(); ++i) {
			separatorY -= segments[i];

			bufferDc.drawLine(0, separatorY, bufferDcWidth, separatorY);

			separatorY -= mSeparator;
		}
	}

	// Return array of segment heights.
	// Last segment may be partial segment; if so, ensure its height is at least 1 pixel.
	// Segment heights rounded to nearest pixel, so neighbouring whole segments may differ in height by a pixel.
	function getSegments() {
		var segmentScale = getSegmentScale(); // Value each whole segment represents.

		var numSegments = mMaxValue * 1.0 / segmentScale; // Including any partial. Force floating-point division.
		var numSeparators = Math.ceil(numSegments) - 1;

		var totalSegmentHeight = mHeight - (numSeparators * mSeparator); // Subtract total separator height from full height.		
		var segmentHeight = totalSegmentHeight * 1.0 / numSegments; // Force floating-point division.
		Sys.println("segmentHeight " + segmentHeight);

		var segments = new [Math.ceil(numSegments)];
		var start, end, height;

		for (var i = 0; i < segments.size(); ++i) {
			start = Math.round(i * segmentHeight);
			end = Math.round((i + 1) * segmentHeight);

			// Last segment is partial.
			if (end > totalSegmentHeight) {
				end = totalSegmentHeight;
			}

			height = end - start;

			segments[i] = height;
			Sys.println("segment " + i + " height " + height);
		}

		return segments;
	}

	function getFillHeight(segments) {
		var fillHeight;

		var i;

		var totalSegmentHeight = 0;
		for (i = 0; i < segments.size(); ++i) {
			totalSegmentHeight += segments[i];
		}

		var remainingFillHeight = Math.round((mCurrentValue * 1.0 / mMaxValue) * totalSegmentHeight); // Excluding separators.
		fillHeight = remainingFillHeight;

		for (i = 0; i < segments.size(); ++i) {
			remainingFillHeight -= segments[i];
			if (remainingFillHeight > 0) {
				fillHeight += mSeparator; // Fill extends beyond end of this segment, so add separator height.
			} else {
				break; // Fill does not extend beyond end of this sgement, because this segment is not full.
			}			
		}

		return fillHeight;
	}

	// Determine what value each whole segment represents.
	// Try each scale in SEGMENT_SCALES array, until MIN_SEGMENT_HEIGHT is breached.
	function getSegmentScale() {
		var segmentScale;

		var tryScaleIndex = 0;		
		var segmentHeight;
		var numSegments;
		var numSeparators;
		var totalSegmentHeight;

		do {
			segmentScale = SEGMENT_SCALES[tryScaleIndex];

			numSegments = mMaxValue * 1.0 / segmentScale;
			numSeparators = Math.ceil(numSegments);
			totalSegmentHeight = mHeight - (numSeparators * mSeparator);
			segmentHeight = Math.floor(totalSegmentHeight / numSegments);

			tryScaleIndex++;	
		} while (segmentHeight <= MIN_WHOLE_SEGMENT_HEIGHT);

		Sys.println("scale " + segmentScale);
		return segmentScale;
	}
}