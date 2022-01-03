/**
 * @description Test class for base TriggerHandler class
 * @author Kevin O'Hara
 * @author David Schach
 * @since 2013
 * @group TriggerHandler
 */
@isTest
private class TriggerHandlerTest {
  private static String lastMethodCalled;
  private static TriggerHandlerTest.TestHandler handler;

  static {
    handler = new TriggerHandlerTest.TestHandler();
    // override its internal trigger detection
    handler.isTriggerExecuting = true;
  }

  // contexts tests

  @isTest
  static void testBeforeInsert() {
    beforeInsertMode();
    handler.run();
    System.assertEquals(
      'beforeInsert',
      lastMethodCalled,
      'last method should be beforeInsert'
    );
    System.assertEquals(
      System.TriggerOperation.BEFORE_INSERT,
      handler.triggerEvent,
      'triggerEvent should be set to current context'
    );
  }

  @isTest
  static void testBeforeUpdate() {
    beforeUpdateMode();
    handler.run();
    System.assertEquals(
      'beforeUpdate',
      lastMethodCalled,
      'last method should be beforeUpdate'
    );
  }

  @isTest
  static void testBeforeDelete() {
    beforeDeleteMode();
    handler.run();
    System.assertEquals(
      'beforeDelete',
      lastMethodCalled,
      'last method should be beforeDelete'
    );
  }

  @isTest
  static void testAfterInsert() {
    afterInsertMode();
    handler.run();
    System.assertEquals(
      'afterInsert',
      lastMethodCalled,
      'last method should be afterInsert'
    );
  }

  @isTest
  static void testAfterUpdate() {
    afterUpdateMode();
    handler.run();
    System.assertEquals(
      'afterUpdate',
      lastMethodCalled,
      'last method should be afterUpdate'
    );
  }

  @isTest
  static void testAfterDelete() {
    afterDeleteMode();
    handler.run();
    System.assertEquals(
      'afterDelete',
      lastMethodCalled,
      'last method should be afterDelete'
    );
  }

  @isTest
  static void testAfterUndelete() {
    afterUndeleteMode();
    handler.run();
    System.assertEquals(
      'afterUndelete',
      lastMethodCalled,
      'last method should be afterUndelete'
    );
  }

  @isTest
  static void testNonTriggerContext() {
    try {
      handler.run();
      System.assert(
        false,
        'the handler ran but should have thrown an exception'
      );
    } catch (TriggerHandler.TriggerHandlerException te) {
      System.assertEquals(
        TriggerHandler.errorOutsideTriggerContext,
        te.getMessage(),
        'the exception message should match'
      );
    } catch (Exception e) {
      System.assert(
        false,
        'the exception thrown was not expected: ' +
        e.getTypeName() +
        ': ' +
        e.getMessage()
      );
    }
  }

  @isTest
  static void testConstructorWithParameter() {
    handler = new TriggerHandlerTest.TestHandler('TestHandler');
    // override its internal trigger detection
    handler.isTriggerExecuting = true;
    beforeInsertMode();
    handler.run();
    assertTestHandlerName();
    System.assertEquals(
      'beforeInsert',
      lastMethodCalled,
      'last method should be beforeInsert'
    );
  }

  @isTest
  static void testConstructorWithParametersAndBypass() {
    handler = new TriggerHandlerTest.TestHandler('TestHandler');
    // override its internal trigger detection
    handler.isTriggerExecuting = true;
    beforeUpdateMode();
    TriggerHandler.bypass('TestHandler');
    handler.run();
    System.assertEquals(
      null,
      lastMethodCalled,
      'last method should be null when bypassed'
    );
    System.assertEquals(
      true,
      TriggerHandler.isBypassed('TestHandler'),
      'test handler should be bypassed'
    );
    System.assert(
      !TriggerHandler.bypassList().isEmpty(),
      'Should have no bypassed handlers'
    );
    System.assert(
      TriggerHandler.bypassList().contains('TestHandler'),
      'The list of bypassed handlers should contain the test handler'
    );
  }

  /**
   * @description test bypass api
   */
  @SuppressWarnings('PMD.NcssMethodCount')
  @isTest
  static void testBypassAPI() {
    afterUpdateMode();

    // test a bypass by string and run handler
    TriggerHandler.bypass('TestHandler');
    handler.run();
    System.assertEquals(
      null,
      lastMethodCalled,
      'last method should be null when bypassed'
    );
    System.assertEquals(
      true,
      TriggerHandler.isBypassed('TestHandler'),
      'test handler should be bypassed'
    );
    System.assert(
      !TriggerHandler.bypassList().isEmpty(),
      'Should have no bypassed handlers'
    );
    resetTest();

    // clear that bypass and run handler
    TriggerHandler.clearBypass('TestHandler');
    handler.run();
    System.assertEquals(
      'afterUpdate',
      lastMethodCalled,
      'last method called should be afterUpdate'
    );
    System.assertEquals(
      false,
      TriggerHandler.isBypassed('TestHandler'),
      'test handler should not be bypassed'
    );
    resetTest();

    // test a re-bypass by list and run handler
    TriggerHandler.bypass(new List<String>{ 'TestHandler' });
    handler.run();
    System.assertEquals(
      null,
      lastMethodCalled,
      'last method should be null when bypassed'
    );
    System.assertEquals(
      true,
      TriggerHandler.isBypassed('TestHandler'),
      'test handler should be bypassed'
    );
    resetTest();

    // clear that bypass and run handler
    TriggerHandler.clearBypass(new List<String>{ 'TestHandler' });
    handler.run();
    System.assertEquals(
      'afterUpdate',
      lastMethodCalled,
      'last method called should be afterUpdate'
    );
    System.assertEquals(
      false,
      TriggerHandler.isBypassed('TestHandler'),
      'test handler should not be bypassed'
    );
    resetTest();

    // test a bypass and run handler
    TriggerHandler.bypass('TestHandler');
    handler.run();
    System.assertEquals(
      null,
      lastMethodCalled,
      'last method should be null when bypassed'
    );
    System.assertEquals(
      true,
      TriggerHandler.isBypassed('TestHandler'),
      'test handler should be bypassed'
    );
    resetTest();

    // clear all bypasses and run handler
    TriggerHandler.clearAllBypasses();
    handler.run();
    System.assertEquals(
      'afterUpdate',
      lastMethodCalled,
      'last method called should be afterUpdate'
    );
    System.assertEquals(
      false,
      TriggerHandler.isBypassed('TestHandler'),
      'test handler should not be bypassed'
    );
    resetTest();

    // bypass everything
    TriggerHandler.bypassAll();
    handler.run();
    System.assert(
      TriggerHandler.bypassedHandlers.isEmpty(),
      'on bypass all, just set global variable to true and leave list empty'
    );
    System.assert(
      TriggerHandler.globalBypass,
      'bypassing all should set global bypass to true'
    );
    resetTest();

    TriggerHandler.bypassAll();
    handler.run();
    System.assertEquals(
      true,
      TriggerHandler.isBypassed('TestHandler'),
      'test handler should be bypassed'
    );
    System.assert(
      !TriggerHandler.bypassList().isEmpty(),
      'we should have a bypassed handler in the list'
    );
    TriggerHandler.clearAllBypasses();
    System.assert(
      TriggerHandler.bypassList().isEmpty(),
      'all bypassed handlers should be cleared'
    );

    TriggerHandler.setBypass('TestHandler', true);
    handler.run();
    System.assertEquals(
      true,
      TriggerHandler.isBypassed('TestHandler'),
      'test handler should be bypassed'
    );
    TriggerHandler.bypassAll();
    TriggerHandler.setBypass('TestHandler', false);
    System.assert(
      !TriggerHandler.globalBypass,
      'When one handler is set to run, global bypass should clear as well'
    );
    System.assert(
      TriggerHandler.bypassList().isEmpty(),
      'Should have cleared all bypasses'
    );
    TriggerHandler.bypassAll();
    TriggerHandler.setBypass('TestHandler', true);
    System.assert(
      TriggerHandler.bypassList().contains('bypassAll'),
      'Global bypass should be enabled'
    );
    System.assert(
      TriggerHandler.bypassList().contains('TestHandler'),
      'Bypass list should still contain test handler'
    );
    resetTest();

    TriggerHandler.clearAllBypasses();
    TriggerHandler.bypass('TestHandler');
    TriggerHandler.setBypass('TestHandler', false);
    System.assert(
      TriggerHandler.bypassList().isEmpty(),
      'Should have cleared bypass list'
    );
  }

  /**
   * @description Test and show limits
   */
  @isTest
  static void testBeforeInsertWithLimits() {
    beforeInsertMode();
    TriggerHandler.showLimits(false);
    TriggerHandler.showLimits();
    handler.run();
    System.assert(TriggerHandler.showLimits, 'We should be showing limits');
    TriggerHandler.getLoopCount('TestHandler');
    System.assertEquals(
      'beforeInsert',
      lastMethodCalled,
      'last method should be beforeInsert'
    );
  }

  /**
   * @description instance method tests
   */
  @isTest
  static void testLoopCount() {
    beforeInsertMode();

    // set the max loops to 2
    handler.setMaxLoopCount(2);

    // run the handler twice
    handler.run();
    handler.run();

    System.assertEquals(
      2,
      TriggerHandler.getLoopCount('TestHandler'),
      'We should have run the handler only twice.'
    );

    assertTestHandlerName();

    // clear the tests
    resetTest();

    try {
      // try running it. This should exceed the limit.
      handler.run();
      System.assert(
        false,
        'the handler should throw on the 3rd run when maxloopcount is 3'
      );
    } catch (TriggerHandler.TriggerHandlerException te) {
      // we're expecting to get here
      System.assertEquals(null, lastMethodCalled, 'last method should be null');
    } catch (Exception e) {
      System.assert(
        false,
        'the exception thrown was not expected: ' +
        e.getTypeName() +
        ': ' +
        e.getMessage()
      );
    }

    // clear the tests
    resetTest();

    // now clear the loop count
    handler.clearMaxLoopCount();

    try {
      // re-run the handler. We shouldn't throw now.
      handler.run();
      System.assertEquals(
        'beforeInsert',
        lastMethodCalled,
        'last method should be beforeInsert'
      );
    } catch (TriggerHandler.TriggerHandlerException te) {
      System.assert(
        false,
        'running the handler after clearing the loop count should not throw'
      );
    } catch (Exception e) {
      System.assert(
        false,
        'the exception thrown was not expected: ' +
        e.getTypeName() +
        ': ' +
        e.getMessage()
      );
    }
  }

  @isTest
  static void testLoopCountClass() {
    TriggerHandler.LoopCount lc = new TriggerHandler.LoopCount();
    System.assertEquals(5, lc.getMax(), 'max should be five on init');
    System.assertEquals(0, lc.getCount(), 'count should be zero on init');

    lc.increment();
    System.assertEquals(1, lc.getCount(), 'count should be 1');
    System.assertEquals(
      false,
      lc.exceeded(),
      'should not be exceeded with count of 1'
    );

    lc.increment();
    lc.increment();
    lc.increment();
    lc.increment();
    System.assertEquals(5, lc.getCount(), 'count should be 5');
    System.assertEquals(
      false,
      lc.exceeded(),
      'should not be exceeded with count of 5'
    );

    lc.increment();
    System.assertEquals(6, lc.getCount(), 'count should be 6');
    System.assertEquals(
      true,
      lc.exceeded(),
      'should not be exceeded with count of 6'
    );
  }

  /**
   * @description ensure that the current handler name is as expected
   */
  private static void assertTestHandlerName() {
    System.assertEquals(
      'TestHandler',
      handler.getHandlerName(),
      'handler name should match class name'
    );
  }

  /**
   * @description test virtual methods
   */
  @isTest
  private static void testVirtualMethods() {
    TriggerHandler h = new TriggerHandler();
    h.beforeInsert();
    h.beforeUpdate();
    h.beforeDelete();
    h.afterInsert();
    h.afterUpdate();
    h.afterDelete();
    h.afterUndelete();
    System.assert(true, 'Method is for code coverage only');
  }

  /**
   * @description call from outside trigger
   */
  @isTest
  private static void testOutsideTrigger() {
    TriggerHandler th = new TriggerHandler();
    System.assert(!th.isTriggerExecuting, 'Should be outside trigger context');
    th.setTriggerContext(null, true);
    System.assert(!th.isTriggerExecuting, 'Should be outside trigger context');
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
      super('TestHandler');
    }

    /**
     * @description       Override the trigger handler constructor that takes the handler name as a parameter
     *
     * @param handlerName The handler name to instantiate
     */
    @SuppressWarnings('PMD.EmptyStatementBlock')
    public TestHandler(String handlerName) {
      //super(handlerName);
    }

    public override void beforeInsert() {
      TriggerHandlerTest.lastMethodCalled = 'beforeInsert';
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
