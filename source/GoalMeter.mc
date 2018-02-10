using Toybox.WatchUi as Ui;
using Toybox.System as Sys;
using Toybox.Application as App;

class GoalMeter extends Ui.Drawable {

	private var mSide; // :left, :right.
	private var mShape; // :arc, :line.
	private var mMargin; // Margin between outer edge of stroke and edge of DC.
	private var mStroke; // Stroke width.
	private var mHeight; // Total height of meter.
	private var mSeparator; // Stroke width of separator bars.

	private var mCurrentValue = 3500.0;
	private var mMaxValue = 7200.0;

	private const MAX_WHOLE_SEGMENTS = 10;
	private const SEGMENT_SCALES = [1, 2, 5];
	private const MIN_SEGMENT_HEIGHT = 1;

	function initialize(params) {
		Drawable.initialize(params);

		mSide = params[:side];
		mShape = params[:shape];
		mMargin = params[:margin];
		mStroke = params[:stroke];
		mHeight = params[:height];
		mSeparator = params[:separator];
		
		getSegmentHeights();
	}
	
	function draw(dc) {
		var highlightColour = App.getApp().getProperty("HighlightColour");
		dc.setColor(highlightColour, Graphics.COLOR_TRANSPARENT);
		dc.setPenWidth(mStroke);

		var top = (dc.getHeight() - mHeight) / 2;

		if (mSide == :left) {
			dc.setClip(0, top, dc.getWidth() / 2, mHeight);
		}
		
		dc.drawCircle(dc.getWidth() / 2, dc.getHeight() / 2, dc.getWidth() / 2 - mMargin - (mStroke / 2));
	}

	function setValue(current, max) {
	}


	private function getSegmentHeights() {
		var segmentScale = getSegmentScale(); // Value each whole segment represents.
		var numSegments = mMaxValue / segmentScale; // Including any partial.

		var availableHeight = mHeight; // Start with full meter height.
		var numSeparators = Math.ceil(numSegments) - 1; // Subtract total separator height.
		availableHeight -= numSeparators * mSeparator;

		// Partial last segment handling.
		var hasPartialLastSegment = (numSegments != Math.round(numSegments));
		var partialLastSegmentHeight = 0;
		if (hasPartialLastSegment) {
			// "(numSegments % 1) * segmentHeight" doesn't work because % expects Number/Long, not Number/Float.
			// partialLastSegmentHeight = fractionalPartOfNumSgements * segmentHeight;
			partialLastSegmentHeight = (numSegments - Math.floor(numSegments)) * (availableHeight / numSegments);
			partialLastSegmentHeight = Math.round(partialLastSegmentHeight);

			// Enforce minimum partial last segment height.
			if (partialLastSegmentHeight < MIN_SEGMENT_HEIGHT) {
				partialLastSegmentHeight = MIN_SEGMENT_HEIGHT;
			}
			Sys.println("partialLastSegmentHeight " + partialLastSegmentHeight);
			availableHeight -= partialLastSegmentHeight;
		}

		var segmentHeight = availableHeight / Math.floor(numSegments); // With any adjustment for partial last segment height.
		Sys.println("segmentHeight " + segmentHeight);		

		var segmentHeights = new [Math.ceil(numSegments)];
		var segmentStart, segmentEnd;
		for (var i = 0; i < config.size(); ++i) {
			segmentStart = Math.round(i * segmentHeight);
			segmentEnd = Math.round((i + 1) * segmentHeight);
			
			// If there is a partial last segment, and this is the last segment.
			if (hasPartialLastSegment && (i == (config.size() - 1))) {
				segmentHeights[i] = partialLastSegmentHeight;
			} else {
				segmentHeights[i] = segmentEnd - segmentStart;
			}
			
			Sys.println("config " + i + " " + config[i]);
		}

		return segmentHeights;
	}

	// Determine what value each whole segment represents.
	// Try a scale of 1, 2, 5, 10, 20, 50, 100, 200, 500, 1000, 2000, 5000... until dividing mMaxValue by that scale gives a whole
	// number of segments that is less than or equal to MAX_WHOLE_SEGMENTS.
	private function getSegmentScale() {
		var scale = 1;
		var scaleFound = false;
		var tryScaleIndex, tryScale;
		var magnitude;

		// 1, 10, 100, 1000...
		for (magnitude = 1; !scaleFound; magnitude *= 10) {

			// 0, 1, 2...
			for (tryScaleIndex = 0; !scaleFound && (tryScaleIndex < SEGMENT_SCALES.size()); ++tryScaleIndex) {

				// 1, 2, 5.
				tryScale = SEGMENT_SCALES[tryScaleIndex];

				// 1, 2, 5, 10, 20, 50...
				scale = magnitude * tryScale;

				if (Math.floor(mMaxValue / scale) <= MAX_WHOLE_SEGMENTS) {
					scaleFound = true; // double break;
				}
			}
		}

		Sys.println("scale " + scale);
		return scale;	
	}

	// Determine height of each whole segment in pixels.
	// Topmost segment may be partial. If so, must be at least MIN_SEGMENT_HEIGHT high.
	private function getSegmentHeight() {
	}
}