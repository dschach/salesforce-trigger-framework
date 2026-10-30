/**
 * The base class of every trigger handler. A handler extends it. Code cannot create the base class itself.
 * <br>`EmptyStatementBlock` is suppressed for the empty virtual context methods. A handler overrides only the methods that it needs. Stock PMD reports empty virtual methods, so this suppression keeps a scan with default rules free of findings.
 * @author {@link [Kevin OHara](https://github.com/kevinohara80)}
 * @since 2013
 * @author {@link [David Schach](https://github.com/dschach)}
 * @since 2021
 * @since 2023-02-24 add andFinally method
 * @since 2023-09 method chaining
 * @since 2026-10-30 a constructor with the handler type, a loop limit for each trigger operation, independent bypasses, and the debug settings of 1 handler
 * @group Trigger Handler
 * @see [License](https://github.com/dschach/salesforce-trigger-framework/blob/main/LICENSE)
 * @see [GitHub](https://github.com/dschach/salesforce-trigger-framework)
 * @see TriggerHandlerTest
 */
@SuppressWarnings('PMD.ExcessivePublicCount, PMD.CyclomaticComplexity, PMD.CognitiveComplexity, PMD.EmptyStatementBlock')
public inherited sharing abstract class TriggerHandler {
	/**
	 * The loop counters of all handlers in the transaction. A trigger operation has a counter after the first call of `setMaxLoopCount()` for it, also with 0 or a negative value. Without a counter, `getLoopCount()` returns `NOT_COUNTED`.
	 */
	private static LoopCounterRegistry loopCounters = new LoopCounterRegistry();

	/**
	 * The bypasses of the transaction: the named bypasses and the global bypass.
	 */
	private static BypassRegistry bypasses = new BypassRegistry();

	/**
	 * `true` when all handlers write the limits line after a run. `showLimits()` and `showLimits(Boolean)` set it, and so do the deprecated `limits()` and `limits(Boolean)`.
	 */
	@TestVisible
	private static Boolean doShowLimits = false;

	/**
	 * `true` when all handlers write the entry and exit lines of a run. `showDebug()` and `showDebug(Boolean)` set it, and so do the deprecated `debug()` and `debug(Boolean)`.
	 */
	@TestVisible
	private static Boolean doShowDebug = false;

	/**
	 * The limits setting of this handler only: `true`, `false`, or null. With null, the handler uses `doShowLimits`. `showHandlerLimits()` and `showHandlerLimits(Boolean)` set it.
	 */
	private Boolean handlerShowLimits;

	/**
	 * The debug setting of this handler only: `true`, `false`, or null. With null, the handler uses `doShowDebug`. `showHandlerDebug()` and `showHandlerDebug(Boolean)` set it.
	 */
	private Boolean handlerShowDebug;

	/**
	 * The trigger operation of the current run. In a test, `setTestContext()` sets it.
	 */
	@TestVisible
	private System.TriggerOperation triggerEvent;

	/**
	 * `true` when the handler runs in a trigger, or in a test context from `setTestContext()`.
	 * @author {@link [David Schach](https://github.com/dschach)}
	 */
	@TestVisible
	private Boolean isTriggerExecuting;

	/**
	 * The name of this handler. The Type constructor sets it. Without the Type constructor, `getHandlerName()` finds the name when it is first needed.
	 */
	private String handlerName;

	/**
	 * The maximum that means no limit. `clearMaxLoopCount()` sets it, and a `LoopCounter` stores a maximum of 0 or less as this value.
	 */
	private static final Integer NO_LOOP_LIMIT = -1;

	/**
	 * The value that `getLoopCount()` returns when `setMaxLoopCount()` was never called for the operation. The framework does not count those runs.
	 */
	@TestVisible
	private static final Integer NOT_COUNTED = -1;

	/**
	 * The character after the class name in the `toString()` text of an Apex object.
	 */
	private static final String CLASS_NAME_END = ':';

	/**
	 * The error text, in English, when `run()` is called outside a trigger.
	 */
	@TestVisible
	private static final String ERROR_TRIGGERCONTEXT = 'Trigger handler called outside of Trigger execution';

	/**
	 * The error text when a handler name is null or blank.
	 */
	@TestVisible
	private static final String ERROR_HANDLER_NAME = 'A handler name is required';

	/**
	 * The error text when a handler type is null.
	 */
	@TestVisible
	private static final String ERROR_HANDLER_TYPE = 'A handler type is required';

	/**
	 * The error text when a list of handler names is null.
	 */
	@TestVisible
	private static final String ERROR_HANDLER_NAMES = 'A list of handler names is required';

	/**
	 * The error text when a maximum loop count is null.
	 */
	@TestVisible
	private static final String ERROR_LOOP_COUNT = 'A maximum loop count is required';

	/**
	 * The error text when a trigger operation is null.
	 */
	@TestVisible
	private static final String ERROR_TRIGGER_OPERATION = 'A trigger operation is required';

	/**
	 * The error text when a bypass value is null.
	 */
	@TestVisible
	private static final String ERROR_BYPASS_VALUE = 'A bypass value is required';

	/**
	 * Creates a handler. The handler name comes from the runtime class name when the framework first needs it.
	 * <br>That lookup serializes all fields of the handler. To prevent the lookup, pass the handler type to the Type constructor.
	 * <br>For an inner class, the lookup gives only the short name, which does not match `bypass(Type)`. An inner-class handler must use the Type constructor.
	 * @see TriggerHandler.TriggerHandler[1]
	 * @example
	 * // in the trigger
	 * new OpportunityTriggerHandler().run();
	 * // in the handler class
	 * public OpportunityTriggerHandler() {
	 *   super();
	 *   this.newRecords = (List<Opportunity>) Trigger.new;
	 * }
	 */
	public TriggerHandler() {
		this.setTriggerContext();
	}

	/**
	 * Creates a handler with its type. The handler name is `Type.getName()`, so it always matches `bypass(Type)`, also for an inner class. The framework does no name lookup.
	 * <br>It replaces the String constructor `TriggerHandler(String handlerName)`, which version 2.0 removed. To upgrade a handler, change `super('ClassName')` to `super(ClassName.class)`.
	 * @param  handlerType The handler class, written as `ClassName.class`.
	 * @exception TriggerHandlerException when the type is null.
	 * @throws TriggerHandlerException when the type is null.
	 * @example
	 * // in the trigger
	 * new AccountSampleTriggerHandler().run();
	 * // in the handler class
	 * public AccountSampleTriggerHandler() {
	 *   super(AccountSampleTriggerHandler.class);
	 *   this.newRecords = (List<Account>) Trigger.new;
	 *   this.oldRecordsMap = (Map<Id, Account>) Trigger.oldMap;
	 * }
	 * // in an inner-class handler: the outer class name, a dot, and the inner class name
	 * public OpportunityTriggerHandler() {
	 *   super(SalesHandlers.OpportunityTriggerHandler.class);
	 * }
	 */
	protected TriggerHandler(Type handlerType) {
		requireHandlerType(handlerType);
		this.handlerName = handlerType.getName();
		this.setTriggerContext();
	}

	/**
	 * Runs the handler. Call it from the trigger. It calls the context method of the current trigger operation, and then `andFinally()`.
	 * <br>It does nothing when the handler is bypassed. When the loop limit stops the run, it only sends a warning to `log()`.
	 * <br>The switch names all 7 trigger operations, and `validateRun()` rejects a null operation. So this method suppresses `SwitchWithoutWhenElse`.
	 * @exception TriggerHandlerException when `run()` is called outside a trigger.
	 * @throws TriggerHandlerException when `run()` is called outside a trigger.
	 * @author {@link [Kevin OHara](https://github.com/kevinohara80)}
	 * @author {@link [David Schach](https://github.com/dschach)}
	 * @example
	 * trigger AccountSampleTrigger on Account(before insert, before update, before delete, after insert, after update, after delete, after undelete) {
	 *   new AccountSampleTriggerHandler().run();
	 * }
	 */
	@SuppressWarnings('PMD.SwitchWithoutWhenElse')
	public void run() {
		if (!validateRun()) {
			return;
		}

		// Past the loop limit, return with no exception. The counter already sent a warning to log().
		if (!incrementCheckLoopCount()) {
			return;
		}

		if (isDebugOn()) {
			log(LoggingLevel.DEBUG, String.format('Entering {0}, fired {1}', new List<String>{ getHandlerName(), triggerEvent.name() }));
		}

		// Call the context method of the current operation.
		switch on triggerEvent {
			when BEFORE_INSERT {
				beforeInsert();
			}
			when BEFORE_UPDATE {
				beforeUpdate();
			}
			when BEFORE_DELETE {
				beforeDelete();
			}
			when AFTER_INSERT {
				afterInsert();
			}
			when AFTER_UPDATE {
				afterUpdate();
			}
			when AFTER_DELETE {
				afterDelete();
			}
			when AFTER_UNDELETE {
				afterUndelete();
			}
		}
		andFinally();

		if (isLimitsOn()) {
			log(
				LoggingLevel.DEBUG,
				String.format(
					'{0} on {1} ({2}/{3} queries) and ({4}/{5} DML calls)',
					new List<String>{
						triggerEvent.name(),
						getHandlerName(),
						Limits.getQueries() + '',
						Limits.getLimitQueries() + '',
						Limits.getDmlStatements() + '',
						Limits.getLimitDmlStatements() + ''
					}
				)
			);
		}
		if (isDebugOn()) {
			log(LoggingLevel.DEBUG, String.format('Exiting {0}, fired {1}', new List<String>{ getHandlerName(), triggerEvent.name() }));
		}
	}

	/**
	 * Limits how many times `run()` runs this handler. Each trigger operation gets the same limit.
	 * <br>Each operation has its own count for the transaction. The count starts at the first call of `setMaxLoopCount()`, also with 0 or a negative value. Each chunk of 200 records counts as 1 run. A bypassed run does not count. A run that the limit stops counts.
	 * <br>When an operation passes its limit, `run()` sends a warning to `log()` and returns. It does not call the context method or `andFinally()`.
	 * @param  max The maximum number of runs of each operation. 0 or a negative value removes the limit.
	 * @return `TriggerHandler` This handler, so that you can chain calls.
	 * @exception TriggerHandlerException when the value is null.
	 * @throws TriggerHandlerException when the value is null.
	 * @see TriggerHandler.setMaxLoopCount[1]
	 * @author {@link [David Schach](https://github.com/dschach)}
	 * @example
	 * this.setMaxLoopCount(5); // in the handler constructor
	 * // or in the trigger
	 * new AccountSampleTriggerHandler().setMaxLoopCount(5).run();
	 */
	public TriggerHandler setMaxLoopCount(Integer max) {
		if (max == null) {
			throw new TriggerHandlerException(ERROR_LOOP_COUNT);
		}
		String handlerName = getHandlerName();
		for (System.TriggerOperation operation : System.TriggerOperation.values()) {
			TriggerHandler.loopCounters.setMax(handlerName, operation, max);
		}
		return this;
	}

	/**
	 * Limits how many times `run()` runs this handler for 1 trigger operation. The other operations keep their limits.
	 * <br>The count of the operation starts at the first call of `setMaxLoopCount()` for it, also with 0 or a negative value. Each chunk of 200 records counts as 1 run. A bypassed run does not count. A run that the limit stops counts.
	 * @param  operation The trigger operation to limit.
	 * @param  max The maximum number of runs of the operation. 0 or a negative value removes the limit.
	 * @return `TriggerHandler` This handler, so that you can chain calls.
	 * @exception TriggerHandlerException when the operation or the value is null.
	 * @throws TriggerHandlerException when the operation or the value is null.
	 * @example
	 * this.setMaxLoopCount(System.TriggerOperation.AFTER_UPDATE, 1); // in the handler constructor
	 */
	public TriggerHandler setMaxLoopCount(System.TriggerOperation operation, Integer max) {
		if (operation == null) {
			throw new TriggerHandlerException(ERROR_TRIGGER_OPERATION);
		}
		if (max == null) {
			throw new TriggerHandlerException(ERROR_LOOP_COUNT);
		}
		TriggerHandler.loopCounters.setMax(getHandlerName(), operation, max);
		return this;
	}

	/**
	 * Removes the limit of all trigger operations of this handler. The handler keeps its counters, so it still counts its runs.
	 * @example
	 * clearMaxLoopCount(); // in the handler
	 */
	public void clearMaxLoopCount() {
		TriggerHandler.loopCounters.clearMax(getHandlerName());
	}

	/**
	 * Bypasses a handler by name. The name matches in any case.
	 * @param handlerName The name of the handler to bypass.
	 * @exception TriggerHandlerException when the name is null or blank.
	 * @throws TriggerHandlerException when the name is null or blank.
	 * @example
	 * TriggerHandler.bypass('AccountSampleTriggerHandler');
	 */
	public static void bypass(String handlerName) {
		requireHandlerName(handlerName);
		TriggerHandler.bypasses.add(handlerName);
	}

	/**
	 * Bypasses a handler by type. The compiler checks the type, so the name cannot have a typo.
	 * @param handlerType The handler class, written as `ClassName.class`.
	 * @exception TriggerHandlerException when the type is null.
	 * @throws TriggerHandlerException when the type is null.
	 * @author {@link [vr8hub](https://github.com/vr8hub)}
	 * @example
	 * TriggerHandler.bypass(AccountSampleTriggerHandler.class);
	 */
	public static void bypass(Type handlerType) {
		requireHandlerType(handlerType);
		TriggerHandler.bypass(handlerType.getName());
	}

	/**
	 * Bypasses a list of handlers by name. It checks all names before it bypasses a handler.
	 * @param handlerNames The names of the handlers to bypass.
	 * @exception TriggerHandlerException when the list is null, or a name in it is null or blank.
	 * @throws TriggerHandlerException when the list is null, or a name in it is null or blank.
	 * @example
	 * TriggerHandler.bypass(new List<String>{ 'AccountSampleTriggerHandler', 'ContactTriggerHandler' });
	 */
	public static void bypass(List<String> handlerNames) {
		requireHandlerNames(handlerNames);
		for (String handlerName : handlerNames) {
			TriggerHandler.bypass(handlerName);
		}
	}

	/**
	 * Bypasses all handlers. The named bypasses stay, and they apply again after `clearGlobalBypass()`.
	 * @example
	 * TriggerHandler.bypassAll();
	 */
	public static void bypassAll() {
		TriggerHandler.bypasses.setAllBypassed(true);
	}

	/**
	 * Clears the bypass of a handler by name. The name matches in any case.
	 * @param handlerName The name of the handler.
	 * @exception TriggerHandlerException when the name is null or blank.
	 * @throws TriggerHandlerException when the name is null or blank.
	 * @author {@link [vr8hub](https://github.com/vr8hub)}
	 * @example
	 * TriggerHandler.clearBypass('AccountSampleTriggerHandler');
	 */
	public static void clearBypass(String handlerName) {
		requireHandlerName(handlerName);
		TriggerHandler.bypasses.remove(handlerName);
	}

	/**
	 * Clears the bypass of a handler by type.
	 * @param handlerType The handler class, written as `ClassName.class`.
	 * @exception TriggerHandlerException when the type is null.
	 * @throws TriggerHandlerException when the type is null.
	 * @example
	 * TriggerHandler.clearBypass(AccountSampleTriggerHandler.class);
	 */
	public static void clearBypass(Type handlerType) {
		requireHandlerType(handlerType);
		TriggerHandler.clearBypass(handlerType.getName());
	}

	/**
	 * Clears the bypass of a list of handlers by name. It checks all names before it clears a bypass.
	 * @param handlerNames The names of the handlers.
	 * @exception TriggerHandlerException when the list is null, or a name in it is null or blank.
	 * @throws TriggerHandlerException when the list is null, or a name in it is null or blank.
	 * @example
	 * TriggerHandler.clearBypass(new List<String>{ 'AccountSampleTriggerHandler', 'ContactTriggerHandler' });
	 */
	public static void clearBypass(List<String> handlerNames) {
		requireHandlerNames(handlerNames);
		for (String handlerName : handlerNames) {
			TriggerHandler.clearBypass(handlerName);
		}
	}

	/**
	 * Tells if a handler is bypassed by name or by type. The result does not include the global bypass. For the global bypass, use `isGlobalBypassed()`. For both, use `isSkipped()`.
	 * @param handlerName The name of the handler. It matches in any case.
	 * @return `Boolean` `true` when the handler is bypassed by name or by type.
	 * @exception TriggerHandlerException when the name is null or blank.
	 * @throws TriggerHandlerException when the name is null or blank.
	 * @see TriggerHandler.isSkipped[0]
	 * @example
	 * if (TriggerHandler.isBypassed('AccountSampleTriggerHandler')) {
	 *   // the handler is bypassed by name or by type
	 * }
	 */
	public static Boolean isBypassed(String handlerName) {
		requireHandlerName(handlerName);
		return TriggerHandler.bypasses.contains(handlerName);
	}

	/**
	 * Tells if a handler is bypassed by name or by type. The result does not include the global bypass. For the global bypass, use `isGlobalBypassed()`. For both, use `isSkipped()`.
	 * @param handlerType The handler class, written as `ClassName.class`.
	 * @return `Boolean` `true` when the handler is bypassed by name or by type.
	 * @exception TriggerHandlerException when the type is null.
	 * @throws TriggerHandlerException when the type is null.
	 * @see TriggerHandler.isSkipped[1]
	 * @since 2021
	 * @example
	 * if (TriggerHandler.isBypassed(AccountSampleTriggerHandler.class)) {
	 *   // the handler is bypassed by name or by type
	 * }
	 */
	public static Boolean isBypassed(Type handlerType) {
		requireHandlerType(handlerType);
		return TriggerHandler.isBypassed(handlerType.getName());
	}

	/**
	 * Tells if all handlers are bypassed, after `bypassAll()`.
	 * @return `Boolean` `true` when the global bypass is on.
	 * @example
	 * if (TriggerHandler.isGlobalBypassed()) {
	 *   // no handler runs
	 * }
	 */
	public static Boolean isGlobalBypassed() {
		return TriggerHandler.bypasses.isAllBypassed();
	}

	/**
	 * Tells if a handler does not run. A handler does not run when it is bypassed by name or by type, or when all handlers are bypassed. The result does not include the loop limit.
	 * @param handlerName The name of the handler. It matches in any case.
	 * @return `Boolean` `true` when the handler does not run.
	 * @exception TriggerHandlerException when the name is null or blank.
	 * @throws TriggerHandlerException when the name is null or blank.
	 * @example
	 * if (TriggerHandler.isSkipped('AccountSampleTriggerHandler')) {
	 *   // the handler does not run
	 * }
	 */
	public static Boolean isSkipped(String handlerName) {
		return TriggerHandler.isBypassed(handlerName) || TriggerHandler.bypasses.isAllBypassed();
	}

	/**
	 * Tells if a handler does not run. A handler does not run when it is bypassed by name or by type, or when all handlers are bypassed. The result does not include the loop limit.
	 * @param handlerType The handler class, written as `ClassName.class`.
	 * @return `Boolean` `true` when the handler does not run.
	 * @exception TriggerHandlerException when the type is null.
	 * @throws TriggerHandlerException when the type is null.
	 * @example
	 * if (TriggerHandler.isSkipped(AccountSampleTriggerHandler.class)) {
	 *   // the handler does not run
	 * }
	 */
	public static Boolean isSkipped(Type handlerType) {
		return TriggerHandler.isBypassed(handlerType) || TriggerHandler.bypasses.isAllBypassed();
	}

	/**
	 * Returns the handlers that are bypassed by name or by type, in sorted order, as the caller wrote them.
	 * <br>The list does not include the global bypass. For the global bypass, use `isGlobalBypassed()`.
	 * <br>It replaces the deprecated `bypassSet()`. A `List` also has `contains(value)`.
	 * @return `List<String>` The bypassed handlers.
	 * @example
	 * if (TriggerHandler.bypassList().contains('AccountSampleTriggerHandler')) {
	 *   // the handler is bypassed by name
	 * }
	 */
	public static List<String> bypassList() {
		return TriggerHandler.bypasses.sortedNames();
	}

	/**
	 * Returns the handlers that are bypassed by name or by type, as the caller wrote them.
	 * <br>The set does not include the global bypass. For the global bypass, use `isGlobalBypassed()`.
	 * @deprecated Use `bypassList()`, which holds the same names in sorted order. A later major release removes this method.
	 * @return `Set<String>` The bypassed handlers.
	 * @author David Schach
	 * @since 2022
	 * @example
	 * // before
	 * Boolean bypassed = TriggerHandler.bypassSet().contains('AccountSampleTriggerHandler');
	 * // after
	 * bypassed = TriggerHandler.bypassList().contains('AccountSampleTriggerHandler');
	 */
	public static Set<String> bypassSet() {
		return TriggerHandler.bypasses.nameSet();
	}

	/**
	 * Clears all bypasses: the global bypass and all named bypasses.
	 * @example
	 * TriggerHandler.clearAllBypasses();
	 */
	public static void clearAllBypasses() {
		clearGlobalBypass();
		clearBypassList();
	}

	/**
	 * Clears only the global bypass. The named bypasses stay.
	 * <br>Use it to keep a set of bypassed handlers for a full operation. After `bypassAll()` and `clearGlobalBypass()`, the handlers that were bypassed by name are still bypassed.
	 * @example
	 * TriggerHandler.clearGlobalBypass();
	 */
	public static void clearGlobalBypass() {
		TriggerHandler.bypasses.setAllBypassed(false);
	}

	/**
	 * Clears all named bypasses. The global bypass stays.
	 * <br>Use it to reset the named bypasses while all handlers stay bypassed.
	 * @example
	 * TriggerHandler.clearBypassList();
	 */
	public static void clearBypassList() {
		TriggerHandler.bypasses.clearNames();
	}

	/**
	 * Sets the named bypass of a handler to a value. You do not have to know the current status first.
	 * <br>`false` clears only the named bypass. A global bypass stays, so the handler does not run until `clearGlobalBypass()`.
	 * <br>`isBypassed()` tells only about the named bypass. So the save-and-restore example gives back the exact earlier state.
	 * @param  handlerName  The name of the handler.
	 * @param  desiredValue `true` to bypass the handler, `false` to clear its named bypass.
	 * @exception TriggerHandlerException when the name is null or blank, or the value is null.
	 * @throws TriggerHandlerException when the name is null or blank, or the value is null.
	 * @since 2021
	 * @author {@link [David Schach](https://github.com/dschach)}
	 * @example
	 * TriggerHandler.setBypass('AccountSampleTriggerHandler', false);
	 * // or save the state, bypass the handler, and restore the state
	 * Boolean wasBypassed = TriggerHandler.isBypassed('AccountSampleTriggerHandler');
	 * TriggerHandler.bypass('AccountSampleTriggerHandler');
	 * // update the records here
	 * TriggerHandler.setBypass('AccountSampleTriggerHandler', wasBypassed);
	 */
	public static void setBypass(String handlerName, Boolean desiredValue) {
		requireHandlerName(handlerName);
		if (desiredValue == null) {
			throw new TriggerHandlerException(ERROR_BYPASS_VALUE);
		}
		if (desiredValue) {
			TriggerHandler.bypass(handlerName);
			return;
		}
		TriggerHandler.clearBypass(handlerName);
	}

	/**
	 * Sets the named bypass of a handler, given by type, to a value. It works as the String form does, with `Type.getName()` as the name.
	 * @param  handlerType  The handler class, written as `ClassName.class`.
	 * @param  desiredValue `true` to bypass the handler, `false` to clear its named bypass.
	 * @exception TriggerHandlerException when the type is null, or the value is null.
	 * @throws TriggerHandlerException when the type is null, or the value is null.
	 * @see TriggerHandler.setBypass[0]
	 * @example
	 * Boolean wasBypassed = TriggerHandler.isBypassed(AccountSampleTriggerHandler.class);
	 * TriggerHandler.bypass(AccountSampleTriggerHandler.class);
	 * // update the records here
	 * TriggerHandler.setBypass(AccountSampleTriggerHandler.class, wasBypassed);
	 */
	public static void setBypass(Type handlerType, Boolean desiredValue) {
		requireHandlerType(handlerType);
		TriggerHandler.setBypass(handlerType.getName(), desiredValue);
	}

	// limits line

	/**
	 * Makes all handlers that run later in the transaction write the limits line. You can chain this method.
	 * <br>The setting is static, so it applies to all handlers, not only to this handler.
	 * @deprecated Use `showHandlerLimits()` for this handler only, or the static `showLimits()` for all handlers. A later major release removes this method.
	 * @return `TriggerHandler` This handler, so that you can chain calls.
	 * @see TriggerHandler.showLimits[0]
	 * @since 2023
	 * @example
	 * // before
	 * new AccountSampleTriggerHandler().limits().run();
	 * // after, for this handler only
	 * new AccountSampleTriggerHandler().showHandlerLimits().run();
	 */
	public TriggerHandler limits() {
		showLimits();
		return this;
	}

	/**
	 * Sets whether all handlers that run later in the transaction write the limits line. You can chain this method.
	 * <br>The setting is static, so it applies to all handlers, not only to this handler.
	 * @deprecated Use `showHandlerLimits(Boolean)` for this handler only, or the static `showLimits(Boolean)` for all handlers. A later major release removes this method.
	 * @param enabled `true` to write the line, `false` or null to stop it.
	 * @return `TriggerHandler` This handler, so that you can chain calls.
	 * @see TriggerHandler.showLimits[1]
	 * @since 2023
	 * @example
	 * // before
	 * new AccountSampleTriggerHandler().limits(false).run();
	 * // after, for this handler only
	 * new AccountSampleTriggerHandler().showHandlerLimits(false).run();
	 */
	public TriggerHandler limits(Boolean enabled) {
		showLimits(enabled);
		return this;
	}

	/**
	 * Makes all handlers that run later in the transaction write the limits line. A handler with its own setting from `showHandlerLimits()` keeps it.
	 * <br>Call it in the trigger or in a handler.
	 * @see TriggerHandler.showLimits[1]
	 * @example
	 * TriggerHandler.showLimits(); // in the trigger, before the handler runs
	 * new AccountSampleTriggerHandler().run();
	 */
	public static void showLimits() {
		showLimits(true);
	}

	/**
	 * Sets whether all handlers that run later in the transaction write the limits line. A handler with its own setting from `showHandlerLimits()` keeps it.
	 * @param enabled `true` to write the line, `false` or null to stop it.
	 * @see TriggerHandler.showLimits[0]
	 * @example
	 * TriggerHandler.showLimits(false);
	 */
	public static void showLimits(Boolean enabled) {
		doShowLimits = enabled ?? false;
	}

	// entry and exit lines

	/**
	 * Makes all handlers that run later in the transaction write the entry and exit lines. You can chain this method.
	 * <br>The setting is static, so it applies to all handlers, not only to this handler.
	 * @deprecated Use `showHandlerDebug()` for this handler only, or the static `showDebug()` for all handlers. A later major release removes this method.
	 * @return `TriggerHandler` This handler, so that you can chain calls.
	 * @see TriggerHandler.showDebug[0]
	 * @since 2023
	 * @example
	 * // before
	 * new AccountSampleTriggerHandler().debug().run();
	 * // after, for this handler only
	 * new AccountSampleTriggerHandler().showHandlerDebug().run();
	 */
	public TriggerHandler debug() {
		showDebug();
		return this;
	}

	/**
	 * Sets whether all handlers that run later in the transaction write the entry and exit lines. You can chain this method.
	 * <br>The setting is static, so it applies to all handlers, not only to this handler.
	 * @deprecated Use `showHandlerDebug(Boolean)` for this handler only, or the static `showDebug(Boolean)` for all handlers. A later major release removes this method.
	 * @param enabled `true` to write the lines, `false` or null to stop them.
	 * @return `TriggerHandler` This handler, so that you can chain calls.
	 * @see TriggerHandler.showDebug[1]
	 * @since 2023
	 * @example
	 * // before
	 * new AccountSampleTriggerHandler().debug(false).run();
	 * // after, for this handler only
	 * new AccountSampleTriggerHandler().showHandlerDebug(false).run();
	 */
	public TriggerHandler debug(Boolean enabled) {
		showDebug(enabled);
		return this;
	}

	/**
	 * Makes all handlers that run later in the transaction write the entry and exit lines. A handler with its own setting from `showHandlerDebug()` keeps it.
	 * <br>Call it in the trigger or in a handler.
	 * @see TriggerHandler.showDebug[1]
	 * @author {@link [David Schach](https://github.com/dschach)}
	 * @since 2021
	 * @example
	 * TriggerHandler.showDebug(); // in the trigger, before the handler runs
	 * new AccountSampleTriggerHandler().run();
	 */
	public static void showDebug() {
		showDebug(true);
	}

	/**
	 * Sets whether all handlers that run later in the transaction write the entry and exit lines. A handler with its own setting from `showHandlerDebug()` keeps it.
	 * @param enabled `true` to write the lines, `false` or null to stop them.
	 * @see TriggerHandler.showDebug[0]
	 * @author {@link [David Schach](https://github.com/dschach)}
	 * @since 2021
	 * @example
	 * TriggerHandler.showDebug(false);
	 */
	public static void showDebug(Boolean enabled) {
		doShowDebug = enabled ?? false;
	}

	/**
	 * Makes this handler write the limits line. Other handlers keep their own setting or the static setting.
	 * @return `TriggerHandler` This handler, so that you can chain calls.
	 * @see TriggerHandler.showHandlerLimits[1]
	 * @example
	 * new AccountSampleTriggerHandler().showHandlerLimits().run();
	 */
	public TriggerHandler showHandlerLimits() {
		return showHandlerLimits(true);
	}

	/**
	 * Sets whether this handler writes the limits line. This setting wins over the static `showLimits()`.
	 * @param enabled `true` to write the line, `false` to stop it for this handler, or null to use the static setting again.
	 * @return `TriggerHandler` This handler, so that you can chain calls.
	 * @see TriggerHandler.showHandlerLimits[0]
	 * @example
	 * new AccountSampleTriggerHandler().showHandlerLimits(false).run();
	 */
	public TriggerHandler showHandlerLimits(Boolean enabled) {
		handlerShowLimits = enabled;
		return this;
	}

	/**
	 * Makes this handler write the entry and exit lines. Other handlers keep their own setting or the static setting.
	 * @return `TriggerHandler` This handler, so that you can chain calls.
	 * @see TriggerHandler.showHandlerDebug[1]
	 * @example
	 * new AccountSampleTriggerHandler().showHandlerDebug().run();
	 */
	public TriggerHandler showHandlerDebug() {
		return showHandlerDebug(true);
	}

	/**
	 * Sets whether this handler writes the entry and exit lines. This setting wins over the static `showDebug()`.
	 * @param enabled `true` to write the lines, `false` to stop them for this handler, or null to use the static setting again.
	 * @return `TriggerHandler` This handler, so that you can chain calls.
	 * @see TriggerHandler.showHandlerDebug[0]
	 * @example
	 * new AccountSampleTriggerHandler().showHandlerDebug(false).run();
	 */
	public TriggerHandler showHandlerDebug(Boolean enabled) {
		handlerShowDebug = enabled;
		return this;
	}

	/**
	 * Tells if this handler writes the limits line. It uses the setting of the handler, or the static setting when the handler has none.
	 * @return `Boolean` `true` when this handler writes the limits line.
	 */
	private Boolean isLimitsOn() {
		return handlerShowLimits ?? doShowLimits;
	}

	/**
	 * Tells if this handler writes the entry and exit lines. It uses the setting of the handler, or the static setting when the handler has none.
	 * @return `Boolean` `true` when this handler writes the entry and exit lines.
	 */
	private Boolean isDebugOn() {
		return handlerShowDebug ?? doShowDebug;
	}

	/**
	 * Returns the number of runs of a handler in this transaction, for all trigger operations together. The count includes the runs that the loop limit stopped.
	 * <br>The name must be the handler name in the same case, as `getHandlerName()` returns it. Unlike a bypass name, it does not match in any case.
	 * @deprecated Use `getLoopCount(String, System.TriggerOperation)` for the count of 1 trigger operation. A later major release removes this method.
	 * @param handlerName The name of the handler.
	 * @return `Integer` The total count, or -1 when `setMaxLoopCount()` was never called for the handler.
	 * @exception TriggerHandlerException when the name is null or blank.
	 * @throws TriggerHandlerException when the name is null or blank.
	 * @example
	 * Integer runs = TriggerHandler.getLoopCount('AccountSampleTriggerHandler');
	 */
	public static Integer getLoopCount(String handlerName) {
		requireHandlerName(handlerName);
		return TriggerHandler.loopCounters.total(handlerName);
	}

	/**
	 * Returns the number of runs of 1 trigger operation of a handler in this transaction. The count includes the runs that the loop limit stopped.
	 * <br>The name must be the handler name in the same case, as `getHandlerName()` returns it. Unlike a bypass name, it does not match in any case.
	 * @param handlerName The name of the handler.
	 * @param operation The trigger operation.
	 * @return `Integer` The count, or -1 when `setMaxLoopCount()` was never called for the operation.
	 * @exception TriggerHandlerException when the name is null or blank, or the operation is null.
	 * @throws TriggerHandlerException when the name is null or blank, or the operation is null.
	 * @example
	 * Integer runs = TriggerHandler.getLoopCount('AccountSampleTriggerHandler', System.TriggerOperation.AFTER_UPDATE);
	 */
	public static Integer getLoopCount(String handlerName, System.TriggerOperation operation) {
		requireHandlerName(handlerName);
		if (operation == null) {
			throw new TriggerHandlerException(ERROR_TRIGGER_OPERATION);
		}
		return TriggerHandler.loopCounters.count(handlerName, operation);
	}

	/**
	 * Sets the current context from `Trigger.operationType`. Both constructors call it.
	 * <br>Outside a trigger, `isTriggerExecuting` is false. A test sets its own context with `setTestContext()`.
	 * @see TriggerHandler.isTriggerExecuting
	 */
	private void setTriggerContext() {
		triggerEvent = Trigger.operationType;
		isTriggerExecuting = Trigger.isExecuting && triggerEvent != null;
	}

	/**
	 * Adds this run to the counter of the current trigger operation, when the operation has a counter. Then it checks the limit.
	 * <br>When the count passes the limit, it writes a warning. `run()` then returns before the context method and `andFinally()`.
	 * @return `Boolean` `true` when `run()` continues: the operation has no counter, or the count is in the limit. `false` when the count passes the limit.
	 * @author {@link [David Schach](https://github.com/dschach)}
	 * @author {@link [fbouzeraa](https://github.com/fbouzeraa)}
	 */
	private Boolean incrementCheckLoopCount() {
		if (TriggerHandler.loopCounters.isEmpty()) {
			return true;
		}
		LoopCounter counter = TriggerHandler.loopCounters.get(getHandlerName(), triggerEvent);
		if (counter == null || !counter.increment()) {
			return true;
		}
		log(LoggingLevel.WARN, 'Maximum loop count of ' + counter.getMax() + ' exceeded in ' + getHandlerName() + ', so run() stopped ' + triggerEvent.name());
		return false;
	}

	/**
	 * Tells if this run continues. With `false`, `run()` returns before the context method.
	 * @return `Boolean` `true` when the handler runs, `false` when it is skipped.
	 * @exception TriggerHandlerException when `run()` is called outside a trigger.
	 * @throws TriggerHandlerException when `run()` is called outside a trigger.
	 * @see TriggerHandler.TriggerHandlerException
	 */
	private Boolean validateRun() {
		if (!isTriggerExecuting || triggerEvent == null) {
			throw new TriggerHandlerException(ERROR_TRIGGERCONTEXT);
		}
		if (TriggerHandler.bypasses.isAllBypassed()) {
			return false;
		}
		// the same rule as isSkipped(); with no named bypass, the handler name is not needed
		return !TriggerHandler.bypasses.hasNames() || !TriggerHandler.isBypassed(getHandlerName());
	}

	/**
	 * Returns the trigger operation of the current run. In a test that runs the handler without DML, `setTestContext()` sets it, because `Trigger.operationType` is null there.
	 * @return `System.TriggerOperation` The current operation, or null outside a trigger.
	 */
	protected System.TriggerOperation getTriggerEvent() {
		return triggerEvent;
	}

	/**
	 * Returns the name of this handler: `Type.getName()` from the Type constructor, or the runtime class name.
	 * <br>A subclass can use it, for example in a log line or in a `bypass()` call.
	 * <br>The runtime lookup reads the start of `toString()`. For an inner class, it gives only the short name. A handler that is an inner class, or that overrides `toString()`, must pass its type to the Type constructor.
	 * @return `String` The name of this handler.
	 * @see TriggerHandler.handlerName
	 */
	@TestVisible
	protected String getHandlerName() {
		if (String.isBlank(handlerName)) {
			handlerName = toString().substringBefore(CLASS_NAME_END);
		}
		return handlerName;
	}

	/**
	 * Makes this handler run as if a trigger fired the operation. A test can then call `run()` without DML.
	 * <br>Before you call `run()`, set the records that the handler reads, for example through `@TestVisible` fields of the handler.
	 * <br>Outside a test, it changes nothing. The handler keeps the context of the real trigger.
	 * <br>A null operation clears the context. `run()` then throws, as it does outside a trigger.
	 * @param operation The trigger operation to simulate.
	 * @return `TriggerHandler` This handler, so that you can chain calls.
	 * @example
	 * AccountSampleTriggerHandler handler = new AccountSampleTriggerHandler();
	 * // set the records that the handler reads, and then:
	 * handler.setTestContext(System.TriggerOperation.BEFORE_INSERT).run();
	 */
	@TestVisible
	protected TriggerHandler setTestContext(System.TriggerOperation operation) {
		if (Test.isRunningTest()) {
			triggerEvent = operation;
			isTriggerExecuting = operation != null;
		}
		return this;
	}

	/**
	 * Writes a message from the framework. The messages are the entry, exit, and limits lines when they are on, and the warning when a run passes the loop limit.
	 * <br>The default writes to the debug log. Override it to send the messages to the logging framework of your org, such as {@link [Nebula Logger](https://github.com/jongpie/NebulaLogger)}. The README has an example.
	 * @param level The logging level of the message.
	 * @param message The message.
	 * @example
	 * // in the handler class
	 * protected override void log(LoggingLevel level, String message) {
	 *   // send the message to the logging framework here
	 *   super.log(level, message);
	 * }
	 */
	protected virtual void log(LoggingLevel level, String message) {
		System.debug(level, message); // NOPMD
	}

	// context methods

	/**
	 * Runs in the before insert context. Override it in the handler. The base method does nothing.
	 */
	protected virtual void beforeInsert() {
	}

	/**
	 * Runs in the before update context. Override it in the handler. The base method does nothing.
	 */
	protected virtual void beforeUpdate() {
	}

	/**
	 * Runs in the before delete context. Override it in the handler. The base method does nothing.
	 */
	protected virtual void beforeDelete() {
	}

	/**
	 * Runs in the after insert context. Override it in the handler. The base method does nothing.
	 */
	protected virtual void afterInsert() {
	}

	/**
	 * Runs in the after update context. Override it in the handler. The base method does nothing.
	 */
	protected virtual void afterUpdate() {
	}

	/**
	 * Runs in the after delete context. Override it in the handler. The base method does nothing.
	 */
	protected virtual void afterDelete() {
	}

	/**
	 * Runs in the after undelete context. Override it in the handler. The base method does nothing.
	 */
	protected virtual void afterUndelete() {
	}

	/**
	 * Runs after the context method returns, in all trigger contexts. It also runs in a context that the handler does not override.
	 * <br>It does not run when the handler is bypassed. Then nothing in the handler runs.
	 * <br>It does not run when the loop limit stops the run. Then only `log()` runs, with the loop limit warning.
	 * <br>It does not run when the context method throws an exception that it does not catch.
	 * <br>It runs when the context method catches its own exception or calls `addError()`.
	 * <br>After a run starts its context method, a bypass cannot stop the `andFinally()` of that run. For example, the context method bypasses this handler and updates records of the same object. The handler skips the run for that update, and the `andFinally()` of the first run comes last.
	 * <br>If `andFinally()` throws, the exception reaches the caller, and the handler does not write the exit and limits lines.
	 * <br>Credit to James Simone for this idea.
	 * @see [The Joys of Apex](https://www.jamessimone.net/blog/joys-of-apex/lightweight-trigger-handler/)
	 * @author James Simone
	 * @since 2023-02-24
	 * @example
	 * // andFinally() runs after the before context and again after the after context.
	 * // This work runs only once for each chunk of 200 records, in the after context.
	 * public override void andFinally() {
	 *   if (getTriggerEvent() == System.TriggerOperation.AFTER_UPDATE) {
	 *     publishChangeEvent();
	 *   }
	 * }
	 */
	protected virtual void andFinally() {
	}

	// inner classes

	/**
	 * Holds the bypasses of the transaction: the named bypasses and the global bypass. The 2 are independent.
	 * <br>`TriggerHandler` keeps 1 instance in `bypasses`, because an inner class cannot have static members. The public static methods check their arguments and then call it.
	 */
	@TestVisible
	private inherited sharing class BypassRegistry {
		/**
		 * All handlers that are bypassed by name or by type, as the caller wrote them.
		 */
		private Set<String> names = new Set<String>();
		/**
		 * A lower-case copy of `names`. All membership checks use it, so a name matches in any case.
		 */
		private Set<String> namesLower = new Set<String>();
		/**
		 * `true` when all handlers are bypassed.
		 */
		private Boolean allBypassed = false;

		/**
		 * Bypasses a handler by name.
		 * @param handlerName The name. It is not null or blank.
		 */
		public void add(String handlerName) {
			names.add(handlerName);
			namesLower.add(handlerName.toLowerCase());
		}

		/**
		 * Clears the bypass of a handler by name, in any case. A name that is not bypassed changes nothing.
		 * @param handlerName The name. It is not null or blank.
		 */
		public void remove(String handlerName) {
			if (!namesLower.remove(handlerName.toLowerCase())) {
				return;
			}
			for (String bypassedName : new List<String>(names)) {
				if (bypassedName.equalsIgnoreCase(handlerName)) {
					names.remove(bypassedName);
				}
			}
		}

		/**
		 * Tells if a handler is bypassed by name, in any case.
		 * @param handlerName The name. It is not null or blank.
		 * @return `Boolean` `true` when the name is bypassed.
		 */
		public Boolean contains(String handlerName) {
			return namesLower.contains(handlerName.toLowerCase());
		}

		/**
		 * Tells if 1 or more handlers are bypassed by name.
		 * @return `Boolean` `true` when 1 or more names are bypassed.
		 */
		public Boolean hasNames() {
			return !namesLower.isEmpty();
		}

		/**
		 * Returns the bypassed names in sorted order, as the caller wrote them.
		 * @return `List<String>` A new sorted list.
		 */
		public List<String> sortedNames() {
			List<String> sorted = new List<String>(names);
			sorted.sort();
			return sorted;
		}

		/**
		 * Returns the bypassed names, as the caller wrote them.
		 * @return `Set<String>` A new set.
		 */
		public Set<String> nameSet() {
			return new Set<String>(names);
		}

		/**
		 * Clears all named bypasses. The global bypass stays.
		 */
		public void clearNames() {
			names.clear();
			namesLower.clear();
		}

		/**
		 * Tells if all handlers are bypassed.
		 * @return `Boolean` `true` when the global bypass is on.
		 */
		public Boolean isAllBypassed() {
			return allBypassed;
		}

		/**
		 * Sets the global bypass. The named bypasses stay.
		 * @param value `true` to bypass all handlers, `false` to clear the global bypass.
		 */
		public void setAllBypassed(Boolean value) {
			allBypassed = value;
		}
	}

	/**
	 * Holds the loop counters of the transaction, by handler name and then by trigger operation.
	 * <br>`TriggerHandler` keeps 1 instance in `loopCounters`, because an inner class cannot have static members. The public methods check their arguments and then call it.
	 */
	@TestVisible
	private inherited sharing class LoopCounterRegistry {
		/**
		 * The loop counters of each handler, by handler name and then by trigger operation.
		 */
		private Map<String, Map<System.TriggerOperation, LoopCounter>> counters = new Map<String, Map<System.TriggerOperation, LoopCounter>>();

		/**
		 * Tells if no handler has a counter. Then `run()` does not look up the handler name.
		 * @return `Boolean` `true` when no handler called `setMaxLoopCount()` in the transaction.
		 */
		public Boolean isEmpty() {
			return counters.isEmpty();
		}

		/**
		 * Returns the counter of 1 trigger operation of a handler.
		 * @param handlerName The name of the handler.
		 * @param operation The trigger operation.
		 * @return `LoopCounter` The counter, or null when `setMaxLoopCount()` was never called for the operation.
		 */
		public LoopCounter get(String handlerName, System.TriggerOperation operation) {
			return counters.get(handlerName)?.get(operation);
		}

		/**
		 * Sets the limit of 1 trigger operation of a handler. It creates the counter when the operation has none.
		 * @param handlerName The name of the handler.
		 * @param operation The trigger operation.
		 * @param max The maximum number of runs. 0 or a negative value means no limit.
		 */
		public void setMax(String handlerName, System.TriggerOperation operation, Integer max) {
			Map<System.TriggerOperation, LoopCounter> handlerCounters = counters.get(handlerName);
			if (handlerCounters == null) {
				handlerCounters = new Map<System.TriggerOperation, LoopCounter>();
				counters.put(handlerName, handlerCounters);
			}
			LoopCounter counter = handlerCounters.get(operation);
			if (counter == null) {
				handlerCounters.put(operation, new LoopCounter(max));
			} else {
				counter.setMax(max);
			}
		}

		/**
		 * Removes the limit of all counters of a handler. The counters keep their counts. It creates no counter.
		 * @param handlerName The name of the handler.
		 */
		public void clearMax(String handlerName) {
			for (LoopCounter counter : counters.get(handlerName)?.values() ?? new List<LoopCounter>()) {
				counter.setMax(NO_LOOP_LIMIT);
			}
		}

		/**
		 * Returns the count of 1 trigger operation of a handler.
		 * @param handlerName The name of the handler.
		 * @param operation The trigger operation.
		 * @return `Integer` The count, or `NOT_COUNTED` when `setMaxLoopCount()` was never called for the operation.
		 */
		public Integer count(String handlerName, System.TriggerOperation operation) {
			return get(handlerName, operation)?.getCount() ?? NOT_COUNTED;
		}

		/**
		 * Returns the total count of all trigger operations of a handler.
		 * @param handlerName The name of the handler.
		 * @return `Integer` The total, or `NOT_COUNTED` when `setMaxLoopCount()` was never called for the handler.
		 */
		public Integer total(String handlerName) {
			Map<System.TriggerOperation, LoopCounter> handlerCounters = counters.get(handlerName);
			if (handlerCounters == null) {
				return NOT_COUNTED;
			}
			Integer sum = 0;
			for (LoopCounter counter : handlerCounters.values()) {
				sum += counter.getCount();
			}
			return sum;
		}
	}

	/**
	 * Counts the runs of 1 trigger operation of 1 handler, and compares the count with a maximum.
	 */
	@TestVisible
	private inherited sharing class LoopCounter {
		/**
		 * The maximum number of runs, or `NO_LOOP_LIMIT` for no limit.
		 */
		private Integer max;
		/**
		 * The number of runs so far, with the runs that the limit stopped.
		 */
		private Integer loopCount;

		/**
		 * Creates a counter with a maximum. The count starts at 0.
		 * @param maxCount The maximum number of runs. 0 or a negative value means no limit.
		 */
		public LoopCounter(Integer maxCount) {
			setMax(maxCount);
			this.loopCount = 0;
		}

		/**
		 * Adds 1 to the count and returns `exceeded()`.
		 * @return `Boolean` `true` when the new count is more than the maximum. A counter with no limit never passes it.
		 */
		public Boolean increment() {
			loopCount++;
			return exceeded();
		}

		/**
		 * Tells if the count passed the limit.
		 * @return `Boolean` `true` when the counter has a limit and the count is more than the limit.
		 */
		public Boolean exceeded() {
			return max != NO_LOOP_LIMIT && loopCount > max;
		}

		/**
		 * Returns the maximum number of runs.
		 * @return `Integer` The maximum, or -1 when there is no limit.
		 */
		public Integer getMax() {
			return max;
		}

		/**
		 * Returns the number of runs so far, with the runs that the limit stopped.
		 * @return `Integer` The count.
		 */
		public Integer getCount() {
			return loopCount;
		}

		/**
		 * Sets the maximum number of runs. The count does not change. A maximum of 0 or less becomes `NO_LOOP_LIMIT`.
		 * @param maxCount The new maximum. 0 or a negative value means no limit.
		 */
		public void setMax(Integer maxCount) {
			max = maxCount > 0 ? maxCount : NO_LOOP_LIMIT;
		}
	}

	/**
	 * Rejects a null or blank handler name.
	 * @param handlerName The name to check.
	 * @exception TriggerHandlerException when the name is null or blank.
	 * @throws TriggerHandlerException when the name is null or blank.
	 */
	private static void requireHandlerName(String handlerName) {
		if (String.isBlank(handlerName)) {
			throw new TriggerHandlerException(ERROR_HANDLER_NAME);
		}
	}

	/**
	 * Rejects a null handler type.
	 * @param handlerType The type to check.
	 * @exception TriggerHandlerException when the type is null.
	 * @throws TriggerHandlerException when the type is null.
	 */
	private static void requireHandlerType(Type handlerType) {
		if (handlerType == null) {
			throw new TriggerHandlerException(ERROR_HANDLER_TYPE);
		}
	}

	/**
	 * Rejects a null list, or a list with a null or blank name, before the method uses a name.
	 * @param handlerNames The names to check.
	 * @exception TriggerHandlerException when the list is null or has a null or blank name.
	 * @throws TriggerHandlerException when the list is null or has a null or blank name.
	 */
	private static void requireHandlerNames(List<String> handlerNames) {
		if (handlerNames == null) {
			throw new TriggerHandlerException(ERROR_HANDLER_NAMES);
		}
		for (String handlerName : handlerNames) {
			requireHandlerName(handlerName);
		}
	}

	/**
	 * The exception that the framework throws for a wrong call.
	 */
	public class TriggerHandlerException extends Exception {
	}
}