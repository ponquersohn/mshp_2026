SHELL := /bin/bash
MARP := ./node_modules/.bin/marp --no-stdin
DECKS := 01-rootkits 02-hardening
HTML := $(DECKS:%=build/%/index.html)
PDF := $(DECKS:%=build/%/slides.pdf)
PPTX := $(DECKS:%=build/%/slides.pptx)
.PHONY: all html pdf pptx install clean preview-rootkits preview-hardening
all: html pdf pptx
install:
	npm ci
html: $(HTML)
pdf: $(PDF)
pptx: $(PPTX)
build/%/index.html: %/slides.md themes/mshp.css themes/cybertopia.css .marprc.yml package-lock.json $(wildcard 01-rootkits/assets/* 02-hardening/assets/*)
	@mkdir -p $(@D)
	$(MARP) $< -o $@
	@if [ -d $*/assets ]; then cp -R $*/assets $(@D)/; fi
build/%/slides.pdf: %/slides.md themes/mshp.css themes/cybertopia.css .marprc.yml package-lock.json $(wildcard 01-rootkits/assets/* 02-hardening/assets/*)
	@mkdir -p $(@D)
	$(MARP) $< --pdf -o $@
build/%/slides.pptx: %/slides.md themes/mshp.css themes/cybertopia.css .marprc.yml package-lock.json $(wildcard 01-rootkits/assets/* 02-hardening/assets/*)
	@mkdir -p $(@D)
	$(MARP) $< --pptx -o $@
preview-rootkits:
	$(MARP) -s . --watch
preview-hardening: preview-rootkits
clean:
	rm -rf build
