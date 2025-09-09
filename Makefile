SHELL := /bin/bash

# Paths
SITE := $(abspath _site)
INDEX := $(SITE)/index.html
LETTER_INDEX := $(SITE)/letters/index.html

# Images
JEKYLL_IMAGE ?= jekyll/jekyll:latest
CHROME_IMAGE ?= zenika/alpine-chrome:latest

# On Apple Silicon (arm64/aarch64), many images are amd64-only; use emulation
UNAME_M := $(shell uname -m)
DOCKER_PLATFORM ?=
ifeq ($(UNAME_M),arm64)
  DOCKER_PLATFORM := --platform=linux/amd64
endif
ifeq ($(UNAME_M),aarch64)
  DOCKER_PLATFORM := --platform=linux/amd64
endif

# Try to locate a Chrome/Chromium binary; allow override via CHROME=/path/to/chrome
CHROME ?= $(shell which google-chrome-stable 2>/dev/null || which google-chrome 2>/dev/null || which chromium 2>/dev/null || which chromium-browser 2>/dev/null || { test -x "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" && echo "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"; } )

define NEED_CHROME
	@if [ -z "$(CHROME)" ]; then echo "No Chrome/Chromium found. Set CHROME=/path/to/chrome or use 'make pdf-docker'"; exit 1; fi
endef

.PHONY: site site-local serve clean pdf pdf-all pdf-docker pdf-all-docker

# Build static site with Dockerized Jekyll into _site/
site:
	@docker run --rm $(DOCKER_PLATFORM) -v "$(PWD)":/srv/jekyll -w /srv/jekyll $(JEKYLL_IMAGE) jekyll build

# Optional: build with local Jekyll (if installed)
site-local:
	@jekyll build

# Local preview server (optional, requires local Jekyll)
serve:
	@jekyll serve

# Generate cv.pdf from _site/index.html using local headless Chrome
pdf: site
	$(NEED_CHROME)
	@"$(CHROME)" --headless --disable-gpu --print-to-pdf="cv.pdf" "file://$(INDEX)"
	@echo "Generated cv.pdf"

# Generate both CV and cover letter PDFs if the letter page exists (local Chrome)
pdf-all: pdf
	@if [ -f "$(LETTER_INDEX)" ]; then \
		"$(CHROME)" --headless --disable-gpu --print-to-pdf="cover-letter.pdf" "file://$(LETTER_INDEX)"; \
		echo "Generated cover-letter.pdf"; \
	else \
		echo "No letters/index.html found; skipping cover letter"; \
	fi

# Generate PDFs using a Dockerized Chrome (no local Chrome required)
pdf-docker: site
	@docker run --rm $(DOCKER_PLATFORM) -v "$(PWD)":/work -w /work $(CHROME_IMAGE) \
		--no-sandbox --headless --disable-gpu \
		--print-to-pdf=/work/cv.pdf "file:///work/_site/index.html"
	@echo "Generated cv.pdf (dockerized Chrome)"

pdf-all-docker: site
	@docker run --rm $(DOCKER_PLATFORM) -v "$(PWD)":/work -w /work $(CHROME_IMAGE) \
		--no-sandbox --headless --disable-gpu \
		--print-to-pdf=/work/cv.pdf "file:///work/_site/index.html"
	@if [ -f "$(LETTER_INDEX)" ]; then \
		docker run --rm $(DOCKER_PLATFORM) -v "$(PWD)":/work -w /work $(CHROME_IMAGE) \
			--no-sandbox --headless --disable-gpu \
			--print-to-pdf=/work/cover-letter.pdf "file:///work/_site/letters/index.html"; \
		echo "Generated cover-letter.pdf (dockerized Chrome)"; \
	else \
		echo "No letters/index.html found; skipping cover letter"; \
	fi

clean:
	@rm -rf _site cv.pdf cover-letter.pdf
