/**
 * Tests for the `TriggerHandler` base class.
 * <br>Each test proves 1 behavior. Most tests create their handler with `newHandler()` and read the call log.
 * <br>No real trigger runs in these tests: `setTestContext()` gives each handler its trigger operation. The sample tests, which are outside the package directory, run the real trigger.
 * <br>`NcssCount` is suppressed. The class has 1 test for each behavior of the framework, the bypass and loop counter registries too, so it is large by design.
 * @author {@link [Kevin OHara](https://github.com/kevinohara80)}
 * @since 2013
 * @author {@link [David Schach](https://github.com/dschach)}
 * @since 2021 Update, add new methods
 * @since 2023-02-08 Update assert methods to Assert class
 * @since 2026-10-30 1 test per behavior, with a call log that records `andFinally()`
 * @group Trigger Handler
 * @see [GitHub](https://github.com/dschach/salesforce-trigger-framework)
 * @see TriggerHandler
 */
@SuppressWarnings('PMD.CyclomaticComplexity, PMD.NcssCount')
@IsTest(isParallel=true testFor='ApexClass:TriggerHandler')
private inherited sharing class TriggerHandlerTest {
	/**
	 * The methods that the test handler ran, in order. Apex resets it for each test method.
	 */
	private static List<String> calls = new List<String>();
	/**
	 * The context method that throws, or null when no method throws.
	 */
	private static String throwIn;
	/**
	 * The messages that the `log` override of the test handler received. Each entry is the level, a colon, and the message.
	 */
	private static List<String> logs = new List<String>();
	/**
	 * The value of `getTriggerEvent()` that the test handler saw in its last run.
	 */
	private static System.TriggerOperation lastEventSeen;
	/**
	 * The value of `getHandlerName()` that the test handler saw in its last run.
	 */
	private static String lastNameSeen;
	/**
	 * The name that the test handler gets from the Type constructor: `Type.getName()` of the inner class. It matches `bypass(Type)`.
	 */
	private static final String HANDLER_NAME = TriggerHandlerTest.TestHandler.class.getName();
	/**
	 * A handler name that is never bypassed by name. The tests use it to see the global bypass.
	 */
	private static final String OTHER_HANDLER = 'OtherHandler';

	// dispatch and andFinally

	/**
	 * `run()` calls the context method of each operation, and then `andFinally()`.
	 */
	@IsTest
	private static void runDispatchesEachOperationToItsMethod() {
		Map<System.TriggerOperation, String> expectedMethods = new Map<System.TriggerOperation, String>{
			System.TriggerOperation.BEFORE_INSERT => 'beforeInsert',
			System.TriggerOperation.BEFORE_UPDATE => 'beforeUpdate',
			System.TriggerOperation.BEFORE_DELETE => 'beforeDelete',
			System.TriggerOperation.AFTER_INSERT => 'afterInsert',
			System.TriggerOperation.AFTER_UPDATE => 'afterUpdate',
			System.TriggerOperation.AFTER_DELETE => 'afterDelete',
			System.TriggerOperation.AFTER_UNDELETE => 'afterUndelete'
		};
		for (System.TriggerOperation operation : System.TriggerOperation.values()) {
			calls.clear();
			newHandler(operation).run();
			Assert.areEqual(new List<String>{ expectedMethods.get(operation), 'andFinally' }, calls, operation + ' should call its context method and then andFinally');
		}
	}

	/**
	 * A subclass reads its own trigger event and handler name through the protected methods.
	 */
	@IsTest
	private static void subclassReadsItsEventAndName() {
		newHandler(System.TriggerOperation.BEFORE_INSERT).run();
		Assert.areEqual(System.TriggerOperation.BEFORE_INSERT, lastEventSeen, 'getTriggerEvent() should return the current operation to the subclass');
		Assert.areEqual(HANDLER_NAME, lastNameSeen, 'getHandlerName() should return the registered name to the subclass');
	}

	/**
	 * When a context method throws, the exception reaches the caller, and `andFinally()` does not run.
	 */
	@IsTest
	private static void andFinallyDoesNotRunWhenContextMethodThrows() {
		throwIn = 'afterUpdate';
		try {
			newHandler(System.TriggerOperation.AFTER_UPDATE).run();
			Assert.fail('the exception from the context method should reach the caller');
		} catch (TestHandlerException e) {
			Assert.areEqual(new List<String>{ 'afterUpdate' }, calls, 'andFinally should not run after the context method throws');
		}
	}

	/**
	 * A handler with no overrides runs the empty base methods for all operations. Each run counts against the loop limit.
	 */
	@IsTest
	private static void baseClassRunsEveryOperationWithoutOverrides() {
		TriggerHandlerTest.UntypedHandler baseHandler = new TriggerHandlerTest.UntypedHandler();
		baseHandler.setMaxLoopCount(10);
		for (System.TriggerOperation operation : System.TriggerOperation.values()) {
			baseHandler.setTestContext(operation);
			baseHandler.run();
		}
		for (System.TriggerOperation operation : System.TriggerOperation.values()) {
			Assert.areEqual(1, TriggerHandler.getLoopCount('UntypedHandler', operation), 'the base class should complete 1 run of ' + operation);
		}
		Assert.areEqual(System.TriggerOperation.values().size(), TriggerHandler.getLoopCount('UntypedHandler'), 'the deprecated total should count 1 run for each operation');
	}

	// trigger context

	/**
	 * `run()` outside a trigger throws and calls no method.
	 */
	@IsTest
	private static void runOutsideTriggerThrows() {
		TriggerHandlerTest.TestHandler outside = new TriggerHandlerTest.TestHandler();
		Assert.isFalse(outside.isTriggerExecuting, 'a handler built outside a trigger should not be executing');
		try {
			outside.run();
			Assert.fail('run() outside a trigger should throw TriggerHandlerException');
		} catch (TriggerHandler.TriggerHandlerException e) {
			Assert.areEqual(TriggerHandler.ERROR_TRIGGERCONTEXT, e.getMessage(), 'the exception should say that run() was called outside a trigger');
		}
		Assert.isTrue(calls.isEmpty(), 'no method should run outside a trigger');
	}

	/**
	 * A null operation clears the trigger context. `run()` then throws.
	 */
	@IsTest
	private static void nullOperationClearsTriggerContext() {
		TriggerHandlerTest.UntypedHandler baseHandler = new TriggerHandlerTest.UntypedHandler();
		baseHandler.setTestContext(null);
		Assert.isFalse(baseHandler.isTriggerExecuting, 'a null operation should leave the handler outside a trigger');
		Assert.isNull(baseHandler.triggerEvent, 'a null operation should clear the trigger event');
		try {
			baseHandler.run();
			Assert.fail('run() with a null operation should throw TriggerHandlerException');
		} catch (TriggerHandler.TriggerHandlerException e) {
			Assert.areEqual(TriggerHandler.ERROR_TRIGGERCONTEXT, e.getMessage(), 'the exception should say that run() was called outside a trigger');
		}
	}

	// handler name

	/**
	 * The Type constructor sets the name to `Type.getName()`. For an inner class, the name includes the outer class name.
	 */
	@IsTest
	private static void typeConstructorSetsFullHandlerName() {
		TriggerHandlerTest.TestHandler typed = new TriggerHandlerTest.TestHandler();
		Assert.areEqual('TriggerHandlerTest.TestHandler', typed.getHandlerName(), 'the handler name should be Type.getName() of the inner class');
	}

	/**
	 * The Type constructor rejects a null type.
	 */
	@IsTest
	private static void typeConstructorRejectsNullType() {
		try {
			new TriggerHandlerTest.TestHandler((Type) null);
			Assert.fail('a null type should throw TriggerHandlerException');
		} catch (TriggerHandler.TriggerHandlerException e) {
			Assert.areEqual(TriggerHandler.ERROR_HANDLER_TYPE, e.getMessage(), 'the exception should say that a handler type is required');
		}
	}

	/**
	 * Without the Type constructor, an inner-class handler gets its name from the runtime class name.
	 * <br>That name is only the short name, which is not the same as `Type.getName()`. So an inner-class handler must use the Type constructor.
	 */
	@IsTest
	private static void noArgConstructorResolvesShortInnerClassName() {
		TriggerHandlerTest.UntypedHandler untyped = new TriggerHandlerTest.UntypedHandler();
		Assert.areEqual('UntypedHandler', untyped.getHandlerName(), 'the no-arg constructor should resolve the short runtime class name');
		Assert.areNotEqual(TriggerHandlerTest.UntypedHandler.class.getName(), untyped.getHandlerName(), 'for an inner class the resolved name differs from Type.getName()');
	}

	// bypass by name, list, and type

	/**
	 * A handler that is bypassed by name does not run. Its `andFinally()` does not run either.
	 */
	@IsTest
	private static void bypassByNameSkipsRun() {
		TriggerHandler.bypass(HANDLER_NAME);
		newHandler(System.TriggerOperation.AFTER_UPDATE).run();
		Assert.isTrue(calls.isEmpty(), 'a bypassed handler should call no method');
		Assert.isTrue(TriggerHandler.isBypassed(HANDLER_NAME), 'the handler should be bypassed');
		Assert.areEqual(new List<String>{ HANDLER_NAME }, TriggerHandler.bypassList(), 'the bypass list should hold the handler name');
		Assert.isTrue(TriggerHandler.bypassSet().contains(HANDLER_NAME), 'the bypass set should hold the handler name');
	}

	/**
	 * When its bypass is cleared, a handler runs again. A clear of a name that is not bypassed changes nothing.
	 */
	@IsTest
	private static void clearBypassByNameLetsHandlerRun() {
		TriggerHandler.bypass(HANDLER_NAME);
		TriggerHandler.clearBypass(OTHER_HANDLER);
		Assert.isTrue(TriggerHandler.isBypassed(HANDLER_NAME), 'clearing another name should keep this bypass');

		TriggerHandler.clearBypass(HANDLER_NAME);
		newHandler(System.TriggerOperation.AFTER_UPDATE).run();
		Assert.areEqual(new List<String>{ 'afterUpdate', 'andFinally' }, calls, 'the handler should run after its bypass is cleared');
		Assert.isFalse(TriggerHandler.isBypassed(HANDLER_NAME), 'the handler should not be bypassed');
		Assert.isTrue(TriggerHandler.bypassList().isEmpty(), 'the bypass list should be empty');
	}

	/**
	 * A bypass of another handler does not stop this handler.
	 */
	@IsTest
	private static void bypassOfAnotherHandlerDoesNotSkipRun() {
		TriggerHandler.bypass(OTHER_HANDLER);
		newHandler(System.TriggerOperation.AFTER_UPDATE).run();
		Assert.areEqual(new List<String>{ 'afterUpdate', 'andFinally' }, calls, 'a handler that is not bypassed should run');
		Assert.isFalse(TriggerHandler.isBypassed(HANDLER_NAME), 'the handler should not be bypassed');
	}

	/**
	 * A list of names bypasses each handler in it. A clear of the list lets the handlers run.
	 */
	@IsTest
	private static void bypassByListSkipsRunUntilCleared() {
		TriggerHandler.bypass(new List<String>{ HANDLER_NAME, OTHER_HANDLER });
		newHandler(System.TriggerOperation.AFTER_UPDATE).run();
		Assert.isTrue(calls.isEmpty(), 'a handler bypassed by list should call no method');
		Assert.isTrue(TriggerHandler.isBypassed(OTHER_HANDLER), 'every name in the list should be bypassed');

		TriggerHandler.clearBypass(new List<String>{ HANDLER_NAME, OTHER_HANDLER });
		newHandler(System.TriggerOperation.AFTER_UPDATE).run();
		Assert.areEqual(new List<String>{ 'afterUpdate', 'andFinally' }, calls, 'the handler should run after the list is cleared');
		Assert.isTrue(TriggerHandler.bypassList().isEmpty(), 'every name in the list should be cleared');
	}

	/**
	 * A bypass by type uses `Type.getName()`. A clear by type lets the handler run.
	 */
	@IsTest
	private static void bypassByTypeSkipsRunUntilCleared() {
		TriggerHandler.bypass(TriggerHandlerTest.TestHandler.class);
		Assert.isTrue(TriggerHandler.isBypassed(HANDLER_NAME), 'a bypass by type should register Type.getName()');
		Assert.isTrue(TriggerHandler.isBypassed(TriggerHandlerTest.TestHandler.class), 'the handler type should be bypassed');
		newHandler(System.TriggerOperation.AFTER_UPDATE).run();
		Assert.isTrue(calls.isEmpty(), 'a handler bypassed by type should call no method');

		TriggerHandler.clearBypass(TriggerHandlerTest.TestHandler.class);
		newHandler(System.TriggerOperation.AFTER_UPDATE).run();
		Assert.areEqual(new List<String>{ 'afterUpdate', 'andFinally' }, calls, 'the handler should run after the type bypass is cleared');
		Assert.isFalse(TriggerHandler.isBypassed(TriggerHandlerTest.TestHandler.class), 'the handler type should not be bypassed');
	}

	/**
	 * Bypass names match in any case. The list keeps the names as the caller wrote them.
	 */
	@IsTest
	private static void bypassIsCaseInsensitive() {
		TriggerHandler.bypass(HANDLER_NAME.toLowerCase());
		newHandler(System.TriggerOperation.AFTER_UPDATE).run();
		Assert.isTrue(calls.isEmpty(), 'a lower-case bypass name should still bypass the handler');
		Assert.isTrue(TriggerHandler.isBypassed(HANDLER_NAME.toUpperCase()), 'isBypassed should match regardless of case');
		Assert.isTrue(TriggerHandler.isBypassed(TriggerHandlerTest.TestHandler.class), 'isBypassed by Type should match regardless of case');
		Assert.isTrue(TriggerHandler.bypassList().contains(HANDLER_NAME.toLowerCase()), 'the bypass list should keep the name as the caller spelled it');

		TriggerHandler.clearBypass(HANDLER_NAME.toUpperCase());
		newHandler(System.TriggerOperation.AFTER_UPDATE).run();
		Assert.areEqual(new List<String>{ 'afterUpdate', 'andFinally' }, calls, 'clearing with another case should clear the bypass');
		Assert.isFalse(TriggerHandler.isBypassed(HANDLER_NAME), 'the handler should no longer be bypassed');
		Assert.isTrue(TriggerHandler.bypassList().isEmpty(), 'the bypass list should be empty after a clear in another case');
	}

	/**
	 * The bypass list is sorted. It holds only the named bypasses, also under a global bypass.
	 */
	@IsTest
	private static void bypassListIsSortedWithNamesOnly() {
		TriggerHandler.bypassAll();
		TriggerHandler.bypass('Zulu');
		TriggerHandler.bypass('Alpha');
		Assert.areEqual(new List<String>{ 'Alpha', 'Zulu' }, TriggerHandler.bypassList(), 'the names should be sorted, with no entry for the global bypass');
	}

	/**
	 * 'BypassAll' is an ordinary handler name. A bypass with that name does not start a global bypass.
	 */
	@IsTest
	private static void bypassAllNameIsAnOrdinaryName() {
		TriggerHandler.bypass('BypassAll');
		Assert.isFalse(TriggerHandler.isGlobalBypassed(), 'a bypass named BypassAll should not turn on the global bypass');
		Assert.areEqual(new List<String>{ 'BypassAll' }, TriggerHandler.bypassList(), 'the bypass list should hold the name');
		newHandler(System.TriggerOperation.AFTER_UPDATE).run();
		Assert.areEqual(new List<String>{ 'afterUpdate', 'andFinally' }, calls, 'another handler should still run');
	}

	// global bypass

	/**
	 * `bypassAll()` stops all handlers and their `andFinally()`.
	 */
	@IsTest
	private static void bypassAllSkipsRun() {
		TriggerHandler.bypassAll();
		newHandler(System.TriggerOperation.AFTER_UPDATE).run();
		Assert.isTrue(calls.isEmpty(), 'a global bypass should stop the handler');
		Assert.isTrue(TriggerHandler.isGlobalBypassed(), 'the global bypass should be on');
		Assert.isTrue(TriggerHandler.isSkipped(HANDLER_NAME), 'every handler should be skipped');
		Assert.isTrue(TriggerHandler.isSkipped(OTHER_HANDLER), 'a handler that was never named should be skipped too');
		Assert.isFalse(TriggerHandler.isBypassed(OTHER_HANDLER), 'isBypassed should answer only the named bypass');
		Assert.isTrue(TriggerHandler.bypassList().isEmpty(), 'the bypass list should hold no entry for the global bypass');
		Assert.isTrue(TriggerHandler.bypassSet().isEmpty(), 'the bypass set should hold no entry for the global bypass');
	}

	/**
	 * `bypassAll()` keeps the named bypasses. After `clearGlobalBypass()`, they apply again.
	 */
	@IsTest
	private static void bypassAllKeepsNamedBypasses() {
		TriggerHandler.bypass(HANDLER_NAME);
		TriggerHandler.bypassAll();
		Assert.areEqual(new List<String>{ HANDLER_NAME }, TriggerHandler.bypassList(), 'bypassAll() should keep the named bypasses');
		TriggerHandler.clearGlobalBypass();
		Assert.isTrue(TriggerHandler.isBypassed(HANDLER_NAME), 'the named bypass should stay after the global bypass is cleared');
		Assert.isFalse(TriggerHandler.isBypassed(OTHER_HANDLER), 'a handler that was not named should no longer be bypassed');
		newHandler(System.TriggerOperation.AFTER_UPDATE).run();
		Assert.isTrue(calls.isEmpty(), 'the named handler should still be bypassed');
	}

	/**
	 * `clearAllBypasses()` clears the global bypass and all named bypasses.
	 */
	@IsTest
	private static void clearAllBypassesLetsHandlerRun() {
		TriggerHandler.bypassAll();
		TriggerHandler.bypass(HANDLER_NAME);
		TriggerHandler.clearAllBypasses();
		newHandler(System.TriggerOperation.AFTER_UPDATE).run();
		Assert.areEqual(new List<String>{ 'afterUpdate', 'andFinally' }, calls, 'the handler should run after all bypasses are cleared');
		Assert.isTrue(TriggerHandler.bypassList().isEmpty(), 'the bypass list should be empty');
	}

	/**
	 * `clearGlobalBypass()` keeps the named bypasses.
	 */
	@IsTest
	private static void clearGlobalBypassKeepsNamedBypasses() {
		TriggerHandler.bypassAll();
		TriggerHandler.bypass(HANDLER_NAME);
		TriggerHandler.clearGlobalBypass();
		Assert.isFalse(TriggerHandler.isGlobalBypassed(), 'the global bypass should be cleared');
		Assert.isFalse(TriggerHandler.isSkipped(OTHER_HANDLER), 'a handler that was not named should run');
		Assert.isTrue(TriggerHandler.isBypassed(HANDLER_NAME), 'the named bypass should stay');
		Assert.areEqual(new List<String>{ HANDLER_NAME }, TriggerHandler.bypassList(), 'the bypass list should hold only the named handler');
		newHandler(System.TriggerOperation.AFTER_UPDATE).run();
		Assert.isTrue(calls.isEmpty(), 'the named handler should still be bypassed');
	}

	/**
	 * `clearBypassList()` keeps the global bypass.
	 */
	@IsTest
	private static void clearBypassListKeepsGlobalBypass() {
		TriggerHandler.bypassAll();
		TriggerHandler.bypass(HANDLER_NAME);
		TriggerHandler.clearBypassList();
		Assert.isTrue(TriggerHandler.isGlobalBypassed(), 'the global bypass should stay');
		Assert.isFalse(TriggerHandler.isBypassed(HANDLER_NAME), 'the named bypass should be cleared');
		Assert.isTrue(TriggerHandler.bypassList().isEmpty(), 'the bypass list should be empty');
		newHandler(System.TriggerOperation.AFTER_UPDATE).run();
		Assert.isTrue(calls.isEmpty(), 'the handler should still be bypassed');
	}

	// setBypass

	/**
	 * `setBypass(name, true)` bypasses the handler by name, also during a global bypass. The named bypass stays after the global bypass is cleared.
	 */
	@IsTest
	private static void setBypassTrueBypassesHandler() {
		TriggerHandler.bypassAll();
		TriggerHandler.setBypass(HANDLER_NAME, true);
		Assert.areEqual(new List<String>{ HANDLER_NAME }, TriggerHandler.bypassList(), 'the bypass list should hold the name');

		TriggerHandler.clearGlobalBypass();
		newHandler(System.TriggerOperation.AFTER_UPDATE).run();
		Assert.isTrue(calls.isEmpty(), 'the handler should be bypassed by name');
	}

	/**
	 * `setBypass(name, false)` clears only the named bypass. A global bypass stays, so the handler runs only after `clearGlobalBypass()`.
	 */
	@IsTest
	private static void setBypassFalseClearsOnlyNamedBypass() {
		TriggerHandler.bypassAll();
		TriggerHandler.bypass(HANDLER_NAME);
		TriggerHandler.setBypass(HANDLER_NAME, false);
		Assert.isFalse(TriggerHandler.isBypassed(HANDLER_NAME), 'setBypass false should clear the named bypass');
		Assert.isTrue(TriggerHandler.isGlobalBypassed(), 'setBypass false should keep the global bypass');
		Assert.isTrue(TriggerHandler.isSkipped(HANDLER_NAME), 'the handler should still be skipped');
		newHandler(System.TriggerOperation.AFTER_UPDATE).run();
		Assert.isTrue(calls.isEmpty(), 'the global bypass should still stop the handler');

		TriggerHandler.clearGlobalBypass();
		newHandler(System.TriggerOperation.AFTER_UPDATE).run();
		Assert.areEqual(new List<String>{ 'afterUpdate', 'andFinally' }, calls, 'the handler should run after the global bypass is cleared');
	}

	/**
	 * The save-and-restore example with `isBypassed()` and `setBypass()` gives back the exact earlier state, also under a global bypass.
	 */
	@IsTest
	private static void setBypassRestoresTheEarlierState() {
		TriggerHandler.bypassAll();
		Boolean wasBypassed = TriggerHandler.isBypassed(HANDLER_NAME);
		TriggerHandler.bypass(HANDLER_NAME);
		TriggerHandler.setBypass(HANDLER_NAME, wasBypassed);
		Assert.isFalse(TriggerHandler.isBypassed(HANDLER_NAME), 'the idiom should not leave a named bypass behind');

		TriggerHandler.clearGlobalBypass();
		newHandler(System.TriggerOperation.AFTER_UPDATE).run();
		Assert.areEqual(new List<String>{ 'afterUpdate', 'andFinally' }, calls, 'the handler should run once the global bypass is cleared');
	}

	/**
	 * `setBypass()` by type sets and clears the named bypass of the handler, as the String form does.
	 */
	@IsTest
	private static void setBypassByTypeSetsAndClearsNamedBypass() {
		TriggerHandler.setBypass(TriggerHandlerTest.TestHandler.class, true);
		Assert.isTrue(TriggerHandler.isBypassed(HANDLER_NAME), 'setBypass true by type should bypass the handler name');
		newHandler(System.TriggerOperation.AFTER_UPDATE).run();
		Assert.isTrue(calls.isEmpty(), 'the handler bypassed by type should call no method');

		TriggerHandler.setBypass(TriggerHandlerTest.TestHandler.class, false);
		Assert.isFalse(TriggerHandler.isBypassed(TriggerHandlerTest.TestHandler.class), 'setBypass false by type should clear the bypass');
		newHandler(System.TriggerOperation.AFTER_UPDATE).run();
		Assert.areEqual(new List<String>{ 'afterUpdate', 'andFinally' }, calls, 'the handler should run after its bypass is cleared');
	}

	/**
	 * `isSkipped()` is true for a named bypass or a global bypass, by name and by type.
	 */
	@IsTest
	private static void isSkippedCombinesNamedAndGlobalBypass() {
		Assert.isFalse(TriggerHandler.isSkipped(HANDLER_NAME), 'a handler with no bypass should not be skipped');
		Assert.isFalse(TriggerHandler.isSkipped(TriggerHandlerTest.TestHandler.class), 'a handler type with no bypass should not be skipped');

		TriggerHandler.bypass(TriggerHandlerTest.TestHandler.class);
		Assert.isTrue(TriggerHandler.isSkipped(HANDLER_NAME), 'a named bypass should skip the handler');
		Assert.isTrue(TriggerHandler.isSkipped(TriggerHandlerTest.TestHandler.class), 'a type bypass should skip the handler');
		Assert.isFalse(TriggerHandler.isSkipped(OTHER_HANDLER), 'another handler should not be skipped');

		TriggerHandler.bypassAll();
		Assert.isTrue(TriggerHandler.isSkipped(OTHER_HANDLER), 'the global bypass should skip every handler');
	}

	// loop count

	/**
	 * After the loop limit is passed, `run()` calls neither the context method nor `andFinally()`.
	 */
	@IsTest
	private static void loopCountStopsRunAfterMax() {
		TriggerHandlerTest.TestHandler limited = newHandler(System.TriggerOperation.BEFORE_INSERT);
		limited.setMaxLoopCount(2).run();
		limited.run();
		Assert.areEqual(new List<String>{ 'beforeInsert', 'andFinally', 'beforeInsert', 'andFinally' }, calls, 'the handler should run twice');
		Assert.areEqual(2, TriggerHandler.getLoopCount(HANDLER_NAME, System.TriggerOperation.BEFORE_INSERT), 'the loop count should be 2 after 2 runs');

		calls.clear();
		limited.run();
		Assert.isTrue(calls.isEmpty(), 'the third run should call no method');
		Assert.areEqual(3, TriggerHandler.getLoopCount(HANDLER_NAME, System.TriggerOperation.BEFORE_INSERT), 'the stopped run should still count');
	}

	/**
	 * A maximum loop count of 0 means no limit, as a negative value does. The framework still counts the runs.
	 */
	@IsTest
	private static void maxLoopCountOfZeroMeansNoLimit() {
		TriggerHandlerTest.TestHandler unlimited = newHandler(System.TriggerOperation.BEFORE_INSERT);
		unlimited.setMaxLoopCount(0).run();
		unlimited.run();
		Assert.areEqual(new List<String>{ 'beforeInsert', 'andFinally', 'beforeInsert', 'andFinally' }, calls, 'a maximum of 0 should stop no run');
		Assert.areEqual(2, TriggerHandler.getLoopCount(HANDLER_NAME, System.TriggerOperation.BEFORE_INSERT), 'the runs should still be counted');
	}

	/**
	 * `clearMaxLoopCount()` removes the limit, so the handler runs again.
	 */
	@IsTest
	private static void clearMaxLoopCountRemovesLimit() {
		TriggerHandlerTest.TestHandler limited = newHandler(System.TriggerOperation.BEFORE_INSERT);
		limited.setMaxLoopCount(1).run();
		limited.run();
		Assert.areEqual(new List<String>{ 'beforeInsert', 'andFinally' }, calls, 'the second run should be stopped');

		calls.clear();
		limited.clearMaxLoopCount();
		limited.run();
		Assert.areEqual(new List<String>{ 'beforeInsert', 'andFinally' }, calls, 'the handler should run after the limit is removed');
	}

	/**
	 * A second `setMaxLoopCount()` changes the limit and keeps the count.
	 */
	@IsTest
	private static void setMaxLoopCountAgainChangesLimit() {
		TriggerHandlerTest.TestHandler limited = newHandler(System.TriggerOperation.BEFORE_INSERT);
		limited.setMaxLoopCount(1).run();
		limited.setMaxLoopCount(2).run();
		Assert.areEqual(2, TriggerHandler.getLoopCount(HANDLER_NAME, System.TriggerOperation.BEFORE_INSERT), 'the count should continue under the new limit');
		Assert.areEqual(new List<String>{ 'beforeInsert', 'andFinally', 'beforeInsert', 'andFinally' }, calls, 'the second run should be inside the new limit');
	}

	/**
	 * Each trigger operation has its own count, so a limit of 1 lets each operation run once.
	 */
	@IsTest
	private static void eachOperationHasItsOwnLoopCount() {
		TriggerHandlerTest.TestHandler limited = newHandler(System.TriggerOperation.BEFORE_INSERT);
		limited.setMaxLoopCount(1).run();
		limited.setTestContext(System.TriggerOperation.AFTER_INSERT).run();
		Assert.areEqual(new List<String>{ 'beforeInsert', 'andFinally', 'afterInsert', 'andFinally' }, calls, 'each operation should run once under a limit of 1');

		calls.clear();
		limited.setTestContext(System.TriggerOperation.BEFORE_INSERT).run();
		Assert.isTrue(calls.isEmpty(), 'a second run of the same operation should be stopped');
		Assert.areEqual(2, TriggerHandler.getLoopCount(HANDLER_NAME, System.TriggerOperation.BEFORE_INSERT), 'before insert should count its 2 runs');
		Assert.areEqual(1, TriggerHandler.getLoopCount(HANDLER_NAME, System.TriggerOperation.AFTER_INSERT), 'after insert should count its own run');
	}

	/**
	 * A limit for 1 operation stops only that operation. The framework does not count the other operations.
	 */
	@IsTest
	private static void setMaxLoopCountForOneOperationLimitsOnlyIt() {
		TriggerHandlerTest.TestHandler limited = newHandler(System.TriggerOperation.AFTER_UPDATE);
		limited.setMaxLoopCount(System.TriggerOperation.AFTER_UPDATE, 1).run();
		limited.run();
		Assert.areEqual(new List<String>{ 'afterUpdate', 'andFinally' }, calls, 'the second after update run should be stopped');

		calls.clear();
		limited.setTestContext(System.TriggerOperation.BEFORE_UPDATE).run();
		limited.run();
		Assert.areEqual(new List<String>{ 'beforeUpdate', 'andFinally', 'beforeUpdate', 'andFinally' }, calls, 'before update should have no limit');
		Assert.areEqual(
			TriggerHandler.NOT_COUNTED,
			TriggerHandler.getLoopCount(HANDLER_NAME, System.TriggerOperation.BEFORE_UPDATE),
			'an operation without a limit should not be counted'
		);
		Assert.areEqual(2, TriggerHandler.getLoopCount(HANDLER_NAME, System.TriggerOperation.AFTER_UPDATE), 'after update should count its 2 runs');
	}

	/**
	 * `clearMaxLoopCount()` on a handler with no limit creates no counter.
	 */
	@IsTest
	private static void clearMaxLoopCountWithoutLimitCreatesNoCounter() {
		TriggerHandlerTest.TestHandler handler = newHandler(System.TriggerOperation.BEFORE_INSERT);
		handler.clearMaxLoopCount();
		handler.run();
		Assert.areEqual(new List<String>{ 'beforeInsert', 'andFinally' }, calls, 'the handler should run');
		Assert.areEqual(TriggerHandler.NOT_COUNTED, TriggerHandler.getLoopCount(HANDLER_NAME, System.TriggerOperation.BEFORE_INSERT), 'the run should not be counted');
	}

	/**
	 * Without a loop limit, the framework does not count the runs. A handler that never had a limit has a count of -1.
	 */
	@IsTest
	private static void loopCountIsNotCountedWithoutLimit() {
		newHandler(System.TriggerOperation.BEFORE_INSERT).run();
		Assert.areEqual(
			TriggerHandler.NOT_COUNTED,
			TriggerHandler.getLoopCount(HANDLER_NAME, System.TriggerOperation.BEFORE_INSERT),
			'a handler without a limit should not be counted'
		);
		Assert.areEqual(TriggerHandler.NOT_COUNTED, TriggerHandler.getLoopCount(OTHER_HANDLER, System.TriggerOperation.BEFORE_INSERT), 'an unknown handler should not be counted');
		Assert.areEqual(TriggerHandler.NOT_COUNTED, TriggerHandler.getLoopCount(OTHER_HANDLER), 'the deprecated total should not count an unknown handler');
		Assert.areEqual(-1, TriggerHandler.NOT_COUNTED, 'a count that is not kept should be -1');
	}

	/**
	 * The `LoopCounter` class stores a maximum of 0 or less as -1, which means no limit.
	 */
	@IsTest
	private static void loopCounterStoresZeroAsNoLimit() {
		TriggerHandler.LoopCounter zero = new TriggerHandler.LoopCounter(0);
		Assert.areEqual(-1, zero.getMax(), 'a maximum of 0 should be stored as -1');
		Assert.isFalse(zero.increment(), 'a counter with no limit should never be exceeded');
		zero.setMax(-5);
		Assert.areEqual(-1, zero.getMax(), 'a negative maximum should be stored as -1');
		zero.setMax(3);
		Assert.areEqual(3, zero.getMax(), 'a positive maximum should be stored as given');
	}

	/**
	 * The `LoopCounter` class counts up and tells when the count passes the maximum.
	 */
	@IsTest
	private static void loopCounterClassCountsAndReportsExceeded() {
		TriggerHandler.LoopCounter lc = new TriggerHandler.LoopCounter(5);
		Assert.areEqual(5, lc.getMax(), 'max should be the value given to the constructor');
		Assert.areEqual(0, lc.getCount(), 'count should be 0 on init');

		lc.increment();
		Assert.areEqual(1, lc.getCount(), 'count should be 1');
		Assert.isFalse(lc.exceeded(), 'should not be exceeded with count of 1');

		lc.increment();
		lc.increment();
		lc.increment();
		lc.increment();
		Assert.areEqual(5, lc.getCount(), 'count should be 5');
		Assert.isFalse(lc.exceeded(), 'should not be exceeded with count of 5');

		lc.increment();
		Assert.areEqual(6, lc.getCount(), 'count should be 6');
		Assert.isTrue(lc.exceeded(), 'should be exceeded with count of 6');
	}

	// bypass and loop counter registries

	/**
	 * The `BypassRegistry` inner class keeps the named bypasses and the global bypass apart. It matches names in any case.
	 */
	@IsTest
	private static void bypassRegistryKeepsNamesAndGlobalApart() {
		TriggerHandler.BypassRegistry registry = new TriggerHandler.BypassRegistry();
		Assert.isFalse(registry.hasNames(), 'a new registry should have no named bypass');
		Assert.isFalse(registry.isAllBypassed(), 'a new registry should have no global bypass');

		registry.add('Zulu');
		registry.add('alpha');
		Assert.isTrue(registry.contains('ZULU'), 'a name should match regardless of case');
		Assert.areEqual(new List<String>{ 'Zulu', 'alpha' }, registry.sortedNames(), 'the names should keep their spelling, in sorted order');
		Assert.areEqual(new Set<String>{ 'Zulu', 'alpha' }, registry.nameSet(), 'the set should hold the same names');

		registry.remove('ALPHA');
		registry.remove('Unknown');
		Assert.isFalse(registry.contains('alpha'), 'a name removed in another case should be gone');
		Assert.areEqual(new List<String>{ 'Zulu' }, registry.sortedNames(), 'removing an unknown name should change nothing');

		registry.setAllBypassed(true);
		registry.clearNames();
		Assert.isTrue(registry.isAllBypassed(), 'clearing the names should keep the global bypass');
		Assert.isFalse(registry.hasNames(), 'every named bypass should be cleared');
	}

	/**
	 * The `LoopCounterRegistry` inner class keeps 1 counter for each handler and trigger operation. It returns `NOT_COUNTED` where no limit was set.
	 */
	@IsTest
	private static void loopCounterRegistryCountsEachOperation() {
		TriggerHandler.LoopCounterRegistry registry = new TriggerHandler.LoopCounterRegistry();
		Assert.isTrue(registry.isEmpty(), 'a new registry should have no counter');
		Assert.areEqual(TriggerHandler.NOT_COUNTED, registry.total('Handler'), 'a handler without a limit should not be counted');

		registry.setMax('Handler', System.TriggerOperation.BEFORE_INSERT, 1);
		registry.get('Handler', System.TriggerOperation.BEFORE_INSERT).increment();
		Assert.isFalse(registry.isEmpty(), 'the registry should have a counter after a limit is set');
		Assert.areEqual(1, registry.count('Handler', System.TriggerOperation.BEFORE_INSERT), 'the operation should count its run');
		Assert.areEqual(TriggerHandler.NOT_COUNTED, registry.count('Handler', System.TriggerOperation.AFTER_INSERT), 'an operation without a limit should not be counted');
		Assert.isNull(registry.get('Handler', System.TriggerOperation.AFTER_INSERT), 'an operation without a limit should have no counter');
		Assert.areEqual(1, registry.total('Handler'), 'the total should add the counted operations');

		registry.setMax('Handler', System.TriggerOperation.BEFORE_INSERT, 3);
		Assert.areEqual(3, registry.get('Handler', System.TriggerOperation.BEFORE_INSERT).getMax(), 'a second limit should change the maximum');
		Assert.areEqual(1, registry.count('Handler', System.TriggerOperation.BEFORE_INSERT), 'a second limit should keep the count');

		registry.clearMax('Handler');
		registry.clearMax('Unknown');
		Assert.areEqual(-1, registry.get('Handler', System.TriggerOperation.BEFORE_INSERT).getMax(), 'clearing should remove the limit');
		Assert.isNull(registry.get('Unknown', System.TriggerOperation.BEFORE_INSERT), 'clearing an unknown handler should create no counter');
	}

	// debug and limits

	/**
	 * The static methods set the debug and limits settings, and `run()` works with both settings on.
	 */
	@IsTest
	private static void staticSwitchesSetDebugAndLimits() {
		TriggerHandler.showLimits(false);
		TriggerHandler.showDebug(false);
		Assert.isFalse(TriggerHandler.doShowLimits, 'showLimits(false) should turn limits off');
		Assert.isFalse(TriggerHandler.doShowDebug, 'showDebug(false) should turn debug off');

		TriggerHandler.showLimits();
		TriggerHandler.showDebug();
		newHandler(System.TriggerOperation.BEFORE_INSERT).run();
		Assert.isTrue(TriggerHandler.doShowLimits, 'showLimits() should turn limits on');
		Assert.isTrue(TriggerHandler.doShowDebug, 'showDebug() should turn debug on');
		Assert.areEqual(new List<String>{ 'beforeInsert', 'andFinally' }, calls, 'the handler should run with debug and limits on');

		TriggerHandler.showDebug(null);
		Assert.isFalse(TriggerHandler.doShowDebug, 'showDebug(null) should turn debug off');
	}

	/**
	 * The deprecated instance methods `debug()` and `limits()` return the same handler, so you can chain them before `run()`.
	 */
	@IsTest
	private static void instanceSwitchesChainAndSetFlags() {
		TriggerHandlerTest.TestHandler chained = newHandler(System.TriggerOperation.BEFORE_INSERT);
		Assert.isTrue(chained === chained.limits(), 'limits() should return the same handler');
		Assert.isTrue(chained === chained.debug(), 'debug() should return the same handler');
		Assert.isTrue(chained === chained.setMaxLoopCount(5), 'setMaxLoopCount() should return the same handler');
		chained.limits().debug().run();
		Assert.isTrue(TriggerHandler.doShowLimits, 'limits() should turn limits on');
		Assert.isTrue(TriggerHandler.doShowDebug, 'debug() should turn debug on');
		Assert.areEqual(new List<String>{ 'beforeInsert', 'andFinally' }, calls, 'the chained run should call the context method');

		chained.limits(null).debug(null);
		Assert.isFalse(TriggerHandler.doShowLimits, 'limits(null) should turn limits off');
		Assert.isFalse(TriggerHandler.doShowDebug, 'debug(null) should turn debug off');

		chained.limits(true).debug(true);
		chained.limits(false).debug(false);
		Assert.isFalse(TriggerHandler.doShowLimits, 'limits(false) should turn limits off');
		Assert.isFalse(TriggerHandler.doShowDebug, 'debug(false) should turn debug off');
	}

	// test seam and log hook

	/**
	 * `setTestContext()` makes a handler run as if a trigger fired the operation. It returns the handler, so you can chain calls.
	 */
	@IsTest
	private static void setTestContextLetsTestRunHandler() {
		TriggerHandlerTest.TestHandler seamHandler = new TriggerHandlerTest.TestHandler();
		Assert.isTrue(seamHandler === seamHandler.setTestContext(System.TriggerOperation.AFTER_INSERT), 'setTestContext() should return the same handler');
		Assert.isTrue(seamHandler.isTriggerExecuting, 'the handler should run as if a trigger fired');
		seamHandler.run();
		Assert.areEqual(new List<String>{ 'afterInsert', 'andFinally' }, calls, 'the handler should run the simulated operation');
	}

	/**
	 * With debug on, `run()` sends its entry and exit lines through the `log` hook.
	 */
	@IsTest
	private static void debugOnLogsEntryAndExitThroughHook() {
		TriggerHandler.showDebug();
		newHandler(System.TriggerOperation.BEFORE_UPDATE).run();
		Assert.areEqual(
			new List<String>{ 'DEBUG: Entering ' + HANDLER_NAME + ', fired BEFORE_UPDATE', 'DEBUG: Exiting ' + HANDLER_NAME + ', fired BEFORE_UPDATE' },
			logs,
			'the entry and exit lines should reach the log hook'
		);
	}

	/**
	 * With debug and limits off, `run()` writes no line.
	 */
	@IsTest
	private static void debugOffLogsNothing() {
		newHandler(System.TriggerOperation.BEFORE_UPDATE).run();
		Assert.isTrue(logs.isEmpty(), 'nothing should be logged with debug and limits off');
	}

	/**
	 * With limits on, `run()` sends 1 limits line through the `log` hook.
	 */
	@IsTest
	private static void limitsOnLogsLimitsLine() {
		TriggerHandler.showLimits();
		newHandler(System.TriggerOperation.BEFORE_UPDATE).run();
		Assert.areEqual(1, logs.size(), 'the limits line should be the only message');
		Assert.isTrue(logs[0].startsWith('DEBUG: BEFORE_UPDATE on ' + HANDLER_NAME + ' ('), 'the limits line should name the operation and the handler');
	}

	/**
	 * `showHandlerDebug()` makes only 1 handler write the entry and exit lines. It returns the handler, so you can chain calls.
	 */
	@IsTest
	private static void showHandlerDebugIsForOneHandlerOnly() {
		TriggerHandlerTest.TestHandler debugged = newHandler(System.TriggerOperation.BEFORE_UPDATE);
		Assert.isTrue(debugged === debugged.showHandlerDebug(), 'showHandlerDebug() should return the same handler');
		debugged.run();
		Assert.areEqual(2, logs.size(), 'the handler with its own debug setting should write the entry and exit lines');

		logs.clear();
		newHandler(System.TriggerOperation.BEFORE_UPDATE).run();
		Assert.isTrue(logs.isEmpty(), 'another handler should write no debug line');
		Assert.isFalse(TriggerHandler.doShowDebug, 'showHandlerDebug() should not change the static setting');
	}

	/**
	 * The setting of a handler wins over the static setting. With null, the handler uses the static setting again.
	 */
	@IsTest
	private static void handlerDebugSettingWinsOverStatic() {
		TriggerHandler.showDebug();
		TriggerHandlerTest.TestHandler quiet = newHandler(System.TriggerOperation.BEFORE_UPDATE);
		quiet.showHandlerDebug(false).run();
		Assert.isTrue(logs.isEmpty(), 'showHandlerDebug(false) should turn the lines off for this handler');

		newHandler(System.TriggerOperation.BEFORE_UPDATE).run();
		Assert.areEqual(2, logs.size(), 'another handler should still use the static setting');

		logs.clear();
		quiet.showHandlerDebug(null).run();
		Assert.areEqual(2, logs.size(), 'showHandlerDebug(null) should make the handler use the static setting again');
	}

	/**
	 * `showHandlerLimits()` makes only 1 handler write the limits line. `showHandlerLimits(false)` wins over the static setting.
	 */
	@IsTest
	private static void showHandlerLimitsIsForOneHandlerOnly() {
		TriggerHandlerTest.TestHandler limited = newHandler(System.TriggerOperation.BEFORE_UPDATE);
		Assert.isTrue(limited === limited.showHandlerLimits(), 'showHandlerLimits() should return the same handler');
		limited.run();
		Assert.areEqual(1, logs.size(), 'the handler with its own limits setting should write the limits line');
		Assert.isTrue(logs[0].startsWith('DEBUG: BEFORE_UPDATE on ' + HANDLER_NAME + ' ('), 'the line should be the limits line');

		logs.clear();
		newHandler(System.TriggerOperation.BEFORE_UPDATE).run();
		Assert.isTrue(logs.isEmpty(), 'another handler should write no limits line');

		TriggerHandler.showLimits();
		limited.showHandlerLimits(false).run();
		Assert.isTrue(logs.isEmpty(), 'showHandlerLimits(false) should turn the line off for this handler');
	}

	/**
	 * When a run passes the loop limit, a warning goes through the `log` hook, also with debug off.
	 */
	@IsTest
	private static void exceededLoopLimitLogsWarning() {
		TriggerHandlerTest.TestHandler limited = newHandler(System.TriggerOperation.BEFORE_INSERT);
		limited.setMaxLoopCount(1).run();
		limited.run();
		Assert.areEqual(
			new List<String>{ 'WARN: Maximum loop count of 1 exceeded in ' + HANDLER_NAME + ', so run() stopped BEFORE_INSERT' },
			logs,
			'the loop limit warning should reach the log hook'
		);
	}

	/**
	 * The default `log` hook of the base class writes the debug and limits lines without an error, for a handler that does not override it.
	 */
	@IsTest
	private static void baseLogHookWritesWithoutError() {
		TriggerHandlerTest.UntypedHandler baseHandler = new TriggerHandlerTest.UntypedHandler();
		baseHandler.setTestContext(System.TriggerOperation.BEFORE_INSERT);
		TriggerHandler.showDebug();
		TriggerHandler.showLimits();
		baseHandler.setMaxLoopCount(5).run();
		Assert.areEqual(1, TriggerHandler.getLoopCount('UntypedHandler', System.TriggerOperation.BEFORE_INSERT), 'the base handler should complete its run with logging on');
	}

	// argument checks

	/**
	 * Null and blank arguments throw `TriggerHandlerException`. The message names the missing argument.
	 */
	@IsTest
	private static void nullAndBlankArgumentsThrow() {
		Map<String, String> expectedMessages = new Map<String, String>{
			'bypass null string' => TriggerHandler.ERROR_HANDLER_NAME,
			'bypass blank string' => TriggerHandler.ERROR_HANDLER_NAME,
			'bypass null type' => TriggerHandler.ERROR_HANDLER_TYPE,
			'bypass null list' => TriggerHandler.ERROR_HANDLER_NAMES,
			'bypass list with blank' => TriggerHandler.ERROR_HANDLER_NAME,
			'clearBypass null string' => TriggerHandler.ERROR_HANDLER_NAME,
			'clearBypass null type' => TriggerHandler.ERROR_HANDLER_TYPE,
			'clearBypass null list' => TriggerHandler.ERROR_HANDLER_NAMES,
			'isBypassed null string' => TriggerHandler.ERROR_HANDLER_NAME,
			'isBypassed null type' => TriggerHandler.ERROR_HANDLER_TYPE,
			'isSkipped null string' => TriggerHandler.ERROR_HANDLER_NAME,
			'isSkipped null type' => TriggerHandler.ERROR_HANDLER_TYPE,
			'setBypass null value' => TriggerHandler.ERROR_BYPASS_VALUE,
			'setBypass null type' => TriggerHandler.ERROR_HANDLER_TYPE,
			'setBypass type null value' => TriggerHandler.ERROR_BYPASS_VALUE,
			'setMaxLoopCount null' => TriggerHandler.ERROR_LOOP_COUNT,
			'setMaxLoopCount null operation' => TriggerHandler.ERROR_TRIGGER_OPERATION,
			'setMaxLoopCount operation null value' => TriggerHandler.ERROR_LOOP_COUNT,
			'getLoopCount null operation' => TriggerHandler.ERROR_TRIGGER_OPERATION,
			'getLoopCount operation null name' => TriggerHandler.ERROR_HANDLER_NAME,
			'getLoopCount null' => TriggerHandler.ERROR_HANDLER_NAME
		};
		for (String scenario : expectedMessages.keySet()) {
			try {
				callWithNullArgument(scenario);
				Assert.fail(scenario + ' should have thrown TriggerHandlerException');
			} catch (TriggerHandler.TriggerHandlerException e) {
				Assert.areEqual(expectedMessages.get(scenario), e.getMessage(), scenario + ' should say what is missing');
			}
		}
		Assert.isTrue(TriggerHandler.bypassList().isEmpty(), 'a rejected call should record no bypass');
		newHandler(System.TriggerOperation.AFTER_UPDATE).run();
		Assert.areEqual(new List<String>{ 'afterUpdate', 'andFinally' }, calls, 'the handler should still run after the rejected calls');
	}

	/**
	 * Makes 1 bypass call with a null or blank argument. It passes a loop count scenario to `callLoopCountWithNullArgument()`.
	 * @param scenario The call to make.
	 */
	private static void callWithNullArgument(String scenario) {
		switch on scenario {
			when 'bypass null string' {
				TriggerHandler.bypass((String) null);
			}
			when 'bypass blank string' {
				TriggerHandler.bypass(' ');
			}
			when 'bypass null type' {
				TriggerHandler.bypass((Type) null);
			}
			when 'bypass null list' {
				TriggerHandler.bypass((List<String>) null);
			}
			when 'bypass list with blank' {
				TriggerHandler.bypass(new List<String>{ HANDLER_NAME, '' });
			}
			when 'clearBypass null string' {
				TriggerHandler.clearBypass((String) null);
			}
			when 'clearBypass null type' {
				TriggerHandler.clearBypass((Type) null);
			}
			when 'clearBypass null list' {
				TriggerHandler.clearBypass((List<String>) null);
			}
			when 'isBypassed null string' {
				TriggerHandler.isBypassed((String) null);
			}
			when 'isBypassed null type' {
				TriggerHandler.isBypassed((Type) null);
			}
			when 'isSkipped null string' {
				TriggerHandler.isSkipped((String) null);
			}
			when 'isSkipped null type' {
				TriggerHandler.isSkipped((Type) null);
			}
			when 'setBypass null value' {
				TriggerHandler.setBypass(HANDLER_NAME, null);
			}
			when 'setBypass null type' {
				TriggerHandler.setBypass((Type) null, true);
			}
			when 'setBypass type null value' {
				TriggerHandler.setBypass(TriggerHandlerTest.TestHandler.class, null);
			}
			when else {
				callLoopCountWithNullArgument(scenario);
			}
		}
	}

	/**
	 * Makes 1 loop count call with a null argument. `callWithNullArgument()` passes the loop count scenarios to it.
	 * @param scenario The call to make.
	 */
	private static void callLoopCountWithNullArgument(String scenario) {
		switch on scenario {
			when 'setMaxLoopCount null' {
				newHandler(System.TriggerOperation.AFTER_UPDATE).setMaxLoopCount(null);
			}
			when 'getLoopCount null' {
				TriggerHandler.getLoopCount(null);
			}
			when 'setMaxLoopCount null operation' {
				newHandler(System.TriggerOperation.AFTER_UPDATE).setMaxLoopCount(null, 1);
			}
			when 'setMaxLoopCount operation null value' {
				newHandler(System.TriggerOperation.AFTER_UPDATE).setMaxLoopCount(System.TriggerOperation.AFTER_UPDATE, null);
			}
			when 'getLoopCount null operation' {
				TriggerHandler.getLoopCount(HANDLER_NAME, null);
			}
			when 'getLoopCount operation null name' {
				TriggerHandler.getLoopCount(null, System.TriggerOperation.AFTER_UPDATE);
			}
			when else {
				Assert.fail('unknown scenario: ' + scenario);
			}
		}
	}

	// testing utilities

	/**
	 * Creates a test handler that runs as if a trigger fired the operation.
	 * @param operation The trigger operation to simulate.
	 * @return `TriggerHandlerTest.TestHandler` A handler with the name `HANDLER_NAME`.
	 */
	private static TriggerHandlerTest.TestHandler newHandler(System.TriggerOperation operation) {
		TriggerHandlerTest.TestHandler fixture = new TriggerHandlerTest.TestHandler();
		fixture.setTestContext(operation);
		return fixture;
	}

	/**
	 * Adds a method to the call log. It throws when the test told that method to throw.
	 * @param methodName The method that ran.
	 * @exception TestHandlerException when `throwIn` names the method.
	 * @throws TestHandlerException when `throwIn` names the method.
	 */
	private static void record(String methodName) {
		calls.add(methodName);
		if (methodName == throwIn) {
			throw new TestHandlerException(methodName + ' threw');
		}
	}

	/**
	 * The exception that a context method throws when `throwIn` names it.
	 */
	private class TestHandlerException extends Exception {
	}

	/**
	 * The test handler. Each override writes to the call log.
	 */
	private class TestHandler extends TriggerHandler {
		/**
		 * Creates the handler with its type, so its name is `HANDLER_NAME`.
		 */
		public TestHandler() {
			super(TriggerHandlerTest.TestHandler.class);
		}

		/**
		 * Creates the handler with the type that the test gives.
		 * @param handlerType The handler type.
		 */
		public TestHandler(Type handlerType) {
			super(handlerType);
		}

		public override void beforeInsert() {
			TriggerHandlerTest.lastEventSeen = getTriggerEvent();
			TriggerHandlerTest.lastNameSeen = getHandlerName();
			record('beforeInsert');
		}

		public override void beforeUpdate() {
			record('beforeUpdate');
		}

		public override void beforeDelete() {
			record('beforeDelete');
		}

		public override void afterInsert() {
			record('afterInsert');
		}

		public override void afterUpdate() {
			record('afterUpdate');
		}

		public override void afterDelete() {
			record('afterDelete');
		}

		public override void afterUndelete() {
			record('afterUndelete');
		}

		public override void log(LoggingLevel level, String message) {
			TriggerHandlerTest.logs.add(level + ': ' + message);
		}

		public override void andFinally() {
			record('andFinally');
		}
	}

	/**
	 * A handler with no constructor and no overrides. The base class finds its name at runtime, and all context methods, `andFinally()`, and `log()` are the base class versions.
	 */
	private class UntypedHandler extends TriggerHandler {
	}
}