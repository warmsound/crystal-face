include properties.mk

appName = `./application.py`
supportDevices = `./devices.py`

build:
	$(SDK_HOME)/bin/monkeyc \
	--jungles ./monkey.jungle \
	--device $(DEVICE) \
	--output bin/$(appName).prg \
	--private-key $(PRIVATE_KEY) \
	--unit-test \
	--warn

buildall:
	@for device in $(supportDevices); do \
		echo "-----"; \
		echo "Building for" $$device; \
    		$(SDK_HOME)/bin/monkeyc \
		--jungles ./monkey.jungle \
		--device $$device \
		--output bin/$(appName)-$$device.prg \
		--private-key $(PRIVATE_KEY) \
		--warn; \
	done

test: build
	@./test.sh

run: build
	@$(SDK_HOME)/bin/connectiq &
	sleep 3 &&\
	$(SDK_HOME)/bin/monkeydo bin/$(appName).prg $(DEVICE)

deploy: build
	@cp bin/$(appName).prg $(DEPLOY)

package:
	@$(SDK_HOME)/bin/monkeyc \
	--jungles ./monkey.jungle \
	--package-app \
	--release \
	--output bin/$(appName).iq \
	--private-key $(PRIVATE_KEY) \
	--warn

packaged:
	@$(SDK_HOME)/bin/monkeyc \
	--jungles ./monkey.jungle \
	--package-app \
	--debug \
	--output bin/$(appName).iq \
	--private-key $(PRIVATE_KEY) \
	--warn

