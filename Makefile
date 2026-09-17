.PHONY: project validate assets ipa signed-ipa clean

project:
	python3 Tools/generate_xcodeproj.py

validate:
	python3 Tools/validate_xcodeproj.py

assets:
	python3 Tools/generate_assets.py

ipa:
	./Tools/build_unsigned_ipa.sh

signed-ipa:
	./Tools/build_signed_ipa.sh

clean:
	rm -rf build build-sim payload
