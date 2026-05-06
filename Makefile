.PHONY: clean install test

mu: Sources/main.swift
	swiftc -O -whole-module-optimization -o mu Sources/main.swift

test: Sources/main.swift Tests/TextSearchTests.swift
	mkdir -p build
	awk '/^\/\/ MARK: - Parse command line arguments/{exit} {print}' Sources/main.swift > build/TextSearchForTests.swift
	swiftc build/TextSearchForTests.swift Tests/TextSearchTests.swift -o build/mu-search-tests
	./build/mu-search-tests

install: mu
	cp mu /usr/local/bin/mu

clean:
	rm -f mu
	rm -rf build
