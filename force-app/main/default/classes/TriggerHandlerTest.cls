/**
 * Test class for base TriggerHandler class.
 * <br>Each test builds its own handler with `newHandler()` and proves 1 behavior through the call log.
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
@SuppressWarnings('PMD.CyclomaticComplexity')
@IsTest(isParallel=true testFor='ApexClass:TriggerHandler')
private inherited sharing class TriggerHandlerTest {
	/**
	 * The methods the test handler ran, in order. Apex resets it for each test method.
	 */
	private static List<String> calls = new List<String>();
	/**
	 * The context method that throws, or null when no method throws.
	 */
	private static String throwIn;
	/**
	 * The messages the test handler's `log` override received, each as the level, a colon, and the message.
	 */
	private static List<String> logs = new List<String>();
	private static System.TriggerOperation lastEventSeen;
	private static String lastNameSeen;
	/**
	 * The name the fixture registers with the base class through the Type constructor: `Type.getName()` of the inner class, so that `bypass(Type)` matches.
	 */
	private static final String HANDLER_NAME = TriggerHandlerTest.TestHandler.class.getName();
	/**
	 * A handler name that is never bypassed by name, used to observe the global bypass.
	 */
	private static final String OTHER_HANDLER = 'OtherHandler';

	// dispatch and andFinally

	/**
	 * `run()` calls the context method for each operation, and then `andFinally()`.
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
	 * A subclass can read its own trigger event and handler name through the protected accessors.
	 */
	@IsTest
	private static void subclassReadsItsEventAndName() {
		newHandler(System.TriggerOperation.BEFORE_INSERT).run();
		Assert.areEqual(System.TriggerOperation.BEFORE_INSERT, lastEventSeen, 'getTriggerEvent() should return the current operation to the subclass');
		Assert.areEqual(HANDLER_NAME, lastNameSeen, 'getHandlerName() should return the registered name to the subclass');
	}

	/**
	 * When a context method throws, the exception reaches the caller and `andFinally()` does not run.
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
	 * The base class runs every operation without an override, and each run counts against the loop limit.
	 */
	@IsTest
	private static void baseClassRunsEveryOperationWithoutOverrides() {
		TriggerHandler baseHandler = new TriggerHandler('BaseHandler');
		baseHandler.setMaxLoopCount(10);
		for (System.TriggerOperation operation : System.TriggerOperation.values()) {
			baseHandler.setTriggerContext(operation, true);
			baseHandler.run();
		}
		Assert.areEqual(System.TriggerOperation.values().size(), TriggerHandler.getLoopCount('BaseHandler'), 'the base class should complete 1 run for each operation');
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
	 * A null operation clears the trigger context, and `run()` then throws.
	 */
	@IsTest
	private static void nullOperationClearsTriggerContext() {
		TriggerHandler baseHandler = new TriggerHandler();
		baseHandler.setTriggerContext(null, true);
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
	 * The Type constructor registers `Type.getName()`, which for an inner class includes the outer class name.
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
	 * The String constructor registers the name it is given.
	 */
	@IsTest
	private static void stringConstructorSetsHandlerName() {
		TriggerHandlerTest.TestHandler named = new TriggerHandlerTest.TestHandler('NamedHandler');
		Assert.areEqual('NamedHandler', named.getHandlerName(), 'the handler name should be the constructor argument');
	}

	/**
	 * The String constructor removes the spaces at the start and the end of the name.
	 */
	@IsTest
	private static void stringConstructorTrimsHandlerName() {
		TriggerHandlerTest.TestHandler padded = new TriggerHandlerTest.TestHandler('  NamedHandler  ');
		Assert.areEqual('NamedHandler', padded.getHandlerName(), 'the handler name should have no spaces at the start or the end');
	}

	/**
	 * A blank name given to the String constructor falls back to the runtime class name.
	 * <br>For an inner class the fallback is the short name, which differs from `Type.getName()`. That is why the fixture passes `HANDLER_NAME`.
	 */
	@IsTest
	private static void blankConstructorNameFallsBackToClassName() {
		TriggerHandlerTest.TestHandler blankNamed = new TriggerHandlerTest.TestHandler('');
		Assert.areEqual('TestHandler', blankNamed.getHandlerName(), 'a blank constructor name should resolve to the short runtime class name');
		Assert.areNotEqual(HANDLER_NAME, blankNamed.getHandlerName(), 'for an inner class the fallback name differs from Type.getName()');
	}

	// bypass by name, list, and type

	/**
	 * A handler bypassed by name does not run, and neither does its `andFinally()`.
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
	 * Clearing a bypass by name lets the handler run again. Clearing a name that is not bypassed changes nothing.
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
	 * A list of names bypasses each handler in it, and clearing the list lets them run.
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
	 * A bypass by type uses `Type.getName()`, and clearing it by type lets the handler run.
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
	 * Bypass names match regardless of case, while the list keeps the caller's spelling.
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
	 * The bypass list is sorted, and the global alias comes after the names.
	 */
	@IsTest
	private static void bypassListIsSortedWithAliasLast() {
		TriggerHandler.bypassAll();
		TriggerHandler.bypass('Zulu');
		TriggerHandler.bypass('Alpha');
		Assert.areEqual(new List<String>{ 'Alpha', 'Zulu', TriggerHandler.BYPASS_ALL_ALIAS }, TriggerHandler.bypassList(), 'the names should be sorted, with the alias last');
	}

	// global bypass

	/**
	 * `bypassAll()` stops every handler, including its `andFinally()`.
	 */
	@IsTest
	private static void bypassAllSkipsRun() {
		TriggerHandler.bypassAll();
		newHandler(System.TriggerOperation.AFTER_UPDATE).run();
		Assert.isTrue(calls.isEmpty(), 'a global bypass should stop the handler');
		Assert.isTrue(TriggerHandler.isBypassed(HANDLER_NAME), 'every handler should be bypassed');
		Assert.isTrue(TriggerHandler.isBypassed(OTHER_HANDLER), 'a handler that was never named should be bypassed too');
		Assert.areEqual(new List<String>{ TriggerHandler.BYPASS_ALL_ALIAS }, TriggerHandler.bypassList(), 'the bypass list should hold only the alias');
		Assert.areEqual(new Set<String>{ TriggerHandler.BYPASS_ALL_ALIAS }, TriggerHandler.bypassSet(), 'the bypass set should hold only the alias');
	}

	/**
	 * `bypassAll()` clears the named bypasses, so a later `clearGlobalBypass()` leaves no handler bypassed.
	 */
	@IsTest
	private static void bypassAllClearsNamedBypasses() {
		TriggerHandler.bypass(HANDLER_NAME);
		TriggerHandler.bypassAll();
		Assert.areEqual(new List<String>{ TriggerHandler.BYPASS_ALL_ALIAS }, TriggerHandler.bypassList(), 'bypassAll() should clear the named bypasses');
		TriggerHandler.clearGlobalBypass();
		Assert.isFalse(TriggerHandler.isBypassed(HANDLER_NAME), 'the named bypass should be gone with the global bypass cleared');
	}

	/**
	 * `clearAllBypasses()` clears the global bypass and every named bypass.
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
		Assert.isFalse(TriggerHandler.isBypassed(OTHER_HANDLER), 'the global bypass should be cleared');
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
		Assert.isTrue(TriggerHandler.isBypassed(OTHER_HANDLER), 'the global bypass should stay');
		Assert.areEqual(new List<String>{ TriggerHandler.BYPASS_ALL_ALIAS }, TriggerHandler.bypassList(), 'the bypass list should hold only the alias');
		newHandler(System.TriggerOperation.AFTER_UPDATE).run();
		Assert.isTrue(calls.isEmpty(), 'the handler should still be bypassed');
	}

	// setBypass

	/**
	 * `setBypass(name, true)` bypasses the handler and keeps an active global bypass.
	 */
	@IsTest
	private static void setBypassTrueBypassesHandler() {
		TriggerHandler.bypassAll();
		TriggerHandler.setBypass(HANDLER_NAME, true);
		Assert.areEqual(new List<String>{ HANDLER_NAME, TriggerHandler.BYPASS_ALL_ALIAS }, TriggerHandler.bypassList(), 'the bypass list should hold the name and the alias');

		TriggerHandler.clearGlobalBypass();
		newHandler(System.TriggerOperation.AFTER_UPDATE).run();
		Assert.isTrue(calls.isEmpty(), 'the handler should be bypassed by name');
	}

	/**
	 * `setBypass(name, false)` clears the named bypass and also the global bypass.
	 */
	@IsTest
	private static void setBypassFalseClearsNamedAndGlobalBypass() {
		TriggerHandler.bypassAll();
		TriggerHandler.bypass(HANDLER_NAME);
		TriggerHandler.setBypass(HANDLER_NAME, false);
		Assert.isFalse(TriggerHandler.isBypassed(OTHER_HANDLER), 'setBypass false should clear the global bypass');
		Assert.isTrue(TriggerHandler.bypassList().isEmpty(), 'the bypass list should be empty');
		newHandler(System.TriggerOperation.AFTER_UPDATE).run();
		Assert.areEqual(new List<String>{ 'afterUpdate', 'andFinally' }, calls, 'the handler should run');
	}

	// loop count

	/**
	 * Once the loop limit is exceeded, `run()` calls neither the context method nor `andFinally()`.
	 */
	@IsTest
	private static void loopCountStopsRunAfterMax() {
		TriggerHandlerTest.TestHandler limited = newHandler(System.TriggerOperation.BEFORE_INSERT);
		limited.setMaxLoopCount(2).run();
		limited.run();
		Assert.areEqual(new List<String>{ 'beforeInsert', 'andFinally', 'beforeInsert', 'andFinally' }, calls, 'the handler should run twice');
		Assert.areEqual(2, TriggerHandler.getLoopCount(HANDLER_NAME), 'the loop count should be 2 after 2 runs');

		calls.clear();
		limited.run();
		Assert.isTrue(calls.isEmpty(), 'the third run should call no method');
		Assert.areEqual(3, TriggerHandler.getLoopCount(HANDLER_NAME), 'the skipped run should still count');
	}

	/**
	 * A maximum loop count of 0 stops every run, `andFinally()` included.
	 */
	@IsTest
	private static void maxLoopCountOfZeroStopsEveryRun() {
		newHandler(System.TriggerOperation.BEFORE_INSERT).setMaxLoopCount(0).run();
		Assert.isTrue(calls.isEmpty(), 'a maximum of 0 should stop the first run');
		Assert.areEqual(1, TriggerHandler.getLoopCount(HANDLER_NAME), 'the stopped run should still count');
	}

	/**
	 * `clearMaxLoopCount()` removes the limit, so the handler runs again.
	 */
	@IsTest
	private static void clearMaxLoopCountRemovesLimit() {
		TriggerHandlerTest.TestHandler limited = newHandler(System.TriggerOperation.BEFORE_INSERT);
		limited.setMaxLoopCount(1).run();
		limited.run();
		Assert.areEqual(new List<String>{ 'beforeInsert', 'andFinally' }, calls, 'the second run should be skipped');

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
		Assert.areEqual(2, TriggerHandler.getLoopCount(HANDLER_NAME), 'the count should continue under the new limit');
		Assert.areEqual(new List<String>{ 'beforeInsert', 'andFinally', 'beforeInsert', 'andFinally' }, calls, 'the second run should be inside the new limit');
	}

	/**
	 * Without a loop limit, runs are not counted. A handler that was never limited has a count of 0.
	 */
	@IsTest
	private static void loopCountIsZeroWithoutLimit() {
		newHandler(System.TriggerOperation.BEFORE_INSERT).run();
		Assert.areEqual(0, TriggerHandler.getLoopCount(HANDLER_NAME), 'a handler without a limit should not be counted');
		Assert.areEqual(0, TriggerHandler.getLoopCount(OTHER_HANDLER), 'an unknown handler should have a count of 0');
	}

	/**
	 * The `LoopCounter` class counts up and reports when the count passes the maximum.
	 */
	@IsTest
	private static void loopCounterClassCountsAndReportsExceeded() {
		TriggerHandler.LoopCounter lc = new TriggerHandler.LoopCounter();
		Assert.areEqual(5, lc.getMax(), 'max should be 5 on init');
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

	// debug and limits

	/**
	 * The static switches turn the debug and limits logs on and off, and `run()` works with both on.
	 */
	@IsTest
	private static void staticSwitchesSetDebugAndLimits() {
		TriggerHandler.showLimits(false);
		TriggerHandler.showDebug(false);
		Assert.isFalse(TriggerHandler.showLimits, 'showLimits(false) should turn limits off'); //NOPMD
		Assert.isFalse(TriggerHandler.showDebug, 'showDebug(false) should turn debug off'); //NOPMD

		TriggerHandler.showLimits();
		TriggerHandler.showDebug();
		newHandler(System.TriggerOperation.BEFORE_INSERT).run();
		Assert.isTrue(TriggerHandler.showLimits, 'showLimits() should turn limits on'); //NOPMD
		Assert.isTrue(TriggerHandler.showDebug, 'showDebug() should turn debug on'); //NOPMD
		Assert.areEqual(new List<String>{ 'beforeInsert', 'andFinally' }, calls, 'the handler should run with debug and limits on');

		TriggerHandler.showDebug(null);
		Assert.isFalse(TriggerHandler.showDebug, 'showDebug(null) should turn debug off'); //NOPMD
	}

	/**
	 * The instance switches return the same handler, so they chain into `run()`.
	 */
	@IsTest
	private static void instanceSwitchesChainAndSetFlags() {
		TriggerHandlerTest.TestHandler chained = newHandler(System.TriggerOperation.BEFORE_INSERT);
		Assert.isTrue(chained === chained.limits(), 'limits() should return the same handler');
		Assert.isTrue(chained === chained.debug(), 'debug() should return the same handler');
		Assert.isTrue(chained === chained.setMaxLoopCount(5), 'setMaxLoopCount() should return the same handler');
		chained.limits().debug().run();
		Assert.isTrue(TriggerHandler.showLimits, 'limits() should turn limits on'); //NOPMD
		Assert.isTrue(TriggerHandler.showDebug, 'debug() should turn debug on'); //NOPMD
		Assert.areEqual(new List<String>{ 'beforeInsert', 'andFinally' }, calls, 'the chained run should call the context method');

		chained.limits(null).debug(null);
		Assert.isFalse(TriggerHandler.showLimits, 'limits(null) should turn limits off'); //NOPMD
		Assert.isFalse(TriggerHandler.showDebug, 'debug(null) should turn debug off'); //NOPMD

		chained.limits(true).debug(true);
		chained.limits(false).debug(false);
		Assert.isFalse(TriggerHandler.showLimits, 'limits(false) should turn limits off'); //NOPMD
		Assert.isFalse(TriggerHandler.showDebug, 'debug(false) should turn debug off'); //NOPMD
	}

	// test seam and log hook

	/**
	 * `setTestContext()` makes a handler run as if a trigger fired the operation, and it returns the handler for chaining.
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
	 * With debug and limits off, `run()` logs nothing.
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
	 * An exceeded loop limit sends a warning through the `log` hook, also with debug off.
	 */
	@IsTest
	private static void exceededLoopLimitLogsWarning() {
		TriggerHandlerTest.TestHandler limited = newHandler(System.TriggerOperation.BEFORE_INSERT);
		limited.setMaxLoopCount(1).run();
		limited.run();
		Assert.areEqual(
			new List<String>{ 'WARN: Maximum loop count of 1 exceeded in ' + HANDLER_NAME + ', so run() skipped BEFORE_INSERT' },
			logs,
			'the loop limit warning should reach the log hook'
		);
	}

	/**
	 * The default `log` hook of the base class writes the debug and limits lines without an error.
	 */
	@IsTest
	private static void baseLogHookWritesWithoutError() {
		TriggerHandler baseHandler = new TriggerHandler('BaseHandler');
		baseHandler.setTestContext(System.TriggerOperation.BEFORE_INSERT);
		TriggerHandler.showDebug();
		TriggerHandler.showLimits();
		baseHandler.setMaxLoopCount(5).run();
		Assert.areEqual(1, TriggerHandler.getLoopCount('BaseHandler'), 'the base handler should complete its run with logging on');
	}

	// argument checks

	/**
	 * Null and blank arguments throw `TriggerHandlerException` with a message that names what is missing.
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
			'setBypass null value' => TriggerHandler.ERROR_BYPASS_VALUE,
			'setMaxLoopCount null' => TriggerHandler.ERROR_LOOP_COUNT,
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
	 * Make 1 framework call with a null or blank argument.
	 * @param scenario Which call to make.
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
			when 'setBypass null value' {
				TriggerHandler.setBypass(HANDLER_NAME, null);
			}
			when 'setMaxLoopCount null' {
				newHandler(System.TriggerOperation.AFTER_UPDATE).setMaxLoopCount(null);
			}
			when 'getLoopCount null' {
				TriggerHandler.getLoopCount(null);
			}
			when else {
				Assert.fail('unknown scenario: ' + scenario);
			}
		}
	}

	// testing utilities

	/**
	 * Build a test handler that runs as if a trigger fired the given operation.
	 * @param operation The trigger operation to simulate.
	 * @return `TriggerHandlerTest.TestHandler` A handler registered as `HANDLER_NAME`.
	 */
	private static TriggerHandlerTest.TestHandler newHandler(System.TriggerOperation operation) {
		TriggerHandlerTest.TestHandler fixture = new TriggerHandlerTest.TestHandler();
		fixture.setTestContext(operation);
		return fixture;
	}

	/**
	 * Add a method to the call log, and throw when the test asked that method to throw.
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
	 * The exception a context method throws when `throwIn` names it.
	 */
	private class TestHandlerException extends Exception {
	}

	/**
	 * Test implementation of the TriggerHandler. Every override writes to the call log.
	 */
	private class TestHandler extends TriggerHandler {
		/**
		 * Register the handler with its type, so that its name is `HANDLER_NAME`.
		 */
		public TestHandler() {
			super(TriggerHandlerTest.TestHandler.class);
		}

		/**
		 * Register the handler with the given type.
		 * @param handlerType The handler type to register.
		 */
		public TestHandler(Type handlerType) {
			super(handlerType);
		}

		/**
		 * Register the handler with the given name.
		 * @param handlerName The handler name to register.
		 */
		public TestHandler(String handlerName) {
			super(handlerName);
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
}