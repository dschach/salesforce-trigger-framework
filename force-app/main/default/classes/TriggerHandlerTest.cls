/**
 * @description Test class for base TriggerHandler class
 * @author {@link [Kevin OHara](https://github.com/kevinohara80)}
 * @since 2013
 * @author {@link [David Schach](https://github.com/dschach)}
 * @since 2021 Update, add new methods
 * @since 2023-02-08 Update assert methods to Assert class
 * @group Trigger Handler
 * @see [GitHub](https://github.com/dschach/salesforce-trigger-framework)
 * @see TriggerHandler
 */
@IsTest(isParallel=true testFor='ApexClass:TriggerHandler')
private inherited sharing class TriggerHandlerTest {
	private static String lastMethodCalled;
	private static System.TriggerOperation lastEventSeen;
	private static String lastNameSeen;
	private static TriggerHandlerTest.TestHandler handler;
	/**
	 * The name the fixture registers with the base class: the same string `Type.getName()` returns, so that `bypass(Type)` matches
	 */
	private static final String HANDLER_NAME = TriggerHandlerTest.TestHandler.class.getName();

	static {
		handler = new TriggerHandlerTest.TestHandler();
		// override its internal trigger detection
		handler.isTriggerExecuting = true;
	}

	// contexts tests

	@IsTest
	private static void testBeforeInsert() {
		beforeInsertMode();
		handler.run();
		Assert.areEqual('beforeInsert', lastMethodCalled, 'last method should be beforeInsert');
		Assert.areEqual(System.TriggerOperation.BEFORE_INSERT, handler.triggerEvent, 'triggerEvent should be set to current context');
	}

	@IsTest
	private static void testBeforeUpdate() {
		beforeUpdateMode();
		handler.run();
		Assert.areEqual('beforeUpdate', lastMethodCalled, 'last method should be beforeUpdate');
	}

	@IsTest
	private static void testBeforeDelete() {
		beforeDeleteMode();
		handler.run();
		Assert.areEqual('beforeDelete', lastMethodCalled, 'last method should be beforeDelete');
	}

	@IsTest
	private static void testAfterInsert() {
		afterInsertMode();
		handler.run();
		Assert.areEqual('afterInsert', lastMethodCalled, 'last method should be afterInsert');
	}

	@IsTest
	private static void testAfterUpdate() {
		afterUpdateMode();
		handler.run();
		Assert.areEqual('afterUpdate', lastMethodCalled, 'last method should be afterUpdate');
	}

	@IsTest
	private static void testAfterDelete() {
		afterDeleteMode();
		handler.run();
		Assert.areEqual('afterDelete', lastMethodCalled, 'last method should be afterDelete');
	}

	@IsTest
	private static void testAfterUndelete() {
		afterUndeleteMode();
		handler.run();
		Assert.areEqual('afterUndelete', lastMethodCalled, 'last method should be afterUndelete');
	}

	@IsTest
	private static void testNonTriggerContext() {
		try {
			handler.run();
			Assert.isTrue(false, 'the handler ran but should have thrown an exception');
		} catch (TriggerHandler.TriggerHandlerException te) {
			Assert.areEqual(TriggerHandler.ERROR_TRIGGERCONTEXT, te.getMessage(), 'the exception message should match');
		} catch (Exception e) {
			Assert.isTrue(false, 'the exception thrown was not expected: ' + e.getTypeName() + ': ' + e.getMessage());
		}
	}

	@IsTest
	private static void testConstructorWithParameter() {
		handler = new TriggerHandlerTest.TestHandler(HANDLER_NAME);
		// override its internal trigger detection
		handler.isTriggerExecuting = true;
		beforeInsertMode();
		handler.run();
		assertTestHandlerName();
		Assert.areEqual('beforeInsert', lastMethodCalled, 'last method should be beforeInsert');
	}

	@IsTest
	private static void testConstructorWithParametersAndBypass() {
		handler = new TriggerHandlerTest.TestHandler('TestHandler');
		// override its internal trigger detection
		handler.isTriggerExecuting = true;
		beforeUpdateMode();
		TriggerHandler.bypass('TestHandler');
		handler.run();
		Assert.isNull(lastMethodCalled, 'last method should be null when bypassed');
		Assert.isTrue(TriggerHandler.isBypassed('TestHandler'), 'test handler should be bypassed');
		Assert.isTrue(!TriggerHandler.bypassList().isEmpty(), 'Should have bypassed sample handler');
		Assert.isTrue(TriggerHandler.bypassSet().contains('TestHandler'), 'The set of bypassed handlers should contain the test handler');
	}

	/**
	 * @description test bypass api
	 */
	@SuppressWarnings('PMD.NcssCount')
	@IsTest
	private static void testBypassAPI() {
		afterUpdateMode();

		// test a bypass by string and run handler
		TriggerHandler.bypass(HANDLER_NAME);
		handler.run();
		Assert.isNull(lastMethodCalled, 'last method should be null when bypassed');
		Assert.isTrue(TriggerHandler.isBypassed(HANDLER_NAME), 'test handler should be bypassed');
		Assert.isTrue(!TriggerHandler.bypassList().isEmpty(), 'Should have no bypassed handlers');
		resetTest();

		// clear that bypass and run handler
		TriggerHandler.clearBypass(HANDLER_NAME);
		handler.run();
		Assert.areEqual('afterUpdate', lastMethodCalled, 'last method called should be afterUpdate');
		Assert.isFalse(TriggerHandler.isBypassed(HANDLER_NAME), 'test handler should not be bypassed');
		resetTest();

		// test a re-bypass by list and run handler
		TriggerHandler.bypass(new List<String>{ HANDLER_NAME });
		handler.run();
		Assert.isNull(lastMethodCalled, 'last method should be null when bypassed');
		Assert.isTrue(TriggerHandler.isBypassed(HANDLER_NAME), 'test handler should be bypassed');
		resetTest();

		// clear that bypass and run handler
		TriggerHandler.clearBypass(new List<String>{ HANDLER_NAME });
		handler.run();
		Assert.areEqual('afterUpdate', lastMethodCalled, 'last method called should be afterUpdate');
		Assert.isFalse(TriggerHandler.isBypassed(HANDLER_NAME), 'test handler should not be bypassed');
		resetTest();

		// test a bypass and run handler
		TriggerHandler.bypass(HANDLER_NAME);
		handler.run();
		Assert.isNull(lastMethodCalled, 'last method should be null when bypassed');
		Assert.isTrue(TriggerHandler.isBypassed(HANDLER_NAME), 'test handler should be bypassed');
		resetTest();

		// clear all bypasses and run handler
		TriggerHandler.clearAllBypasses();
		handler.run();
		Assert.areEqual('afterUpdate', lastMethodCalled, 'last method called should be afterUpdate');
		Assert.isFalse(TriggerHandler.isBypassed(HANDLER_NAME), 'test handler should not be bypassed');
		resetTest();

		// bypass everything
		TriggerHandler.bypassAll();
		handler.run();
		Assert.isTrue(TriggerHandler.bypassSet().contains(TriggerHandler.BYPASS_ALL_ALIAS), 'When global bypass is true, put an item in the bypassed set');
		Assert.isTrue(TriggerHandler.bypassedHandlers.isEmpty(), 'on bypass all, just set global variable to true and leave list empty');
		Assert.isTrue(TriggerHandler.globalBypass, 'bypassing all should set global bypass to true');
		resetTest();

		TriggerHandler.bypassAll();
		handler.run();
		Assert.isTrue(TriggerHandler.isBypassed(HANDLER_NAME), 'test handler should be bypassed');
		Assert.isTrue(TriggerHandler.bypassList().contains(TriggerHandler.BYPASS_ALL_ALIAS), 'When global bypass is true, put an item in the bypassed list');
		TriggerHandler.clearAllBypasses();
		Assert.isTrue(TriggerHandler.bypassList().isEmpty(), 'all bypassed handlers should be cleared');

		TriggerHandler.setBypass(HANDLER_NAME, true);
		handler.run();
		Assert.isTrue(TriggerHandler.isBypassed(HANDLER_NAME), 'test handler should be bypassed');
		TriggerHandler.bypassAll();
		TriggerHandler.setBypass(HANDLER_NAME, false);
		Assert.isTrue(!TriggerHandler.globalBypass, 'When one handler is set to run, global bypass should clear as well');
		Assert.isTrue(TriggerHandler.bypassList().isEmpty(), 'Should have cleared all bypasses');
		TriggerHandler.bypassAll();
		TriggerHandler.setBypass(HANDLER_NAME, true);
		Assert.isTrue(TriggerHandler.bypassList().contains(TriggerHandler.BYPASS_ALL_ALIAS), 'Global bypass should be enabled');
		Assert.isTrue(TriggerHandler.bypassList().contains(HANDLER_NAME), 'Bypass list should still contain test handler');
		resetTest();

		TriggerHandler.clearAllBypasses();
		TriggerHandler.bypass(HANDLER_NAME);
		TriggerHandler.setBypass(HANDLER_NAME, false);
		Assert.isTrue(TriggerHandler.bypassList().isEmpty(), 'Should have cleared bypass list');
	}

	/**
	 * @description Test bypass by Type
	 */
	@IsTest
	static void testBypassByType() {
		afterUpdateMode();

		// test a bypass by string and run handler
		TriggerHandler.bypass(TestHandler.class);
		Assert.isTrue(TriggerHandler.isBypassed('TriggerHandlerTest.TestHandler'), 'test handler should be bypassed');
		Assert.isTrue(TriggerHandler.isBypassed(Testhandler.class), 'test handler class should be bypassed');
		handler.run();
		Assert.isNull(lastMethodCalled, 'last method should be null when bypassed by Type');
		resetTest();

		// clear that bypass and run handler
		TriggerHandler.clearBypass(TestHandler.class);
		handler.run();
		Assert.areEqual('afterUpdate', lastMethodCalled, 'last method called should be afterUpdate');
		Assert.isFalse(TriggerHandler.isBypassed('TriggerHandlerTest.TestHandler'), 'test handler should not be bypassed');
		resetTest();
	}

	/**
	 * @description Test and show/hide limits and debug
	 */
	@IsTest
	private static void testBeforeInsertWithLimits() {
		beforeInsertMode();
		TriggerHandler.showLimits(false);
		TriggerHandler.showLimits();
		TriggerHandler.showDebug(null);
		TriggerHandler.showDebug(true);
		TriggerHandler.showDebug(false);
		handler.run();
		Assert.isFalse(TriggerHandler.showDebug, 'We should not be showing debug'); //NOPMD
		TriggerHandler.showDebug();
		handler.run();
		Assert.isTrue(TriggerHandler.showLimits, 'We should be showing limits'); //NOPMD
		TriggerHandler.getLoopCount(HANDLER_NAME);
		Assert.areEqual('beforeInsert', lastMethodCalled, 'last method should be beforeInsert');
	}

	/**
	 * @description Test and show/hide limits and debug using chaining
	 */
	@IsTest
	private static void testBeforeInsertWithLimitsChaining() {
		beforeInsertMode();
		handler.limits().debug().run();
		Assert.isTrue(TriggerHandler.showLimits, 'We should be showing limits'); //NOPMD
		Assert.isTrue(TriggerHandler.showDebug, 'We should be showing debugs'); //NOPMD
		Assert.areEqual('beforeInsert', lastMethodCalled, 'last method should be beforeInsert');

		handler.limits(null).debug(null).run();
		Assert.isFalse(TriggerHandler.showLimits, 'We should not be showing limits'); //NOPMD
		Assert.isFalse(TriggerHandler.showDebug, 'We should not be showing debugs'); //NOPMD

		handler.limits(false).debug(false).run();
		Assert.isFalse(TriggerHandler.showLimits, 'We should not be showing limits'); //NOPMD
		Assert.isFalse(TriggerHandler.showDebug, 'We should not be showing debugs'); //NOPMD
	}

	/**
	 * @description instance method tests
	 */
	@IsTest
	private static void testLoopCount() {
		beforeInsertMode();

		// set the max loops to 2
		// run the handler twice
		handler.setMaxLoopCount(2).run();
		handler.run();

		Assert.areEqual(2, TriggerHandler.getLoopCount(HANDLER_NAME), 'We should have run the handler only twice.');

		assertTestHandlerName();

		// clear the tests
		resetTest();
		TriggerHandler.showDebug();

		handler.run();
		Assert.isTrue(TriggerHandler.loopCountMap.get(HANDLER_NAME).getCount() > TriggerHandler.loopCountMap.get(HANDLER_NAME).getMax(), 'We should have exceeded the max count');
		Assert.isNull(lastMethodCalled, 'run() should skip the context method once the loop limit is exceeded');

		// clear the tests
		resetTest();

		// now clear the loop count
		handler.clearMaxLoopCount();

		handler.run();
		Assert.areEqual('beforeInsert', lastMethodCalled, 'last method should be beforeInsert');
	}

	@IsTest
	private static void testLoopCountClass() {
		TriggerHandler.LoopCount lc = new TriggerHandler.LoopCount();
		Assert.areEqual(5, lc.getMax(), 'max should be five on init');
		Assert.areEqual(0, lc.getCount(), 'count should be zero on init');

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
		Assert.isTrue(lc.exceeded(), 'should not be exceeded with count of 6');
	}

	/**
	 * @description Ensure that the current handler name is as expected
	 */
	private static void assertTestHandlerName() {
		Assert.areEqual(HANDLER_NAME, handler.getHandlerName(), 'handler name should match class name');
	}

	/**
	 * @description test virtual methods
	 */
	@IsTest
	private static void testVirtualMethods() {
		TriggerHandler h = new TriggerHandler();
		h.beforeInsert();
		h.beforeUpdate();
		h.beforeDelete();
		h.afterInsert();
		h.afterUpdate();
		h.afterDelete();
		h.afterUndelete();
		Assert.isTrue(true, 'Method is for code coverage only - debug to avoid PMD error');
	}

	/**
	 * @description call from outside trigger
	 */
	@IsTest
	private static void testOutsideTrigger() {
		TriggerHandler th = new TriggerHandler();
		Assert.isFalse(th.isTriggerExecuting, 'Should be outside trigger context');
		th.setTriggerContext(null, true);
		Assert.isFalse(th.isTriggerExecuting, 'Should be outside trigger context');
		Assert.isNull(th.triggerEvent, 'A null operation type should clear the trigger event');
	}

	/**
	 * @description Bypass names match regardless of case, while the list keeps the caller's spelling
	 */
	@IsTest
	private static void bypassIsCaseInsensitive() {
		afterUpdateMode();

		TriggerHandler.bypass(HANDLER_NAME.toLowerCase());
		handler.run();
		Assert.isNull(lastMethodCalled, 'a lower-case bypass name should still bypass the handler');
		Assert.isTrue(TriggerHandler.isBypassed(HANDLER_NAME.toUpperCase()), 'isBypassed should match regardless of case');
		Assert.isTrue(TriggerHandler.isBypassed(TriggerHandlerTest.TestHandler.class), 'isBypassed by Type should match regardless of case');
		Assert.isTrue(TriggerHandler.bypassList().contains(HANDLER_NAME.toLowerCase()), 'the bypass list should keep the name as the caller spelled it');
		resetTest();

		TriggerHandler.clearBypass(HANDLER_NAME.toUpperCase());
		handler.run();
		Assert.areEqual('afterUpdate', lastMethodCalled, 'clearing with another case should clear the bypass');
		Assert.isFalse(TriggerHandler.isBypassed(HANDLER_NAME), 'the handler should no longer be bypassed');
		Assert.isTrue(TriggerHandler.bypassList().isEmpty(), 'the bypass list should be empty after a clear in another case');
	}

	/**
	 * @description Null and blank arguments throw `TriggerHandlerException` with a message that names what is missing
	 */
	@IsTest
	private static void nullAndBlankArgumentsThrow() {
		afterUpdateMode();
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
		handler.run();
		Assert.areEqual('afterUpdate', lastMethodCalled, 'the handler should still run after the rejected calls');
	}

	/**
	 * @description Make 1 framework call with a null or blank argument
	 * @param scenario Which call to make
	 */
	@SuppressWarnings('PMD.CyclomaticComplexity')
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
				handler.setMaxLoopCount(null);
			}
			when 'getLoopCount null' {
				TriggerHandler.getLoopCount(null);
			}
		}
	}

	/**
	 * @description A blank name given to the String constructor falls back to the runtime class name
	 * <br>For an inner class the fallback is the short name, which differs from `Type.getName()`. That is why the fixture passes `HANDLER_NAME`
	 */
	@IsTest
	private static void blankConstructorNameFallsBackToClassName() {
		TriggerHandlerTest.TestHandler blankNamed = new TriggerHandlerTest.TestHandler('');
		Assert.areEqual('TestHandler', blankNamed.getHandlerName(), 'a blank constructor name should resolve to the short runtime class name');
		Assert.areNotEqual(HANDLER_NAME, blankNamed.getHandlerName(), 'for an inner class the fallback name differs from Type.getName()');
	}

	/**
	 * @description A subclass can read its own trigger event and handler name through the protected accessors
	 */
	@IsTest
	private static void subclassReadsItsEventAndName() {
		beforeInsertMode();
		handler.run();
		Assert.areEqual(System.TriggerOperation.BEFORE_INSERT, lastEventSeen, 'getTriggerEvent() should return the current operation to the subclass');
		Assert.areEqual(HANDLER_NAME, lastNameSeen, 'getHandlerName() should return the registered name to the subclass');
	}

	// testing utilities

	private static void resetTest() {
		lastMethodCalled = null;
	}

	// modes for testing

	private static void beforeInsertMode() {
		handler.setTriggerContext(System.TriggerOperation.BEFORE_INSERT, true);
	}

	private static void beforeUpdateMode() {
		handler.setTriggerContext(System.TriggerOperation.BEFORE_UPDATE, true);
	}

	private static void beforeDeleteMode() {
		handler.setTriggerContext(System.TriggerOperation.BEFORE_DELETE, true);
	}

	private static void afterInsertMode() {
		handler.setTriggerContext(System.TriggerOperation.AFTER_INSERT, true);
	}

	private static void afterUpdateMode() {
		handler.setTriggerContext(System.TriggerOperation.AFTER_UPDATE, true);
	}

	private static void afterDeleteMode() {
		handler.setTriggerContext(System.TriggerOperation.AFTER_DELETE, true);
	}

	private static void afterUndeleteMode() {
		handler.setTriggerContext(System.TriggerOperation.AFTER_UNDELETE, true);
	}

	/**
	 * @description test implementation of the TriggerHandler
	 */
	private class TestHandler extends TriggerHandler {
		/**
		 * @description Invoke constructor
		 */
		public TestHandler() {
			super(HANDLER_NAME);
		}

		/**
		 * @description       Override the trigger handler constructor that takes the handler name as a parameter
		 *
		 * @param handlerName The handler name to instantiate
		 */
		public TestHandler(String handlerName) {
			super(handlerName);
		}

		public override void beforeInsert() {
			TriggerHandlerTest.lastMethodCalled = 'beforeInsert';
			TriggerHandlerTest.lastEventSeen = getTriggerEvent();
			TriggerHandlerTest.lastNameSeen = getHandlerName();
		}

		public override void beforeUpdate() {
			TriggerHandlerTest.lastMethodCalled = 'beforeUpdate';
		}

		public override void beforeDelete() {
			TriggerHandlerTest.lastMethodCalled = 'beforeDelete';
		}

		public override void afterInsert() {
			TriggerHandlerTest.lastMethodCalled = 'afterInsert';
		}

		public override void afterUpdate() {
			TriggerHandlerTest.lastMethodCalled = 'afterUpdate';
		}

		public override void afterDelete() {
			TriggerHandlerTest.lastMethodCalled = 'afterDelete';
		}

		public override void afterUndelete() {
			TriggerHandlerTest.lastMethodCalled = 'afterUndelete';
		}
	}
}