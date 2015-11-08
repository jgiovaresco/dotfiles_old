.PHONY: default dotfiles etc install

default: install

install: dotfiles

dotfiles:
	# add aliases for dotfiles
	for file in $(shell find $(CURDIR) -name ".*" -not -name ".gitignore" -not -name ".git" -not -name ".*.swp"); do \
		f=$$(basename $$file); \
		ln -sfn $$file $(HOME)/$$f; \
	done

etc:
	for file in $(shell find $(CURDIR)/etc -type f -not -name ".*.swp"); do \
		DIR=$$(dirname $$file); \
		DIR=$$(echo $$DIR | sed -e 's|$(CURDIR)||'); \
		mkdir -p $$DIR; \
		f=$$(echo $$file | sed -e 's|$(CURDIR)||'); \
		cp $$file $$f; \
	done
