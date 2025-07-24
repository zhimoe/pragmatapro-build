.PHONY: help, images
help: ## Show this help
	@egrep -h '\s##\s' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

images: ## Create Docker image dependencies
	make builder
	make scripter

builder: ## Create the `iosevka` builder Docker image
	docker build --no-cache -t iosevka/builder ./images/iosevka

scripter: ## Create the `fontforge` scripter Docker image
	docker build --no-cache -t fontforge/scripter ./images/fontforge

font: ## Run all build steps in correct order
	make --ignore-errors ttf
	make --ignore-errors nerd
	# make --ignore-errors package

ttf: ## Build ttf font from `Iosevka` custom configuration
	docker run --rm \
		-v Iosevka-volume:/builder/dist/Iosevka/TTF \
		-v $(CURDIR)/private-build-plans.toml:/builder/private-build-plans.toml \
		iosevka/builder \
		npm run build -- ttf::Iosevka
	docker run --rm \
		-v Iosevka-volume:/scripter \
		-v $(CURDIR)/punctuation.py:/scripter/punctuation.py \
		fontforge/scripter \
		python /scripter/punctuation.py ./Iosevka
	docker container create \
		-v Iosevka-volume:/ttf \
		--name Iosevka-dummy \
		alpine
	mkdir -p $(CURDIR)/dist/ttf
	docker cp Iosevka-dummy:/ttf $(CURDIR)/dist
	docker rm Iosevka-dummy
	docker volume rm Iosevka-volume
	rm -rf $(CURDIR)/dist/ttf/*semibold*.ttf
	rm -rf $(CURDIR)/dist/ttf/*black*.ttf
	rm -rf $(CURDIR)/dist/ttf/punctuation.py
	mv "$(CURDIR)/dist/ttf/Iosevka-normalbolditalic.ttf" "$(CURDIR)/dist/ttf/Iosevka-bolditalic.ttf"
	mv "$(CURDIR)/dist/ttf/Iosevka-normalboldupright.ttf" "$(CURDIR)/dist/ttf/Iosevka-bold.ttf"
	mv "$(CURDIR)/dist/ttf/Iosevka-normalregularitalic.ttf" "$(CURDIR)/dist/ttf/Iosevka-italic.ttf"
	mv "$(CURDIR)/dist/ttf/Iosevka-normalregularupright.ttf" "$(CURDIR)/dist/ttf/Iosevka-regular.ttf"

nerd: ## Patch with Nerd Fonts glyphs
	docker run --rm \
		-v $(CURDIR)/dist/ttf:/in \
		-v Iosevka-volume:/out \
		nerdfonts/patcher --complete --careful --mono
	docker container create \
		-v Iosevka-volume:/nerd \
		--name Iosevka-dummy \
		alpine
	docker cp Iosevka-dummy:/nerd $(CURDIR)/dist
	docker rm Iosevka-dummy
	docker volume rm Iosevka-volume
	mv "$(CURDIR)/dist/nerd/IosevkaNerdFontMono-Regular.ttf" "$(CURDIR)/dist/nerd/Iosevka-nf-regular.ttf"
	mv "$(CURDIR)/dist/nerd/IosevkaNerdFontMono-Italic.ttf" "$(CURDIR)/dist/nerd/Iosevka-nf-italic.ttf"
	mv "$(CURDIR)/dist/nerd/IosevkaNerdFontMono-Bold.ttf" "$(CURDIR)/dist/nerd/Iosevka-nf-bold.ttf"
	mv "$(CURDIR)/dist/nerd/IosevkaNerdFontMono-BoldItalic.ttf" "$(CURDIR)/dist/nerd/Iosevka-nf-bolditalic.ttf"

package: ## Pack fonts to ready-to-distribute archives
	zip -jr $(CURDIR)/dist/Iosevka.zip $(CURDIR)/dist/ttf/*.ttf
	zip -jr $(CURDIR)/dist/Iosevka_NF.zip $(CURDIR)/dist/nerd/*.ttf

clean:
	rm -rf $(CURDIR)/dist/*
