PREFIX ?= /usr/local
BINDIR = $(PREFIX)/bin

.PHONY: install uninstall clean

install: svpm.sh
	@echo "Installing svpm to $(BINDIR)..."
	install -d $(BINDIR)
	install -m 755 svpm.sh $(BINDIR)/svpm
	@echo "Installation complete."

uninstall:
	@echo "Removing svpm from $(BINDIR)..."
	rm -f $(BINDIR)/svpm
	@echo "Uninstallation complete."

clean:
	@echo "Cleaning up..."
