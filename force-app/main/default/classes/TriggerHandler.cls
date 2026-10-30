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
	 * Loop counter per handler name. A handler has an entry only after `setMaxLoopCount()` was called for it, so `getLoopCount()` is 0 for a handler with no limit.
	 */
	@TestVisible
	private static Map<String, LoopCount> loopCountMap = new Map<String, LoopCount>();

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
	 * The name of this handler. Set by the String constructor, or resolved by `getHandlerName()` the first time it is needed.
	 */
	private String handlerName;

	/**
	 * The value that `bypassList()` and `bypassSet()` hold when all handlers are bypassed.
	 */
	@TestVisible
	private static final String BYPASS_ALL_ALIAS = 'BypassAll';

	/**
	 * The maximum loop count of a `LoopCount` created with no maximum. `setMaxLoopCount()` always gives its own maximum.
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
	 * Basic constructor. The handler name is resolved from the runtime class name the first time a bypass or a loop count needs it.
	 * <br>That lookup serializes every field of the handler, so pass the name to the other constructor to avoid it.
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
	 * Constructor with handler name. Skips the runtime class name lookup.
	 * @author {@link [David Schach](https://github.com/dschach)}
	 * @since 2021
	 * @param  handlerName The name of the handler. Pass the class name exactly as `Type.getName()` returns it, so that `bypass(Type)` matches. Spaces at the start and the end are removed.
	 * @example
	 * new AccountSampleTriggerHandler('AccountSampleTriggerHandler').run();
	 * // in the trigger handler class
	 * public AccountSampleTriggerHandler(String className) {
	 *   super(className);
	 *   this.newRecords = (List<Account>) Trigger.new;
	 *   this.oldRecords = (List<Account>) Trigger.old;
	 *   this.newRecordsMap = (Map<Id, Account>) Trigger.newMap;
	 *   this.oldRecordsMap = (Map<Id, Account>) Trigger.oldMap;
	 * }
	 */
	public TriggerHandler(String handlerName) {
		this.handlerName = handlerName?.trim();
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
			this.log(LoggingLevel.DEBUG, String.format('Entering {0}, fired {1}', new List<String>{ getHandlerName(), this.triggerEvent.name() }));
		}

		// dispatch to the correct handler method
		switch on this.triggerEvent {
			when BEFORE_INSERT {
				this.beforeInsert();
			}
			when BEFORE_UPDATE {
				this.beforeUpdate();
			}
			when BEFORE_DELETE {
				this.beforeDelete();
			}
			when AFTER_INSERT {
				this.afterInsert();
			}
			when AFTER_UPDATE {
				this.afterUpdate();
			}
			when AFTER_DELETE {
				this.afterDelete();
			}
			when AFTER_UNDELETE {
				this.afterUndelete();
			}
		}
		this.andFinally();

		if (showLimits) {
			this.log(
				LoggingLevel.DEBUG,
				String.format(
					'{0} on {1} ({2}/{3} queries) and ({4}/{5} DML calls)',
					new List<String>{
						this.triggerEvent.name(),
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
			this.log(LoggingLevel.DEBUG, String.format('Exiting {0}, fired {1}', new List<String>{ getHandlerName(), this.triggerEvent.name() }));
		}
	}

	/**
	 * Limit the number of times `run()` executes this handler's context methods.
	 * <br>The count is kept per handler name. Every trigger context and every 200-record chunk consumes 1 count.
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
		LoopCount counter = TriggerHandler.loopCountMap.get(handlerName);
		if (counter == null) {
			TriggerHandler.loopCountMap.put(handlerName, new LoopCount(max));
		} else {
			counter.setMax(max);
		}
		return this;
	}

	/**
	 * Remove the limit on the number of times this handler can run.
	 * @example
	 * this.clearMaxLoopCount(); // in the handler
	 */
	public void clearMaxLoopCount() {
		this.setMaxLoopCount(NO_LOOP_LIMIT);
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
	 * Bypass all handlers. The list of named bypasses is cleared too.
	 * @example
	 * TriggerHandler.bypassAll();
	 */
	public static void bypassAll() {
		TriggerHandler.clearBypassList();
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
	 * A handler is bypassed when it was bypassed by name or type, or when all handlers are bypassed.
	 *
	 * @param handlerName The class name of the handler to check. It matches regardless of case.
	 * @return            `Boolean` Is this handler bypassed?
	 * @exception TriggerHandlerException when the name is null or blank.
	 * @throws TriggerHandlerException when the name is null or blank.
	 * @example
	 * if (TriggerHandler.isBypassed('AccountSampleTriggerHandler')) {
	 *   // the handler will not run
	 * }
	 */
	public static Boolean isBypassed(String handlerName) {
		requireHandlerName(handlerName);
		return globalBypass || TriggerHandler.bypassedHandlersLower.contains(handlerName.toLowerCase());
	}

	/**
	 * A handler is bypassed when it was bypassed by name or type, or when all handlers are bypassed.
	 *
	 * @since 2021
	 * @param handlerType The handler class to check, written as `ClassName.class`.
	 * @return            `Boolean` Is this handler bypassed?
	 * @exception TriggerHandlerException when the type is null.
	 * @throws TriggerHandlerException when the type is null.
	 * @example
	 * if (TriggerHandler.isBypassed(AccountSampleTriggerHandler.class)) {
	 *   // the handler will not run
	 * }
	 */
	public static Boolean isBypassed(Type handlerType) {
		requireHandlerType(handlerType);
		return TriggerHandler.isBypassed(handlerType.getName());
	}

	/**
	 * Return a sorted list of the bypassed handlers, as the caller spelled them.
	 * <br>When all handlers are bypassed, the list holds the alias `BypassAll`, after any named bypasses.
	 * <br>Both `Set` and `List` support `contains(value)`, so this method and `bypassSet()` differ only in the return type.
	 *
	 * @return      `List<String>` List of bypassed handlers.
	 * @example
	 * List<String> bypassed = TriggerHandler.bypassList();
	 */
	public static List<String> bypassList() {
		List<String> bypasses = new List<String>(TriggerHandler.bypassedHandlers);
		bypasses.sort();
		// the alias marks the global bypass; a name added after bypassAll() stays in the collection
		if (globalBypass) {
			bypasses.add(BYPASS_ALL_ALIAS);
		}

		return bypasses;
	}

	/**
	 * Return a set of the bypassed handlers, as the caller spelled them.
	 * <br>When all handlers are bypassed, the set holds the alias `BypassAll`.
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
		Set<String> bypasses = new Set<String>(TriggerHandler.bypassedHandlers);
		// the alias marks the global bypass; a name added after bypassAll() stays in the collection
		if (globalBypass) {
			bypasses.add(BYPASS_ALL_ALIAS);
		}

		return bypasses;
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
	 * <br>Use it to keep a base set of bypassed handlers for a whole operation.
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
	 * Set bypass status to a specific value. Eliminates the need to know the current bypass status.
	 * <br>`false` also clears the global bypass, so that this handler runs. Every other handler then runs too, because a global bypass cannot exclude 1 handler.
	 * <br>So the save-and-restore idiom below restores the named bypass only, not a global bypass that was active before.
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
		clearGlobalBypass();
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
	 * Return the current loop count of a handler.
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
		this.setTriggerContext(Trigger.operationType, false);
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
		this.isTriggerExecuting = (Trigger.isExecuting || testMode == true) && opType != null;
		this.triggerEvent = opType;
	}

	/**
	 * Increment the loop count and check whether the limit is exceeded.
	 * <br>When it is exceeded, log a warning and tell `run()` to return without calling the context method.
	 *
	 * @author {@link [David Schach](https://github.com/dschach)}
	 * @author {@link [fbouzeraa](https://github.com/fbouzeraa)}
	 * @return   `Boolean` `true` when `run()` should continue, `false` when the limit is exceeded.
	 */
	private Boolean incrementCheckLoopCount() {
		if (TriggerHandler.loopCountMap.isEmpty()) {
			return true;
		}
		LoopCount loopCount = TriggerHandler.loopCountMap.get(getHandlerName());
		if (loopCount == null || !loopCount.increment()) {
			return true;
		}
		this.log(LoggingLevel.WARN, 'Maximum loop count of ' + loopCount.getMax() + ' exceeded in ' + getHandlerName() + ', so run() skipped ' + this.triggerEvent.name());
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
		if (!this.isTriggerExecuting || this.triggerEvent == null) {
			throw new TriggerHandlerException(ERROR_TRIGGERCONTEXT);
		}
		if (globalBypass) {
			return false;
		}
		return TriggerHandler.bypassedHandlersLower.isEmpty() || !TriggerHandler.bypassedHandlersLower.contains(getHandlerName().toLowerCase());
	}

	/**
	 * The trigger operation this handler is running for. Also set under the test seam, where `Trigger.operationType` is null.
	 * @return `System.TriggerOperation` The current operation, or null outside a trigger.
	 */
	protected System.TriggerOperation getTriggerEvent() {
		return this.triggerEvent;
	}

	/**
	 * The name of this handler, as given to the String constructor or resolved from the runtime class name.
	 * <br>Available to subclasses, for example for a log line or a `bypass()` call.
	 * <br>The runtime lookup reads the start of `toString()`. A handler that overrides `toString()` must pass its name to the String constructor.
	 *
	 * @return      `String` Name of the current handler.
	 * @see         TriggerHandler.handlerName
	 */
	@TestVisible
	protected String getHandlerName() {
		if (String.isBlank(this.handlerName)) {
			this.handlerName = this.toString().substringBefore(CLASS_NAME_END);
		}
		return this.handlerName;
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
		this.setTriggerContext(inTest ? operation : Trigger.operationType, inTest);
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
	 * Inner class that keeps the loop count of 1 handler.
	 */
	@TestVisible
	private inherited sharing class LoopCount {
		/**
		 * Maximum number of times this handler should be run.
		 */
		private Integer max;
		/**
		 * Number of times this handler has been run.
		 */
		private Integer count;

		/**
		 * Standard constructor. The max is `DEFAULT_MAX_LOOP_COUNT`, 5, and the count is 0.
		 */
		public LoopCount() {
			this.max = DEFAULT_MAX_LOOP_COUNT;
			this.count = 0;
		}

		/**
		 * Constructor with specified max loops.
		 *
		 * @param max   Max number of loops allowed.
		 */
		public LoopCount(Integer max) {
			this.max = max;
			this.count = 0;
		}

		/**
		 * Increment the internal counter and return `exceeded()`.
		 * @return     `Boolean` true when the new count is greater than a max of 0 or more. A negative max never exceeds.
		 */
		public Boolean increment() {
			this.count++;
			return this.exceeded();
		}

		/**
		 * Whether the count has passed the limit.
		 * @return     `Boolean` true when max is 0 or more and count is greater than max. A negative max means no limit.
		 */
		public Boolean exceeded() {
			return this.max >= 0 && this.count > this.max;
		}

		/**
		 * Returns the max loop count.
		 * @return     `Integer` Max loop count.
		 */
		public Integer getMax() {
			return this.max;
		}

		/**
		 * Returns the current loop count.
		 * @return     `Integer` Current loop count.
		 */
		public Integer getCount() {
			return this.count;
		}

		/**
		 * Sets the max loop count.
		 * @param max   The new maximum. A negative value means no limit.
		 */
		public void setMax(Integer max) {
			this.max = max;
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