# ============================================================
# Makefile — builds des présentations Marp (RisingWave, Flink…)
# Marp est lancé via Docker pour pouvoir build depuis n'importe où.
# ============================================================

.PHONY: all pdf pptx html preview cover clean docker-pull

# Ressources
SRCS     := risingwave.md flink.md proto.md
THEME    := theme.css
PNG      := cover.png

# Image Marp officielle (avec Chromium embarqué pour le PDF)
# On court-circuite le docker-entrypoint (qui fait du gosu vers l'utilisateur
# "marp") pour lancer node directement et conserver --user $(id -u) : les
# fichiers produits appartiennent bien à l'utilisateur courant.
IMAGE    := marpteam/marp-cli:latest
MARPC    := /home/marp/.cli/marp-cli.js
DOCKER   := docker run --rm --user "$$(id -u):$$(id -g)" \
	-v "$${PWD}:/home/marp/app" -e LANG=C.UTF-8 \
	--entrypoint node $(IMAGE) $(MARPC)

# Cible par défaut : PDF de toutes les présentations
all: pdf

# --- Télécharge / met à jour l'image Marp ---
docker-pull:
	docker pull $(IMAGE)

# --- PDF (Chrome/Chromium fourni par l'image) ---
pdf: $(SRCS:.md=.pdf)

%.pdf: %.md $(PNG) flink-model.png
	mkdir -p $$(dirname $@)
	$(DOCKER) $< --theme $(THEME) --pdf --allow-local-files -o $@
	@echo "PDF généré : slides/$@"

# --- PPTX (optionnel) ---
pptx: $(SRCS:.md=.pptx)

%.pptx: %.md $(PNG)
	mkdir -p $$(dirname $@)
	$(DOCKER) $< --theme $(THEME) --pptx --allow-local-files -o $@
	@echo "PPTX généré : slides/$@"

# --- HTML standalone ---
html: $(SRCS:.md=.html)

%.html: %.md
	$(DOCKER) $< --theme $(THEME) --html --allow-local-files -o $@
	@echo "HTML généré : slides/$@"

# --- Prévisualisation live ---
# Servi sur http://localhost:8080 ; watch sur les sources. Ctrl+C pour arrêter.
preview:
	@echo "Prévisualisation Marp : http://localhost:8080 (Ctrl+C pour arrêter)"
	$(subst docker run,docker run -p 8080:8080,$(DOCKER)) $(SRCS) --theme $(THEME) --server --watch

# --- Régénère l'image de garde depuis le SVG ---
cover: $(PNG)

$(PNG): cover.svg
	inkscape cover.svg --export-filename=$(PNG) -w 1600 -h 900
	@echo "Garde générée : slides/$(PNG)"

# --- Autres illustrations SVG -> PNG ---
flink-model.png: flink-model.svg
	inkscape $< --export-filename=$@ -w 1200 -h 430
	@echo "Illustration générée : slides/$@"

# --- Nettoyage ---
clean:
	rm -f $(SRCS:.md=.pdf) $(SRCS:.md=.pptx) $(SRCS:.md=.html) $(PNG)
	@echo "Builds supprimés."
