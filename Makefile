
PERL=perl

.PHONY: dummy all guide build

dummy:
	@echo The main target is '"all"'

all: guide build

build:
	# Commented out because I cannot test -- JK
	# $(SH) scripts/build.sh

guide:
	$(PERL) scripts/guide.pl

