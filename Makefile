PREFIX ?= /usr
DESTDIR ?=
BINDIR = $(PREFIX)/bin

.PHONY: install uninstall clean

install: svpm.sh
	@echo "Installing svpm to $(DESTDIR)$(BINDIR)..."
	install -d "$(DESTDIR)$(BINDIR)"
	install -m 755 svpm.sh "$(DESTDIR)$(BINDIR)/svpm"
	@echo "Installation complete."

uninstall:
	@echo "Removing svpm from $(BINDIR)..."
	rm -f "$(BINDIR)/svpm"
	@echo "Uninstallation complete."

clean:
	@echo "Cleaning up..."
