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
	logger.debug("scale is " + scale + ", expecting " + expectedResult);
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


function testGetSegmentHeights(max, expectedResult, logger) {
	var pass = true;

	var goalMeter = new GoalMeter(DEFAULT_PARAMS);
	goalMeter.setValues(0, max);
	var segmentHeights = goalMeter.getSegmentHeights();
	logger.debug(segmentHeights.size() + " segments returned, expected " + expectedResult.size());

	if (segmentHeights.size() != expectedResult.size()) {        
		pass = false;
	} else {
		for (var i = 0; i < segmentHeights.size(); ++i) {
			logger.debug("segment " + i + ": " + segmentHeights[i] + ", expected " + expectedResult[i]);
			if (segmentHeights[i] != expectedResult[i]) {
				pass = false;
				break;
			}
		}
	}

	return pass;
}

(:test)
function getSegmentHeightsShouldHandle1Segment(logger) {
	return testGetSegmentHeights(1, [160], logger);
}

(:test)
function getSegmentHeightsShouldHandle2Segments(logger) {
	return testGetSegmentHeights(2, [80, 79], logger);
}

(:test)
function getSegmentHeightsShouldHandle2SegmentsWithPartial(logger) {
	return testGetSegmentHeights(1.25, [127, 32], logger);
}

(:test)
function getSegmentHeightsShouldHandle2SegmentsWithMinPartial(logger) {
	return testGetSegmentHeights(1.001, [158, 1], logger);
}