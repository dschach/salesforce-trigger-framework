/**
 * Trigger handler virtual class, the base for every trigger handler.
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
public inherited sharing virtual class TriggerHandler {
	/**
	 * The loop counter of each handler, by handler name. A handler has a counter only after `setMaxLoopCount()` is called for it, so `getLoopCount()` is 0 for a handler with no limit.
	 */
	@TestVisible
	private static Map<String, LoopCounter> loopCountMap = new Map<String, LoopCounter>();

	/**
	 * All bypassed handlers, as the caller spelled them.
	 */
	@TestVisible
	private static Set<String> bypassedHandlers = new Set<String>();

	/**
	 * Lower-case copy of `bypassedHandlers`, used for every membership check so that a bypass name matches regardless of case.
	 */
	private static Set<String> bypassedHandlersLower = new Set<String>();

	/**
	 * `true` when all handlers are bypassed. The named bypasses are not checked then.
	 */
	@TestVisible
	private static Boolean globalBypass = false;

	/**
	 * `true` if we include a debug statement for limits.
	 */
	@TestVisible
	private static Boolean showLimits = false;

	/**
	 * `true` if we include a debug statement for trigger entry and exit.
	 */
	@TestVisible
	private static Boolean showDebug = false;

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
	 * The maximum loop count of a `LoopCounter` created with no maximum. `setMaxLoopCount()` always gives its own maximum.
	 */
	private static final Integer DEFAULT_MAX_LOOP_COUNT = 5;

	/**
	 * The maximum loop count that `clearMaxLoopCount()` sets. Any negative maximum means no limit.
	 */
	private static final Integer NO_LOOP_LIMIT = -1;

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

		if (showDebug) {
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

		if (showLimits) {
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
		if (showDebug) {
			log(LoggingLevel.DEBUG, String.format('Exiting {0}, fired {1}', new List<String>{ getHandlerName(), triggerEvent.name() }));
		}
	}

	/**
	 * Limit the number of times `run()` executes this handler's context methods.
	 * <br>The count is kept per handler name for the whole transaction, and it starts when this method is first called for the handler. Every trigger context and every 200-record chunk counts as 1 run. A bypassed run is not counted, and a run that the limit stops is counted.
	 * <br>When the limit is exceeded, `run()` logs a warning and returns without calling the context method or `andFinally()`.
	 * <br>Returning `TriggerHandler` enables method chaining when used in a trigger.
	 * @author {@link [David Schach](https://github.com/dschach)}
	 * @param  max Maximum number of times. 0 means the handler never runs, and a negative value removes the limit.
	 * @exception TriggerHandlerException when the value is null.
	 * @throws TriggerHandlerException when the value is null.
	 * @return      `TriggerHandler` This instance, which enables method chaining.
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
		LoopCounter counter = TriggerHandler.loopCountMap.get(handlerName);
		if (counter == null) {
			TriggerHandler.loopCountMap.put(handlerName, new LoopCounter(max));
		} else {
			counter.setMax(max);
		}
		return this;
	}

	/**
	 * Remove the limit on the number of times this handler can run. The handler keeps its counter, so its runs are still counted.
	 * @example
	 * clearMaxLoopCount(); // in the handler
	 */
	public void clearMaxLoopCount() {
		setMaxLoopCount(NO_LOOP_LIMIT);
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
		TriggerHandler.bypassedHandlers.add(handlerName);
		TriggerHandler.bypassedHandlersLower.add(handlerName.toLowerCase());
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
		globalBypass = true;
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
		if (!TriggerHandler.bypassedHandlersLower.remove(handlerName.toLowerCase())) {
			return;
		}
		for (String bypassedName : new List<String>(TriggerHandler.bypassedHandlers)) {
			if (bypassedName.equalsIgnoreCase(handlerName)) {
				TriggerHandler.bypassedHandlers.remove(bypassedName);
			}
		}
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
		return TriggerHandler.bypassedHandlersLower.contains(handlerName.toLowerCase());
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
		return globalBypass;
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
		return TriggerHandler.isBypassed(handlerName) || globalBypass;
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
		return TriggerHandler.isBypassed(handlerType) || globalBypass;
	}

	/**
	 * Return a sorted list of the handlers that are bypassed by name or by type, as the caller spelled them.
	 * <br>The global bypass is not in the list. Use `isGlobalBypassed()` for it.
	 * <br>Both `Set` and `List` support `contains(value)`, so this method and `bypassSet()` differ only in the return type.
	 *
	 * @return      `List<String>` List of bypassed handlers.
	 * @example
	 * List<String> bypassed = TriggerHandler.bypassList();
	 */
	public static List<String> bypassList() {
		List<String> bypasses = new List<String>(TriggerHandler.bypassedHandlers);
		bypasses.sort();
		return bypasses;
	}

	/**
	 * Return a set of the handlers that are bypassed by name or by type, as the caller spelled them.
	 * <br>The global bypass is not in the set. Use `isGlobalBypassed()` for it.
	 * <br>Both `Set` and `List` support `contains(value)`, so this method and `bypassList()` differ only in the return type.
	 *
	 * @author David Schach
	 * @since 2022
	 * @return      `Set<String>` Set of bypassed handlers.
	 * @example
	 * if (TriggerHandler.bypassSet().contains('AccountSampleTriggerHandler')) {
	 *   // do something
	 * }
	 */
	public static Set<String> bypassSet() {
		return new Set<String>(TriggerHandler.bypassedHandlers);
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
		globalBypass = false;
	}

	/**
	 * Clear the list of bypassed handlers, and keep the global bypass.
	 * <br>Use it to reset the named bypasses while everything stays bypassed.
	 * @example
	 * TriggerHandler.clearBypassList();
	 */
	public static void clearBypassList() {
		TriggerHandler.bypassedHandlers.clear();
		TriggerHandler.bypassedHandlersLower.clear();
	}

	/**
	 * Set the named bypass of a handler to a specific value. Eliminates the need to know the current bypass status.
	 * <br>`false` clears only the named bypass. A global bypass stays, so the handler still does not run until `clearGlobalBypass()`.
	 * <br>`isBypassed()` answers only the named bypass, so the save-and-restore idiom below gives back exactly the state before it.
	 * @since 2021
	 * @author {@link [David Schach](https://github.com/dschach)}
	 * @param  handlerName  The name of the TriggerHandler class.
	 * @param  desiredValue `true` to bypass the handler, `false` to clear its bypass so that it runs.
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

	// handle limits

	/**
	 * Instance method that turns on the limits debug output, allowing method chaining in the trigger.
	 * <br>The flag is static, so it applies to every handler that runs later in the same transaction.
	 * @since 2023
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
	 * Turn on the limits debug output for every handler that runs later in the transaction.
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
	 * Turn the limits debug output on or off for every handler that runs later in the transaction.
	 * <br>Use this in the trigger or handler.
	 *
	 * @param enabled `true` to enable, `false` or null to disable.
	 * @see TriggerHandler.showLimits[0]
	 */
	public static void showLimits(Boolean enabled) {
		showLimits = enabled ?? false;
	}

	// handle debugs

	/**
	 * Instance method that turns on the entry and exit debug output, allowing method chaining in the trigger.
	 * <br>The flag is static, so it applies to every handler that runs later in the same transaction.
	 * @since 2023
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
	 * Turn on the entry and exit debug output for every handler that runs later in the transaction.
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
	 * Turn the entry and exit debug output on or off for every handler that runs later in the transaction.
	 *
	 * @author {@link [David Schach](https://github.com/dschach)}
	 * @since 2021
	 * @param enabled `true` to enable, `false` or null to disable.
	 * @see TriggerHandler.showDebug[0]
	 */
	public static void showDebug(Boolean enabled) {
		showDebug = enabled ?? false;
	}

	/**
	 * Return the number of runs counted for a handler in this transaction, including runs that the loop limit stopped.
	 * @param handlerName The handler name to check.
	 * @return            `Integer` The count, or 0 when `setMaxLoopCount()` was never called for the handler.
	 * @exception TriggerHandlerException when the name is null or blank.
	 * @throws TriggerHandlerException when the name is null or blank.
	 * @example
	 * Integer runs = TriggerHandler.getLoopCount('AccountSampleTriggerHandler');
	 */
	public static Integer getLoopCount(String handlerName) {
		requireHandlerName(handlerName);
		return TriggerHandler.loopCountMap.get(handlerName)?.getCount() ?? 0;
	}

	/**
	 * Set the current context from `Trigger.operationType`. Called by both constructors.
	 */
	@TestVisible
	private void setTriggerContext() {
		setTriggerContext(Trigger.operationType, false);
	}

	/**
	 * Set the current trigger context from a `System.TriggerOperation`.
	 * <br>Outside a trigger, and in a test that does not force a context, `isTriggerExecuting` is false.
	 *
	 * @param opType   The operation type, which the platform sets.
	 * @param testMode Only used in test methods to force a context.
	 * @see TriggerHandler.isTriggerExecuting
	 */
	@TestVisible
	private void setTriggerContext(System.TriggerOperation opType, Boolean testMode) {
		isTriggerExecuting = (Trigger.isExecuting || testMode == true) && opType != null;
		triggerEvent = opType;
	}

	/**
	 * Count this run on the handler's loop counter, when the handler has one, and check the limit.
	 * <br>When the limit is exceeded, log a warning and tell `run()` to return without calling the context method or `andFinally()`.
	 *
	 * @author {@link [David Schach](https://github.com/dschach)}
	 * @author {@link [fbouzeraa](https://github.com/fbouzeraa)}
	 * @return   `Boolean` `true` when `run()` should continue: the handler has no counter, or it is within its limit. `false` when the limit is exceeded.
	 */
	private Boolean incrementCheckLoopCount() {
		if (TriggerHandler.loopCountMap.isEmpty()) {
			return true;
		}
		LoopCounter counter = TriggerHandler.loopCountMap.get(getHandlerName());
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
	@TestVisible
	private Boolean validateRun() {
		if (!isTriggerExecuting || triggerEvent == null) {
			throw new TriggerHandlerException(ERROR_TRIGGERCONTEXT);
		}
		if (globalBypass) {
			return false;
		}
		// the same rule as isSkipped(); with no named bypass, the handler name is not needed
		return TriggerHandler.bypassedHandlersLower.isEmpty() || !TriggerHandler.isBypassed(getHandlerName());
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
	 * @param operation The trigger operation to simulate.
	 * @return `TriggerHandler` This instance, which enables method chaining.
	 * @example
	 * AccountSampleTriggerHandler handler = new AccountSampleTriggerHandler();
	 * // set the records that the handler reads, and then:
	 * handler.setTestContext(System.TriggerOperation.BEFORE_INSERT).run();
	 */
	@TestVisible
	protected TriggerHandler setTestContext(System.TriggerOperation operation) {
		Boolean inTest = Test.isRunningTest();
		setTriggerContext(inTest ? operation : Trigger.operationType, inTest);
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
	@TestVisible
	protected virtual void beforeInsert() {
	}

	/**
	 * Virtual method for the implementing class to override.
	 */
	@TestVisible
	protected virtual void beforeUpdate() {
	}

	/**
	 * Virtual method for the implementing class to override.
	 */
	@TestVisible
	protected virtual void beforeDelete() {
	}

	/**
	 * Virtual method for the implementing class to override.
	 */
	@TestVisible
	protected virtual void afterInsert() {
	}

	/**
	 * Virtual method for the implementing class to override.
	 */
	@TestVisible
	protected virtual void afterUpdate() {
	}

	/**
	 * Virtual method for the implementing class to override.
	 */
	@TestVisible
	protected virtual void afterDelete() {
	}

	/**
	 * Virtual method for the implementing class to override.
	 */
	@TestVisible
	protected virtual void afterUndelete() {
	}

	/**
	 * `andFinally()` runs after the context method, in every trigger context.
	 * <br>It does not run when the handler is bypassed, when the loop limit is exceeded, or when the context method throws an exception.
	 * <br>Credit to James Simone for this idea.
	 * @see [The Joys of Apex](https://www.jamessimone.net/blog/joys-of-apex/lightweight-trigger-handler/)
	 * @author James Simone
	 * @since 2022
	 */
	@TestVisible
	protected virtual void andFinally() {
	}

	// inner classes

	/**
	 * Inner class that counts the runs of 1 handler against its maximum.
	 */
	@TestVisible
	private inherited sharing class LoopCounter {
		/**
		 * The maximum number of runs. A negative value means no limit.
		 */
		private Integer max;
		/**
		 * The number of runs counted so far, including runs that the limit stopped.
		 */
		private Integer loopCount;

		/**
		 * Constructor with the default maximum, `DEFAULT_MAX_LOOP_COUNT`, which is 5. The count starts at 0.
		 */
		public LoopCounter() {
			this(DEFAULT_MAX_LOOP_COUNT);
		}

		/**
		 * Constructor with a maximum. The count starts at 0.
		 *
		 * @param maxCount The maximum number of runs. A negative value means no limit.
		 */
		public LoopCounter(Integer maxCount) {
			this.max = maxCount;
			this.loopCount = 0;
		}

		/**
		 * Add 1 to the count and return `exceeded()`.
		 * @return     `Boolean` true when the new count is greater than a max of 0 or more. A negative max never exceeds.
		 */
		public Boolean increment() {
			loopCount++;
			return exceeded();
		}

		/**
		 * Whether the count has passed the limit.
		 * @return     `Boolean` true when max is 0 or more and count is greater than max. A negative max means no limit.
		 */
		public Boolean exceeded() {
			return max >= 0 && loopCount > max;
		}

		/**
		 * Returns the maximum number of runs.
		 * @return     `Integer` The maximum. A negative value means no limit.
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
		 * Sets the maximum number of runs. The count does not change.
		 * @param maxCount The new maximum. A negative value means no limit.
		 */
		public void setMax(Integer maxCount) {
			max = maxCount;
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