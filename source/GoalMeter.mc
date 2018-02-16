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

	private var mCurrentValue = 0;
	private var mMaxValue = 100;

	private var mLastColour;

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
	}
	
	function draw(dc) {
		var segments = getSegments();

		dc.setPenWidth(mStroke);
		
		var bottom = dc.getHeight() - ((dc.getHeight() - mHeight) / 2);
		var height, fillHeight;

		for (var i = 0; i < segments.size(); ++i) {
			height = segments[i][:height];
			fillHeight = segments[i][:fillHeight];

			// Fully filled segment.
			if (fillHeight == height) {

				drawSegment(dc, bottom, height, App.getApp().getProperty("ThemeColour"));
			
			// Partially filled segment.
			} else if (fillHeight > 0) {
				
				drawSegment(dc, bottom, fillHeight, App.getApp().getProperty("ThemeColour"));
				drawSegment(dc, bottom - fillHeight, height - fillHeight, App.getApp().getProperty("MonoDarkColour"));

			// Empty segment.
			} else {

				drawSegment(dc, bottom, height, App.getApp().getProperty("MonoDarkColour"));
			}

			// Separator.
			bottom -= height + mSeparator;
		}

		// drawSegment() may set clip.
		dc.clearClip();
	}

	function drawSegment(dc, bottom, height, colour) {

		// Set DC colour if different from current DC colour.
		if (colour != mLastColour) {
			mLastColour = colour;
			dc.setColor(colour, Graphics.COLOR_TRANSPARENT);
		}

		var top = bottom - height;
		var left, right;

		var halfDCWidth = dc.getWidth() / 2;
		var halfDCHeight = dc.getHeight() / 2;

		if (mSide == :left) {
			left = 0;
		} else {
			left = halfDCWidth;
		}

		if (mShape == :arc) {
			dc.setClip(left, top, halfDCWidth, height);
			dc.drawCircle(halfDCWidth, halfDCHeight, halfDCWidth - mMargin - (mStroke / 2));
		} else {
			// TODO.
		}
	}

	function setValues(current, max) {
		mCurrentValue = current;
		mMaxValue = max;
	}

	// Return array of dictionaries, one per segment. Each dictionary describes height and fill height of segment.
	// Last segment may be partial segment; if so, must adhere to minimum segment height.
	// Segment heights rounded to nearest pixel, so neighbouring whole segments may differ in height by a pixel.
	function getSegments() {
		var segmentScale = getSegmentScale(); // Value each whole segment represents.
		var numSegments = mMaxValue * 1.0 / segmentScale; // Including any partial. Force floating-point division.

		var totalSegmentHeight = mHeight; // Start with full meter height.
		var numSeparators = Math.ceil(numSegments) - 1; // Subtract total separator height.
		totalSegmentHeight -= numSeparators * mSeparator;

		// Partial last segment handling.
		var totalWholeSegmentHeight = totalSegmentHeight;
		var hasPartialLastSegment = (numSegments != Math.round(numSegments));
		var partialLastSegmentHeight = 0;
		if (hasPartialLastSegment) {
			// "(numSegments % 1) * segmentHeight" doesn't work because % expects Number/Long, not Number/Float.
			// partialLastSegmentHeight = fractionalPartOfNumSegments * segmentHeight;
			partialLastSegmentHeight = (numSegments - Math.floor(numSegments)) * (totalSegmentHeight / numSegments);
			partialLastSegmentHeight = Math.round(partialLastSegmentHeight);

			// Enforce minimum partial last segment height.
			if (partialLastSegmentHeight < MIN_SEGMENT_HEIGHT) {
				partialLastSegmentHeight = MIN_SEGMENT_HEIGHT;
			}
			Sys.println("partialLastSegmentHeight " + partialLastSegmentHeight);
			totalWholeSegmentHeight -= partialLastSegmentHeight;
		}
		Sys.println("totalWholeSegmentHeight " + totalWholeSegmentHeight);
		
		var segmentHeight = totalWholeSegmentHeight * 1.0 / Math.floor(numSegments); // Force floating-point division.
		Sys.println("segmentHeight " + segmentHeight);

		// floor() to ensure meter is full only on genuine goal completion.
		var remainingFillHeight = Math.floor((mCurrentValue * 1.0 / mMaxValue) * totalSegmentHeight);
		Sys.println("remainingFillHeight " + remainingFillHeight);

		var segments = new [Math.ceil(numSegments)];
		var start, end, height, fillHeight;
		var isPartialLastSegment;
		for (var i = 0; i < segments.size(); ++i) {
			start = Math.round(i * segmentHeight);
			end = Math.round((i + 1) * segmentHeight);
			
			// If there is a partial last segment, and this is the last segment.
			isPartialLastSegment = hasPartialLastSegment && (i == (segments.size() - 1));

			if (isPartialLastSegment) {
				height = partialLastSegmentHeight;
			} else {
				height = end - start;
			}		

			// Fully filled segment.
			if (remainingFillHeight > height) {
				fillHeight = height;
			//} else if (isPartialLastSegment) {

			// Partially filled segment.
			} else if (remainingFillHeight > 0) {
				fillHeight = remainingFillHeight;

			// Empty segment.
			} else {
				fillHeight = 0;
			}

			segments[i] = {};
			segments[i][:height] = height;
			segments[i][:fillHeight] = fillHeight;
			Sys.println("segment " + i + " height " + segments[i][:height] + " fillHeight " + segments[i][:fillHeight]);

			remainingFillHeight -= height;
			Sys.println("remainingFillHeight " + remainingFillHeight);
		}

		return segments;
	}

	// Determine what value each whole segment represents.
	// Try a scale of 1, 2, 5, 10, 20, 50, 100, 200, 500, 1000, 2000, 5000... until dividing mMaxValue by that scale gives a whole
	// number of segments that is less than or equal to MAX_WHOLE_SEGMENTS.
	function getSegmentScale() {
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
}