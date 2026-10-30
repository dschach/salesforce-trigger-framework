/**
 * Trigger handler abstract class, the base for every trigger handler. A handler extends it, and code cannot build the base class itself.
 * @author {@link [Kevin OHara](https://github.com/kevinohara80)}
 * @since 2013
 * @author {@link [David Schach](https://github.com/dschach)}
 * @since 2021
 * @since 2023-02-24 add andFinally method
 * @since 2023-09 method chaining
 * @group Trigger Handler
 * @see [License](https://github.com/dschach/salesforce-trigger-framework/blob/main/LICENSE)
 * @see [GitHub](https://github.com/dschach/salesforce-trigger-framework)
 * @see TriggerHandlerTest
 */
@SuppressWarnings('PMD.ExcessivePublicCount, PMD.CyclomaticComplexity, PMD.CognitiveComplexity, PMD.EmptyStatementBlock')
public inherited sharing abstract class TriggerHandler {
	/**
	 * The loop counters of every handler in the transaction. A handler has a counter for an operation only after a limit is set for that operation, so `getLoopCount()` returns `NOT_COUNTED` for an operation with no limit.
	 */
	private static LoopCounterRegistry loopCounters = new LoopCounterRegistry();

	/**
	 * The bypasses of the transaction: the named bypasses and the global bypass.
	 */
	private static BypassRegistry bypasses = new BypassRegistry();

	/**
	 * `true` when every handler writes the limits line after its run. `showLimits()` and `showLimits(Boolean)` set it.
	 */
	@TestVisible
	private static Boolean doShowLimits = false;

	/**
	 * `true` when every handler writes the entry and exit lines of its run. `showDebug()` and `showDebug(Boolean)` set it.
	 */
	@TestVisible
	private static Boolean doShowDebug = false;

	/**
	 * This handler's own setting for the limits line: `true` or `false`, or null to use `doShowLimits`. `showHandlerLimits()` and `showHandlerLimits(Boolean)` set it.
	 */
	private Boolean handlerShowLimits;

	/**
	 * This handler's own setting for the entry and exit lines: `true` or `false`, or null to use `doShowDebug`. `showHandlerDebug()` and `showHandlerDebug(Boolean)` set it.
	 */
	private Boolean handlerShowDebug;

	/**
	 * The current operation of the trigger. Tests can set it.
	 */
	@TestVisible
	private System.TriggerOperation triggerEvent;

	/**
	 * Whether this handler is running inside a trigger.
	 * @author {@link [David Schach](https://github.com/dschach)}
	 */
	@TestVisible
	private Boolean isTriggerExecuting;

	/**
	 * The name of this handler. Set by the Type constructor, or resolved by `getHandlerName()` the first time it is needed.
	 */
	private String handlerName;

	/**
	 * The maximum loop count that means no limit. `clearMaxLoopCount()` sets it, and a `LoopCounter` stores a maximum of 0 or less as this value.
	 */
	private static final Integer NO_LOOP_LIMIT = -1;

	/**
	 * The count that `getLoopCount()` returns when no limit was ever set, so the runs are not counted.
	 */
	@TestVisible
	private static final Integer NOT_COUNTED = -1;

	/**
	 * The character that ends the class name in the `toString()` text of an Apex object.
	 */
	private static final String CLASS_NAME_END = ':';

	/**
	 * Error text for a run outside a trigger. English only.
	 */
	@TestVisible
	private static final String ERROR_TRIGGERCONTEXT = 'Trigger handler called outside of Trigger execution';

	/**
	 * Error text when a handler name is null or blank.
	 */
	@TestVisible
	private static final String ERROR_HANDLER_NAME = 'A handler name is required';

	/**
	 * Error text when a handler type is null.
	 */
	@TestVisible
	private static final String ERROR_HANDLER_TYPE = 'A handler type is required';

	/**
	 * Error text when a list of handler names is null.
	 */
	@TestVisible
	private static final String ERROR_HANDLER_NAMES = 'A list of handler names is required';

	/**
	 * Error text when the maximum loop count is null.
	 */
	@TestVisible
	private static final String ERROR_LOOP_COUNT = 'A maximum loop count is required';

	/**
	 * Error text when the trigger operation is null.
	 */
	@TestVisible
	private static final String ERROR_TRIGGER_OPERATION = 'A trigger operation is required';

	/**
	 * Error text when the desired bypass value is null.
	 */
	@TestVisible
	private static final String ERROR_BYPASS_VALUE = 'A bypass value is required';

	/**
	 * Basic constructor. The handler name is resolved from the runtime class name the first time a bypass, a loop count, or a debug line needs it.
	 * <br>That lookup serializes every field of the handler, so pass the handler's type to the Type constructor to avoid it.
	 * <br>The lookup gives only the short name of an inner class, which does not match `bypass(Type)`, so an inner-class handler must use the Type constructor.
	 * @see TriggerHandler.TriggerHandler[1]
	 * @example
	 * new AccountSampleTriggerHandler().run();
	 * // in the trigger handler class
	 * public AccountSampleTriggerHandler() {
	 *   super();
	 *   this.newRecords = (List<Account>) Trigger.new;
	 *   this.oldRecords = (List<Account>) Trigger.old;
	 *   this.newRecordsMap = (Map<Id, Account>) Trigger.newMap;
	 *   this.oldRecordsMap = (Map<Id, Account>) Trigger.oldMap;
	 * }
	 */
	public TriggerHandler() {
		this.setTriggerContext();
	}

	/**
	 * Constructor with the handler type. The handler name is `Type.getName()`, so it always matches `bypass(Type)`, also for an inner class, and no runtime lookup is needed.
	 * <br>It replaces the String constructor `TriggerHandler(String handlerName)`, which version 2.0 removed. To upgrade a handler, change `super('ClassName')` to `super(ClassName.class)`.
	 * @param  handlerType The class of the handler, written as `ClassName.class`.
	 * @exception TriggerHandlerException when the type is null.
	 * @throws TriggerHandlerException when the type is null.
	 * @example
	 * new AccountSampleTriggerHandler().run();
	 * // in the trigger handler class
	 * public AccountSampleTriggerHandler() {
	 *   super(AccountSampleTriggerHandler.class);
	 *   this.newRecords = (List<Account>) Trigger.new;
	 *   this.oldRecords = (List<Account>) Trigger.old;
	 *   this.newRecordsMap = (Map<Id, Account>) Trigger.newMap;
	 *   this.oldRecordsMap = (Map<Id, Account>) Trigger.oldMap;
	 * }
	 * // in a handler that is an inner class, write the outer class name, a dot, and the inner class name
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
	 * Main method, called from the trigger. It dispatches to the context method and then to `andFinally()`.
	 * <br>See the sample trigger for the best way to set up your handler.
	 * <br>The switch names all 7 trigger operations, and `validateRun()` rejects a null operation, so `SwitchWithoutWhenElse` is suppressed for this method.
	 * @author {@link [Kevin OHara](https://github.com/kevinohara80)}
	 * @author {@link [David Schach](https://github.com/dschach)}
	 * @example
	 * new AccountSampleTriggerHandler().run();
	 */
	@SuppressWarnings('PMD.SwitchWithoutWhenElse')
	public void run() {
		if (!validateRun()) {
			return;
		}

		// Do not throw an exception if we exceed the loop count - just stop executing
		if (!incrementCheckLoopCount()) {
			return;
		}

		if (isDebugOn()) {
			log(LoggingLevel.DEBUG, String.format('Entering {0}, fired {1}', new List<String>{ getHandlerName(), triggerEvent.name() }));
		}

		// dispatch to the correct handler method
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
	 * Limit the number of times `run()` executes this handler's context methods, with the same limit for each trigger operation.
	 * <br>Each trigger operation has its own count for the whole transaction, and it starts when a limit is first set for that operation. Every 200-record chunk counts as 1 run of its operation. A bypassed run is not counted, and a run that the limit stops is counted.
	 * <br>When the limit of an operation is exceeded, `run()` logs a warning and returns without calling the context method or `andFinally()`.
	 * <br>Returning `TriggerHandler` enables method chaining when used in a trigger.
	 * @author {@link [David Schach](https://github.com/dschach)}
	 * @param  max Maximum number of runs of each operation. 0 or a negative value removes the limit.
	 * @exception TriggerHandlerException when the value is null.
	 * @throws TriggerHandlerException when the value is null.
	 * @return      `TriggerHandler` This instance, which enables method chaining.
	 * @see TriggerHandler.setMaxLoopCount[1]
	 * @example
	 * this.setMaxLoopCount(5); // in the handler constructor
	 * // or, in the trigger
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
	 * Limit the number of times `run()` executes this handler's context method for 1 trigger operation. The other operations keep their limits.
	 * <br>The count of the operation is kept for the whole transaction, and it starts when a limit is first set for it. Every 200-record chunk counts as 1 run. A bypassed run is not counted, and a run that the limit stops is counted.
	 * @param  operation The trigger operation to limit.
	 * @param  max Maximum number of runs of the operation. 0 or a negative value removes the limit.
	 * @exception TriggerHandlerException when the operation or the value is null.
	 * @throws TriggerHandlerException when the operation or the value is null.
	 * @return      `TriggerHandler` This instance, which enables method chaining.
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
	 * Remove the limit of every trigger operation of this handler. The handler keeps its counters, so its runs are still counted.
	 * @example
	 * clearMaxLoopCount(); // in the handler
	 */
	public void clearMaxLoopCount() {
		TriggerHandler.loopCounters.clearMax(getHandlerName());
	}

	/**
	 * Bypass a handler by name. The name matches regardless of case.
	 *
	 * @param handlerName Name of the handler to be bypassed.
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
	 * Bypass a handler by type, which avoids typos in the name.
	 *
	 * @param handlerType The class to be bypassed, written as `ClassName.class`.
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
	 * Bypass a list of handlers by name. Every name is checked before any is bypassed.
	 *
	 * @param handlerNames List of handler names.
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
	 * Bypass all handlers. The named bypasses stay, so `clearGlobalBypass()` brings them back.
	 * @example
	 * TriggerHandler.bypassAll();
	 */
	public static void bypassAll() {
		TriggerHandler.bypasses.setAllBypassed(true);
	}

	/**
	 * Clear the bypass of a handler by name. The name matches regardless of case.
	 *
	 * @param handlerName The class name whose bypass is cleared.
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
	 * Clear the bypass of a handler by type.
	 *
	 * @param handlerType The class whose bypass is cleared, written as `ClassName.class`.
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
	 * Clear the bypass of a list of handlers by name. Every name is checked before any is cleared.
	 *
	 * @param handlerNames List of handler names whose bypass is cleared.
	 * @exception TriggerHandlerException when the list is null, or a name in it is null or blank.
	 * @throws TriggerHandlerException when the list is null, or a name in it is null or blank.
	 * @example
	 * List<String> classList = new List<String>{ 'AccountSampleTriggerHandler', 'ContactTriggerHandler' };
	 * TriggerHandler.clearBypass(classList);
	 */
	public static void clearBypass(List<String> handlerNames) {
		requireHandlerNames(handlerNames);
		for (String handlerName : handlerNames) {
			TriggerHandler.clearBypass(handlerName);
		}
	}

	/**
	 * Whether a handler is bypassed by name or by type. The global bypass is not part of the answer: use `isGlobalBypassed()` for it, or `isSkipped()` for both.
	 *
	 * @param handlerName The class name of the handler to check. It matches regardless of case.
	 * @return            `Boolean` Is this handler bypassed by name or by type?
	 * @exception TriggerHandlerException when the name is null or blank.
	 * @throws TriggerHandlerException when the name is null or blank.
	 * @see TriggerHandler.isSkipped[0]
	 * @example
	 * if (TriggerHandler.isBypassed('AccountSampleTriggerHandler')) {
	 *   // the handler is bypassed by name
	 * }
	 */
	public static Boolean isBypassed(String handlerName) {
		requireHandlerName(handlerName);
		return TriggerHandler.bypasses.contains(handlerName);
	}

	/**
	 * Whether a handler is bypassed by name or by type. The global bypass is not part of the answer: use `isGlobalBypassed()` for it, or `isSkipped()` for both.
	 *
	 * @since 2021
	 * @param handlerType The handler class to check, written as `ClassName.class`.
	 * @return            `Boolean` Is this handler bypassed by name or by type?
	 * @exception TriggerHandlerException when the type is null.
	 * @throws TriggerHandlerException when the type is null.
	 * @see TriggerHandler.isSkipped[1]
	 * @example
	 * if (TriggerHandler.isBypassed(AccountSampleTriggerHandler.class)) {
	 *   // the handler is bypassed by name
	 * }
	 */
	public static Boolean isBypassed(Type handlerType) {
		requireHandlerType(handlerType);
		return TriggerHandler.isBypassed(handlerType.getName());
	}

	/**
	 * Whether all handlers are bypassed, after `bypassAll()`.
	 *
	 * @return `Boolean` Is the global bypass on?
	 * @example
	 * if (TriggerHandler.isGlobalBypassed()) {
	 *   // no handler will run
	 * }
	 */
	public static Boolean isGlobalBypassed() {
		return TriggerHandler.bypasses.isAllBypassed();
	}

	/**
	 * Whether a handler will not run, because it is bypassed by name or by type, or because all handlers are bypassed.
	 *
	 * @param handlerName The class name of the handler to check. It matches regardless of case.
	 * @return            `Boolean` Will this handler be skipped?
	 * @exception TriggerHandlerException when the name is null or blank.
	 * @throws TriggerHandlerException when the name is null or blank.
	 * @example
	 * if (TriggerHandler.isSkipped('AccountSampleTriggerHandler')) {
	 *   // the handler will not run
	 * }
	 */
	public static Boolean isSkipped(String handlerName) {
		return TriggerHandler.isBypassed(handlerName) || TriggerHandler.bypasses.isAllBypassed();
	}

	/**
	 * Whether a handler will not run, because it is bypassed by name or by type, or because all handlers are bypassed.
	 *
	 * @param handlerType The handler class to check, written as `ClassName.class`.
	 * @return            `Boolean` Will this handler be skipped?
	 * @exception TriggerHandlerException when the type is null.
	 * @throws TriggerHandlerException when the type is null.
	 * @example
	 * if (TriggerHandler.isSkipped(AccountSampleTriggerHandler.class)) {
	 *   // the handler will not run
	 * }
	 */
	public static Boolean isSkipped(Type handlerType) {
		return TriggerHandler.isBypassed(handlerType) || TriggerHandler.bypasses.isAllBypassed();
	}

	/**
	 * Return a sorted list of the handlers that are bypassed by name or by type, as the caller spelled them.
	 * <br>The global bypass is not in the list. Use `isGlobalBypassed()` for it.
	 * <br>It replaces `bypassSet()`, which is deprecated. A `List` supports `contains(value)` too.
	 *
	 * @return      `List<String>` List of bypassed handlers.
	 * @example
	 * List<String> bypassed = TriggerHandler.bypassList();
	 */
	public static List<String> bypassList() {
		return TriggerHandler.bypasses.sortedNames();
	}

	/**
	 * Return a set of the handlers that are bypassed by name or by type, as the caller spelled them.
	 * <br>The global bypass is not in the set. Use `isGlobalBypassed()` for it.
	 * <br>Both `Set` and `List` support `contains(value)`, so this method and `bypassList()` differ only in the return type.
	 *
	 * @deprecated Use `bypassList()`, which holds the same names in sorted order. A later major release removes this method.
	 * @author David Schach
	 * @since 2022
	 * @return      `Set<String>` Set of bypassed handlers.
	 * @example
	 * if (TriggerHandler.bypassSet().contains('AccountSampleTriggerHandler')) {
	 *   // do something
	 * }
	 */
	public static Set<String> bypassSet() {
		return TriggerHandler.bypasses.nameSet();
	}

	/**
	 * Clear all bypasses, the global bypass and the list of bypassed handlers.
	 * @example
	 * TriggerHandler.clearAllBypasses();
	 */
	public static void clearAllBypasses() {
		clearGlobalBypass();
		clearBypassList();
	}

	/**
	 * Clear only the global bypass, and keep the list of bypassed handlers.
	 * <br>Use it to keep a base set of bypassed handlers for a whole operation. After `bypassAll()`, the handlers that were bypassed by name before stay bypassed.
	 * @example
	 * TriggerHandler.clearGlobalBypass();
	 */
	public static void clearGlobalBypass() {
		TriggerHandler.bypasses.setAllBypassed(false);
	}

	/**
	 * Clear the list of bypassed handlers, and keep the global bypass.
	 * <br>Use it to reset the named bypasses while everything stays bypassed.
	 * @example
	 * TriggerHandler.clearBypassList();
	 */
	public static void clearBypassList() {
		TriggerHandler.bypasses.clearNames();
	}

	/**
	 * Set the named bypass of a handler to a specific value. Eliminates the need to know the current bypass status.
	 * <br>`false` clears only the named bypass. A global bypass stays, so the handler still does not run until `clearGlobalBypass()`.
	 * <br>`isBypassed()` answers only the named bypass, so the save-and-restore idiom below gives back exactly the state before it.
	 * @since 2021
	 * @author {@link [David Schach](https://github.com/dschach)}
	 * @param  handlerName  The name of the TriggerHandler class.
	 * @param  desiredValue `true` to bypass the handler, `false` to clear its named bypass.
	 * @exception TriggerHandlerException when the name is null or blank, or the value is null.
	 * @throws TriggerHandlerException when the name is null or blank, or the value is null.
	 * @example
	 * TriggerHandler.setBypass('AccountSampleTriggerHandler', false);
	 * // or, save the current state, bypass, and restore
	 * Boolean wasBypassed = TriggerHandler.isBypassed('AccountSampleTriggerHandler');
	 * TriggerHandler.bypass('AccountSampleTriggerHandler');
	 * // do something here
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
	 * Set the named bypass of a handler, given by type, to a specific value. It works as the String form does, with `Type.getName()` as the name.
	 * @param  handlerType  The handler class, written as `ClassName.class`.
	 * @param  desiredValue `true` to bypass the handler, `false` to clear its named bypass.
	 * @exception TriggerHandlerException when the type is null, or the value is null.
	 * @throws TriggerHandlerException when the type is null, or the value is null.
	 * @see TriggerHandler.setBypass[0]
	 * @example
	 * Boolean wasBypassed = TriggerHandler.isBypassed(AccountSampleTriggerHandler.class);
	 * TriggerHandler.bypass(AccountSampleTriggerHandler.class);
	 * // do something here
	 * TriggerHandler.setBypass(AccountSampleTriggerHandler.class, wasBypassed);
	 */
	public static void setBypass(Type handlerType, Boolean desiredValue) {
		requireHandlerType(handlerType);
		TriggerHandler.setBypass(handlerType.getName(), desiredValue);
	}

	// handle limits

	/**
	 * Instance method that turns on the limits debug output, allowing method chaining in the trigger.
	 * <br>The flag is static, so it applies to every handler that runs later in the same transaction.
	 * @since 2023
	 * @deprecated Use `showHandlerLimits()` for this handler only, or the static `showLimits()` for every handler. A later major release removes this method.
	 * @see TriggerHandler.showLimits[0]
	 * @example
	 * new AccountSampleTriggerHandler().limits().run();
	 *
	 * @return      `TriggerHandler` Returning this instance enables method chaining.
	 */
	public TriggerHandler limits() {
		showLimits();
		return this;
	}

	/**
	 * Instance method that turns the limits debug output on or off, allowing method chaining in the trigger.
	 * <br>The flag is static, so it applies to every handler that runs later in the same transaction.
	 * @since 2023
	 * @deprecated Use `showHandlerLimits(Boolean)` for this handler only, or the static `showLimits(Boolean)` for every handler. A later major release removes this method.
	 * @see TriggerHandler.showLimits[1]
	 * @example
	 * new AccountSampleTriggerHandler().limits(false).run();
	 *
	 * @param enabled `true` to enable, `false` or null to disable.
	 * @return        `TriggerHandler` Returning this instance enables method chaining.
	 */
	public TriggerHandler limits(Boolean enabled) {
		showLimits(enabled);
		return this;
	}

	/**
	 * Turn on the limits debug output for every handler that runs later in the transaction. A handler with its own setting from `showHandlerLimits()` keeps it.
	 * <br>Use this in the trigger or handler.
	 * @see TriggerHandler.showLimits[1]
	 * @example
	 * TriggerHandler.showLimits(); // in the trigger
	 * new AccountSampleTriggerHandler().run();
	 * // or, in the handler
	 * AccountSampleTriggerHandler.showLimits();
	 */
	public static void showLimits() {
		showLimits(true);
	}

	/**
	 * Turn the limits debug output on or off for every handler that runs later in the transaction. A handler with its own setting from `showHandlerLimits()` keeps it.
	 * <br>Use this in the trigger or handler.
	 *
	 * @param enabled `true` to enable, `false` or null to disable.
	 * @see TriggerHandler.showLimits[0]
	 */
	public static void showLimits(Boolean enabled) {
		doShowLimits = enabled ?? false;
	}

	// handle debugs

	/**
	 * Instance method that turns on the entry and exit debug output, allowing method chaining in the trigger.
	 * <br>The flag is static, so it applies to every handler that runs later in the same transaction.
	 * @since 2023
	 * @deprecated Use `showHandlerDebug()` for this handler only, or the static `showDebug()` for every handler. A later major release removes this method.
	 * @see TriggerHandler.showDebug[0]
	 * @example
	 * new AccountSampleTriggerHandler().debug().run();
	 *
	 * @return      `TriggerHandler` Returning this instance enables method chaining.
	 */
	public TriggerHandler debug() {
		showDebug();
		return this;
	}

	/**
	 * Instance method that turns the entry and exit debug output on or off, allowing method chaining in the trigger.
	 * <br>The flag is static, so it applies to every handler that runs later in the same transaction.
	 * @since 2023
	 * @deprecated Use `showHandlerDebug(Boolean)` for this handler only, or the static `showDebug(Boolean)` for every handler. A later major release removes this method.
	 * @param enabled `true` to enable, `false` or null to disable.
	 * @return      `TriggerHandler` Returning this instance enables method chaining.
	 * @see TriggerHandler.showDebug[0]
	 * @example
	 * new AccountSampleTriggerHandler().debug(false).run();
	 */
	public TriggerHandler debug(Boolean enabled) {
		showDebug(enabled);
		return this;
	}

	/**
	 * Turn on the entry and exit debug output for every handler that runs later in the transaction. A handler with its own setting from `showHandlerDebug()` keeps it.
	 * <br>Use this in the trigger or handler.
	 * @author {@link [David Schach](https://github.com/dschach)}
	 * @since 2021
	 * @see TriggerHandler.showDebug[1]
	 * @example
	 * TriggerHandler.showDebug(); // in the trigger
	 * new AccountSampleTriggerHandler().run();
	 * // or, in the handler
	 * AccountSampleTriggerHandler.showDebug();
	 */
	public static void showDebug() {
		showDebug(true);
	}

	/**
	 * Turn the entry and exit debug output on or off for every handler that runs later in the transaction. A handler with its own setting from `showHandlerDebug()` keeps it.
	 *
	 * @author {@link [David Schach](https://github.com/dschach)}
	 * @since 2021
	 * @param enabled `true` to enable, `false` or null to disable.
	 * @see TriggerHandler.showDebug[0]
	 */
	public static void showDebug(Boolean enabled) {
		doShowDebug = enabled ?? false;
	}

	/**
	 * Turn on the limits line for this handler only. Other handlers keep their own setting or the static one.
	 * @see TriggerHandler.showHandlerLimits[1]
	 * @example
	 * new AccountSampleTriggerHandler().showHandlerLimits().run();
	 *
	 * @return `TriggerHandler` This instance, which enables method chaining.
	 */
	public TriggerHandler showHandlerLimits() {
		return showHandlerLimits(true);
	}

	/**
	 * Turn the limits line on or off for this handler only. This handler's setting wins over the static `showLimits()`.
	 * @param enabled `true` to turn it on, `false` to turn it off for this handler, or null to use the static setting again.
	 * @return `TriggerHandler` This instance, which enables method chaining.
	 * @see TriggerHandler.showHandlerLimits[0]
	 * @example
	 * new AccountSampleTriggerHandler().showHandlerLimits(false).run();
	 */
	public TriggerHandler showHandlerLimits(Boolean enabled) {
		handlerShowLimits = enabled;
		return this;
	}

	/**
	 * Turn on the entry and exit lines for this handler only. Other handlers keep their own setting or the static one.
	 * @see TriggerHandler.showHandlerDebug[1]
	 * @example
	 * new AccountSampleTriggerHandler().showHandlerDebug().run();
	 *
	 * @return `TriggerHandler` This instance, which enables method chaining.
	 */
	public TriggerHandler showHandlerDebug() {
		return showHandlerDebug(true);
	}

	/**
	 * Turn the entry and exit lines on or off for this handler only. This handler's setting wins over the static `showDebug()`.
	 * @param enabled `true` to turn them on, `false` to turn them off for this handler, or null to use the static setting again.
	 * @return `TriggerHandler` This instance, which enables method chaining.
	 * @see TriggerHandler.showHandlerDebug[0]
	 * @example
	 * new AccountSampleTriggerHandler().showHandlerDebug(false).run();
	 */
	public TriggerHandler showHandlerDebug(Boolean enabled) {
		handlerShowDebug = enabled;
		return this;
	}

	/**
	 * Whether this handler writes the limits line: its own setting when it has one, or else the static setting.
	 * @return `Boolean` `true` when the limits line is on for this handler.
	 */
	private Boolean isLimitsOn() {
		return handlerShowLimits ?? doShowLimits;
	}

	/**
	 * Whether this handler writes the entry and exit lines: its own setting when it has one, or else the static setting.
	 * @return `Boolean` `true` when the entry and exit lines are on for this handler.
	 */
	private Boolean isDebugOn() {
		return handlerShowDebug ?? doShowDebug;
	}

	/**
	 * Return the number of runs counted for a handler in this transaction, for all trigger operations together, including runs that the loop limit stopped.
	 * @param handlerName The handler name to check.
	 * @return            `Integer` The total count, or -1 when no limit was ever set for the handler.
	 * @exception TriggerHandlerException when the name is null or blank.
	 * @throws TriggerHandlerException when the name is null or blank.
	 * @deprecated Use `getLoopCount(String, System.TriggerOperation)`, which returns the count of 1 trigger operation. A later major release removes this method.
	 * @example
	 * Integer runs = TriggerHandler.getLoopCount('AccountSampleTriggerHandler');
	 */
	public static Integer getLoopCount(String handlerName) {
		requireHandlerName(handlerName);
		return TriggerHandler.loopCounters.total(handlerName);
	}

	/**
	 * Return the number of runs counted for 1 trigger operation of a handler in this transaction, including runs that the loop limit stopped.
	 * @param handlerName The handler name to check.
	 * @param operation The trigger operation to check.
	 * @return            `Integer` The count, or -1 when no limit was ever set for the operation, because its runs are not counted.
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
	 * Set the current context from `Trigger.operationType`. Called by both constructors.
	 * <br>Outside a trigger, `isTriggerExecuting` is false. A test sets its own context with `setTestContext()`.
	 * @see TriggerHandler.isTriggerExecuting
	 */
	private void setTriggerContext() {
		triggerEvent = Trigger.operationType;
		isTriggerExecuting = Trigger.isExecuting && triggerEvent != null;
	}

	/**
	 * Count this run on the loop counter of the handler's current trigger operation, when it has one, and check the limit.
	 * <br>When the limit is exceeded, log a warning and tell `run()` to return without calling the context method or `andFinally()`.
	 *
	 * @author {@link [David Schach](https://github.com/dschach)}
	 * @author {@link [fbouzeraa](https://github.com/fbouzeraa)}
	 * @return   `Boolean` `true` when `run()` should continue: the operation has no counter, or it is within its limit. `false` when the limit is exceeded.
	 */
	private Boolean incrementCheckLoopCount() {
		if (TriggerHandler.loopCounters.isEmpty()) {
			return true;
		}
		LoopCounter counter = TriggerHandler.loopCounters.get(getHandlerName(), triggerEvent);
		if (counter == null || !counter.increment()) {
			return true;
		}
		log(LoggingLevel.WARN, 'Maximum loop count of ' + counter.getMax() + ' exceeded in ' + getHandlerName() + ', so run() skipped ' + triggerEvent.name());
		return false;
	}

	/**
	 * Decide whether this run continues.
	 * <br>`false` makes `run()` return before the context method.
	 *
	 * @return      `Boolean` `true` when the handler runs, `false` when it is bypassed.
	 * @exception TriggerHandlerException when `run()` is called outside a trigger context.
	 * @throws TriggerHandlerException when `run()` is called outside a trigger context.
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
	 * The trigger operation this handler is running for. Also set under the test seam, where `Trigger.operationType` is null.
	 * @return `System.TriggerOperation` The current operation, or null outside a trigger.
	 */
	protected System.TriggerOperation getTriggerEvent() {
		return triggerEvent;
	}

	/**
	 * The name of this handler: `Type.getName()` from the Type constructor, or the name resolved from the runtime class name.
	 * <br>Available to subclasses, for example for a log line or a `bypass()` call.
	 * <br>The runtime lookup reads the start of `toString()`, which gives only the short name of an inner class. A handler that is an inner class, or that overrides `toString()`, must pass its type to the Type constructor.
	 *
	 * @return      `String` Name of the current handler.
	 * @see         TriggerHandler.handlerName
	 */
	@TestVisible
	protected String getHandlerName() {
		if (String.isBlank(handlerName)) {
			handlerName = toString().substringBefore(CLASS_NAME_END);
		}
		return handlerName;
	}

	/**
	 * Make this handler run as if a trigger fired the given operation, so that a test can call `run()` without DML.
	 * <br>Set the records that the handler reads before you call `run()`, for example through `@TestVisible` fields of the handler.
	 * <br>Outside a test it changes nothing: the handler keeps the context of the real trigger.
	 * <br>A null operation clears the context, so that `run()` throws as it does outside a trigger.
	 * @param operation The trigger operation to simulate.
	 * @return `TriggerHandler` This instance, which enables method chaining.
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
	 * Write a message from the framework: the entry, exit, and limits lines when they are turned on, and the warning when the loop limit is exceeded.
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

	//triggerEvent methods

	/**
	 * Virtual method for the implementing class to override.
	 */
	protected virtual void beforeInsert() {
	}

	/**
	 * Virtual method for the implementing class to override.
	 */
	protected virtual void beforeUpdate() {
	}

	/**
	 * Virtual method for the implementing class to override.
	 */
	protected virtual void beforeDelete() {
	}

	/**
	 * Virtual method for the implementing class to override.
	 */
	protected virtual void afterInsert() {
	}

	/**
	 * Virtual method for the implementing class to override.
	 */
	protected virtual void afterUpdate() {
	}

	/**
	 * Virtual method for the implementing class to override.
	 */
	protected virtual void afterDelete() {
	}

	/**
	 * Virtual method for the implementing class to override.
	 */
	protected virtual void afterUndelete() {
	}

	/**
	 * `andFinally()` runs after the context method returns, in every trigger context, also a context that the handler does not override.
	 * <br>It does not run when the handler is bypassed or the loop limit stops the run, because then nothing in the handler runs. It also does not run when the context method throws an exception that it does not catch.
	 * <br>Once a run has started its context method, a bypass cannot stop its `andFinally()`. If the context method bypasses this handler and then updates records of the same object, the run of the handler for that update is skipped completely, and the `andFinally()` of the first run still comes last.
	 * <br>It also runs when the context method catches its own exception or calls `addError()`.
	 * <br>If `andFinally()` throws, the exception reaches the caller, and the exit and limits debug lines are not written.
	 * <br>Credit to James Simone for this idea.
	 * @see [The Joys of Apex](https://www.jamessimone.net/blog/joys-of-apex/lightweight-trigger-handler/)
	 * @author James Simone
	 * @since 2022
	 */
	protected virtual void andFinally() {
	}

	// inner classes

	/**
	 * Inner class that holds the bypasses of the transaction: the named bypasses and the global bypass, which are independent.
	 * <br>`TriggerHandler` keeps 1 instance in `bypasses`, because an inner class cannot have static members. The public static methods check their arguments and then call it.
	 */
	@TestVisible
	private inherited sharing class BypassRegistry {
		/**
		 * All handlers bypassed by name or by type, as the caller spelled them.
		 */
		private Set<String> names = new Set<String>();
		/**
		 * Lower-case copy of `names`, used for every membership check so that a name matches regardless of case.
		 */
		private Set<String> namesLower = new Set<String>();
		/**
		 * `true` when all handlers are bypassed.
		 */
		private Boolean allBypassed = false;

		/**
		 * Bypass a handler by name.
		 * @param handlerName The name, which is not null or blank.
		 */
		public void add(String handlerName) {
			names.add(handlerName);
			namesLower.add(handlerName.toLowerCase());
		}

		/**
		 * Clear the bypass of a handler by name, whatever its case. A name that is not bypassed changes nothing.
		 * @param handlerName The name, which is not null or blank.
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
		 * Whether a handler is bypassed by name, whatever its case.
		 * @param handlerName The name, which is not null or blank.
		 * @return `Boolean` `true` when the name is bypassed.
		 */
		public Boolean contains(String handlerName) {
			return namesLower.contains(handlerName.toLowerCase());
		}

		/**
		 * Whether any handler is bypassed by name.
		 * @return `Boolean` `true` when at least 1 name is bypassed.
		 */
		public Boolean hasNames() {
			return !namesLower.isEmpty();
		}

		/**
		 * The bypassed names, as the caller spelled them, in sorted order.
		 * @return `List<String>` A new sorted list.
		 */
		public List<String> sortedNames() {
			List<String> sorted = new List<String>(names);
			sorted.sort();
			return sorted;
		}

		/**
		 * The bypassed names, as the caller spelled them.
		 * @return `Set<String>` A new set.
		 */
		public Set<String> nameSet() {
			return new Set<String>(names);
		}

		/**
		 * Clear every named bypass, and keep the global bypass.
		 */
		public void clearNames() {
			names.clear();
			namesLower.clear();
		}

		/**
		 * Whether all handlers are bypassed.
		 * @return `Boolean` `true` when the global bypass is on.
		 */
		public Boolean isAllBypassed() {
			return allBypassed;
		}

		/**
		 * Turn the global bypass on or off, and keep the named bypasses.
		 * @param value `true` to bypass all handlers, `false` to clear the global bypass.
		 */
		public void setAllBypassed(Boolean value) {
			allBypassed = value;
		}
	}

	/**
	 * Inner class that holds the loop counters of the transaction, by handler name and then by trigger operation.
	 * <br>`TriggerHandler` keeps 1 instance in `loopCounters`, because an inner class cannot have static members. The public methods check their arguments and then call it.
	 */
	@TestVisible
	private inherited sharing class LoopCounterRegistry {
		/**
		 * The loop counters of each handler, by handler name and then by trigger operation.
		 */
		private Map<String, Map<System.TriggerOperation, LoopCounter>> counters = new Map<String, Map<System.TriggerOperation, LoopCounter>>();

		/**
		 * Whether no handler has a counter, so that `run()` can skip the handler name lookup.
		 * @return `Boolean` `true` when no limit was set in the transaction.
		 */
		public Boolean isEmpty() {
			return counters.isEmpty();
		}

		/**
		 * The counter of 1 trigger operation of a handler.
		 * @param handlerName The handler name.
		 * @param operation The trigger operation.
		 * @return `LoopCounter` The counter, or null when no limit was set for the operation.
		 */
		public LoopCounter get(String handlerName, System.TriggerOperation operation) {
			return counters.get(handlerName)?.get(operation);
		}

		/**
		 * Set the limit of 1 trigger operation of a handler, and create its counter when it has none.
		 * @param handlerName The handler name.
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
		 * Remove the limit of every counter that a handler has. The counters keep counting, and no counter is created.
		 * @param handlerName The handler name.
		 */
		public void clearMax(String handlerName) {
			for (LoopCounter counter : counters.get(handlerName)?.values() ?? new List<LoopCounter>()) {
				counter.setMax(NO_LOOP_LIMIT);
			}
		}

		/**
		 * The count of 1 trigger operation of a handler.
		 * @param handlerName The handler name.
		 * @param operation The trigger operation.
		 * @return `Integer` The count, or `NOT_COUNTED` when no limit was set for the operation.
		 */
		public Integer count(String handlerName, System.TriggerOperation operation) {
			return get(handlerName, operation)?.getCount() ?? NOT_COUNTED;
		}

		/**
		 * The total count of all trigger operations of a handler.
		 * @param handlerName The handler name.
		 * @return `Integer` The total, or `NOT_COUNTED` when no limit was set for the handler.
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
	 * Inner class that counts the runs of 1 trigger operation of 1 handler against its maximum.
	 */
	@TestVisible
	private inherited sharing class LoopCounter {
		/**
		 * The maximum number of runs, or `NO_LOOP_LIMIT` for no limit.
		 */
		private Integer max;
		/**
		 * The number of runs counted so far, including runs that the limit stopped.
		 */
		private Integer loopCount;

		/**
		 * Constructor with a maximum. The count starts at 0.
		 *
		 * @param maxCount The maximum number of runs. 0 or a negative value means no limit.
		 */
		public LoopCounter(Integer maxCount) {
			setMax(maxCount);
			this.loopCount = 0;
		}

		/**
		 * Add 1 to the count and return `exceeded()`.
		 * @return     `Boolean` true when the new count is greater than the maximum. A counter with no limit never exceeds.
		 */
		public Boolean increment() {
			loopCount++;
			return exceeded();
		}

		/**
		 * Whether the count has passed the limit.
		 * @return     `Boolean` true when the counter has a limit and the count is greater than it.
		 */
		public Boolean exceeded() {
			return max != NO_LOOP_LIMIT && loopCount > max;
		}

		/**
		 * Returns the maximum number of runs.
		 * @return     `Integer` The maximum, or -1 when there is no limit.
		 */
		public Integer getMax() {
			return max;
		}

		/**
		 * Returns the number of runs counted so far, including runs that the limit stopped.
		 * @return     `Integer` The count.
		 */
		public Integer getCount() {
			return loopCount;
		}

		/**
		 * Sets the maximum number of runs. The count does not change. A maximum of 0 or less is stored as `NO_LOOP_LIMIT`.
		 * @param maxCount The new maximum. 0 or a negative value means no limit.
		 */
		public void setMax(Integer maxCount) {
			max = maxCount > 0 ? maxCount : NO_LOOP_LIMIT;
		}
	}

	/**
	 * Reject a null or blank handler name.
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
	 * Reject a null handler type.
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
	 * Reject a null list, or a list with a null or blank name, before any name is used.
	 * @param handlerNames The names to check.
	 * @exception TriggerHandlerException when the list is null or holds a null or blank name.
	 * @throws TriggerHandlerException when the list is null or holds a null or blank name.
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
	 * Exception thrown by the framework for a wrong call.
	 */
	public class TriggerHandlerException extends Exception {
	}
}