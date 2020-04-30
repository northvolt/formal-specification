.PHONY: test

test:
	swipl -l specs.pl -t run_tests
