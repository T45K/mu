.PHONY: clean install

mu: Sources/main.swift
	swiftc -O -whole-module-optimization -o mu Sources/main.swift

install: mu
	cp mu /usr/local/bin/mu

clean:
	rm -f mu
