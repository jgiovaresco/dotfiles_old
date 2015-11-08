.PHONY: default dotfiles etc install

default: install

install: dotfiles etc

dotfiles:
	# add aliases for dotfiles
	for file in $(shell find $(CURDIR) -name ".*" -not -name ".gitignore" -not -name ".git" -not -name ".*.swp"); do \
		f=$$(basename $$file); \
		ln -sfn $$file $(HOME)/$$f; \
	done

etc:
	for file in $(shell find $(CURDIR)/etc -type f -not -name ".*.swp" -not -name "*update-motd.d*"); do \
		f=$$(echo $$file | sed -e 's|$(CURDIR)||'); \
		sudo cp $$file $$f; \
	done
