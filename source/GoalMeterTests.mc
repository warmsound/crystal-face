/*
var DEFAULT_PARAMS = {
	:side => :left,
	:shape => :arc,
	:margin => 8,
	:stroke => 8,
	:height => 160,
	:separator => 1
};


function testGetSegmentScale(max, expectedResult, logger) {
	var goalMeter = new GoalMeter(DEFAULT_PARAMS);
	goalMeter.setValues(0, max);
	var scale = goalMeter.getSegmentScale();
	logger.debug("scale is " + scale + ", expected " + expectedResult);
	return (scale == expectedResult);
}

(:test)
function getSegmentScaleShouldHandle1(logger) {
	return testGetSegmentScale(1, 1, logger);
}

(:test)
function getSegmentScaleShouldHandle2(logger) {
	return testGetSegmentScale(2, 1, logger);
}

(:test)
function getSegmentScaleShouldHandle5(logger) {
	return testGetSegmentScale(5, 1, logger);
}

(:test)
function getSegmentScaleShouldHandle10(logger) {
	return testGetSegmentScale(10, 1, logger);
}

(:test)
function getSegmentScaleShouldHandle15(logger) {
	return testGetSegmentScale(15, 2, logger);
}


function testGetSegments(current, max, expectedFillHeights, expectedHeights, logger) {
	var pass = true;

	var goalMeter = new GoalMeter(DEFAULT_PARAMS);
	goalMeter.setValues(current, max);

	var segments = goalMeter.getSegments();
	logger.debug(segments.size() + " segments returned, expected " + expectedFillHeights.size());

	if ((expectedFillHeights.size() != expectedHeights.size()) ||
		(segments.size() != expectedFillHeights.size())) {
		     
		pass = false;

	} else {

		for (var i = 0; i < segments.size(); ++i) {
			logger.debug("segment " + i + ": " + segments[i][:fillHeight] + "/" + segments[i][:height] +
				", expected " + expectedFillHeights[i] + "/" + expectedHeights[i]);

			if ((segments[i][:fillHeight] != expectedFillHeights[i]) ||
				(segments[i][:height] != expectedHeights[i])) {

				pass = false;
				// Don't break here, to allow all segments to be logged.
			}
		}
	}

	return pass;
}

(:test)
function getSegmentsShouldHandle1Segment(logger) {
	return testGetSegments(0, 1, [0], [160], logger);
}

(:test)
function getSegmentsShouldHandle2Segments(logger) {
	return testGetSegments(0, 2, [0, 0], [80, 79], logger);
}

(:test)
function getSegmentsShouldHandle2SegmentsWithPartial(logger) {
	return testGetSegments(0, 1.25, [0, 0], [127, 32], logger);
}

(:test)
function getSegmentsShouldHandle2SegmentsWithMinPartial(logger) {
	return testGetSegments(0, 1.001, [0, 0], [158, 1], logger);
}

(:test)
function getSegmentsShouldHandle6OutOf10(logger) {
	return testGetSegments(6, 10, [14, 14, 15, 14, 14, 14, 0, 0, 0, 0], [14, 14, 15, 14, 14, 14, 14, 15, 14, 14], logger);
}
*/
