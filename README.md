# formal-specification
A runnable specification separate from code.
The aim is to reflect all of the business logic assumptions in one place,
in such a way that we can verify them and check consistency.
This should help us when we make changes or additions to the logic. 

## How to run
In order to run the spec you will need a prolog.
Recommended is SWI-Prolog, which you can download and install for free.
`brew install swi-prolog` should do the trick.
Then you run the test suites using `make test`

## How to contribute
Have a look at a test case and come up with your own.
Mimic one of the existing test cases.
Run it: your test either passes or fails.
If it passes, you've just proven that your case is covered by the logic.
If it does not, you've found a gap in the model where we need to improve.
You can either fix it yourself or raise the question: what should happen in this case?
