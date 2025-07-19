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
	make --ignore-errors package

ttf: ## Build ttf font from `PragmataPro` custom configuration
	docker run --rm \
		-v PragmataPro-volume:/builder/dist/PragmataPro/TTF \
		-v $(CURDIR)/private-build-plans.toml:/builder/private-build-plans.toml \
		iosevka/builder \
		npm run build -- ttf::PragmataPro
	docker run --rm \
		-v PragmataPro-volume:/scripter \
		-v $(CURDIR)/punctuation.py:/scripter/punctuation.py \
		fontforge/scripter \
		python /scripter/punctuation.py ./PragmataPro
	docker container create \
		-v PragmataPro-volume:/ttf \
		--name PragmataPro-dummy \
		alpine
	mkdir -p $(CURDIR)/dist/ttf
	docker cp PragmataPro-dummy:/ttf $(CURDIR)/dist
	docker rm PragmataPro-dummy
	docker volume rm PragmataPro-volume
	rm -rf $(CURDIR)/dist/ttf/*semibold*.ttf
	rm -rf $(CURDIR)/dist/ttf/*black*.ttf
	rm -rf $(CURDIR)/dist/ttf/punctuation.py
	mv "$(CURDIR)/dist/ttf/PragmataPro-normalbolditalic.ttf" "$(CURDIR)/dist/ttf/PragmataPro-bolditalic.ttf"
	mv "$(CURDIR)/dist/ttf/PragmataPro-normalboldupright.ttf" "$(CURDIR)/dist/ttf/PragmataPro-bold.ttf"
	mv "$(CURDIR)/dist/ttf/PragmataPro-normalregularitalic.ttf" "$(CURDIR)/dist/ttf/PragmataPro-italic.ttf"
	mv "$(CURDIR)/dist/ttf/PragmataPro-normalregularupright.ttf" "$(CURDIR)/dist/ttf/PragmataPro-regular.ttf"

nerd: ## Patch with Nerd Fonts glyphs
	docker run --rm \
		-v $(CURDIR)/dist/ttf:/in \
		-v PragmataPro-volume:/out \
		nerdfonts/patcher --complete --careful --mono
	docker container create \
		-v PragmataPro-volume:/nerd \
		--name PragmataPro-dummy \
		alpine
	docker cp PragmataPro-dummy:/nerd $(CURDIR)/dist
	docker rm PragmataPro-dummy
	docker volume rm PragmataPro-volume
	mv "$(CURDIR)/dist/nerd/PragmataProNerdFontMono-Regular.ttf" "$(CURDIR)/dist/nerd/PragmataPro-nf-regular.ttf"
	mv "$(CURDIR)/dist/nerd/PragmataProNerdFontMono-Italic.ttf" "$(CURDIR)/dist/nerd/PragmataPro-nf-italic.ttf"
	mv "$(CURDIR)/dist/nerd/PragmataProNerdFontMono-Bold.ttf" "$(CURDIR)/dist/nerd/PragmataPro-nf-bold.ttf"
	mv "$(CURDIR)/dist/nerd/PragmataProNerdFontMono-BoldItalic.ttf" "$(CURDIR)/dist/nerd/PragmataPro-nf-bolditalic.ttf"

package: ## Pack fonts to ready-to-distribute archives
	zip -jr $(CURDIR)/dist/PragmataPro.zip $(CURDIR)/dist/ttf/*.ttf
	zip -jr $(CURDIR)/dist/PragmataPro_NF.zip $(CURDIR)/dist/nerd/*.ttf

clean:
	rm -rf $(CURDIR)/dist/*
