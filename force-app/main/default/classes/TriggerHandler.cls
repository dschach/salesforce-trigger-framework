@SuppressWarnings('PMD.ExcessivePublicCount, PMD.CyclomaticComplexity, PMD.FieldDeclarationsShouldBeAtStart, PMD.EmptyStatementBlock')
/**
 * @description Trigger Handler virtual class as base for all trigger handlers
 * @author Kevin O'Hara
 * @author David Schach
 * @since 2013
 * @group TriggerHandler
 * @group-content doc-assets/example.html
 * @see [License](https://github.com/dschach/salesforce-trigger-handler/blob/master/LICENSE)
 * @see [GitHub](https://github.com/dschach/salesforce-trigger-handler)
 */
public virtual class TriggerHandler {
	@TestVisible
	/**
	 * static map of `handlerName`, times `run()` was invoked
	 */
	private static Map<String, LoopCount> loopCountMap;

	@TestVisible
	/**
	 * All bypassed handlers
	 */
	private static Set<String> bypassedHandlers;

	@TestVisible
	/**
	 * `true` if we bypass all triggers without checking the contents of `bypassedHandlers`
	 */
	private static Boolean globalBypass;

	@TestVisible
	/**
	 * `true` if we include a debug statement for limits
	 */
	private static Boolean showLimits;

	@TestVisible
	/**
	 * the current triggerEvent of the trigger, overridable in tests
	 * */
	private System.TriggerOperation triggerEvent;

	@TestVisible
	/**
	 * Is this class executing in trigger context?
	 * @author David Schach
	 */
	private Boolean isTriggerExecuting;

	// static initialization variables
	static {
		loopCountMap = new Map<String, LoopCount>();
		bypassedHandlers = new Set<String>();
		globalBypass = false;
		showLimits = false;
	}

	/**
	 * @description Basic constructor
	 */
	public TriggerHandler() {
		this.setTriggerContext();
	}

	/**
	 * @description Constructor with handler name to improve performance
	 * @author David Schach
	 * @param  handlerName The name of the handler
	 */
	public TriggerHandler(String handlerName) {
		this.handlerName = handlerName;
		this.setTriggerContext();
	}

	// public instance methods

	/**
	 * @description main method that will be called during execution
	 * <br> See the sample trigger for the best way to set up your handler
	 * @author Kevin O'Hara
	 * @author David Schach
	 * @example
	 * new AccountSampleTriggerHandler().run();
	 */
	public void run() {
		if (!validateRun()) {
			return;
		}

		addToLoopCount();

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

		if (showLimits) {
			System.debug(
				LoggingLevel.DEBUG,
				String.format(
					'{0} on {1} ({2}/{3} queries) and ({4}/{5} DML calls',
					new List<String>{
						this.triggerEvent + '',
						getHandlerName(),
						Limits.getQueries() + '',
						Limits.getLimitQueries() + '',
						Limits.getDmlStatements() + '',
						Limits.getLimitDmlStatements() + ''
					}
				)
			); // NOPMD
		}
	}

	/**
	 * @description setMaxLoopCount description
	 * @author David Schach
	 * @param  max max description
	 * @example
	 * TriggerHandler.setMaxLoopCount(5);
	 */
	public void setMaxLoopCount(Integer max) {
		String handlerName = getHandlerName();
		if (!TriggerHandler.loopCountMap.containsKey(handlerName)) {
			TriggerHandler.loopCountMap.put(handlerName, new LoopCount(max));
		} else {
			TriggerHandler.loopCountMap.get(handlerName).setMax(max);
		}
	}

	/**
	 * @description Removes the limit for the number of times we allow this class to run
	 */
	public void clearMaxLoopCount() {
		this.setMaxLoopCount(-1);
	}

	/**
	 * @description       bypass by string, e.g. TriggerHandler.bypass('AccountTriggerHandler')
	 *
	 * @param handlerName Name of the handler to be bypassed
	 * @example TriggerHandler.bypass('AccountSampleTriggerHandler')
	 */
	public static void bypass(String handlerName) {
		TriggerHandler.bypassedHandlers.add(handlerName);
	}

	/**
	 * @description        bypass by list, e.g. TriggerHandler.bypass(listOfHandlerStrings)
	 *
	 * @param handlerNames List of handlernames
	 */
	public static void bypass(List<String> handlerNames) {
		TriggerHandler.bypassedHandlers.addAll(handlerNames);
	}

	/**
	 * @description bypass all handlers (clear bypassedHandlers to prevent confusion)
	 */
	public static void bypassAll() {
		TriggerHandler.bypassedHandlers.clear();
		globalBypass = true;
	}

	/**
	 * @description bypass a specific handler
	 *
	 * @param handlerName The class name to be bypassed
	 * @example
	 * TriggerHandler.clearBypass('AccountSampleTriggerHandler')
	 */
	public static void clearBypass(String handlerName) {
		TriggerHandler.bypassedHandlers.remove(handlerName);
	}

	/**
	 * @description         bypass a list of handlers
	 *
	 * @param handlersNames
	 * @example
	 * List<String> classList = ['AccountTriggerHandler','ContactTriggerHandler'];
	 * TriggerHandler.clearBypass(classList;
	 */
	public static void clearBypass(List<String> handlersNames) {
		TriggerHandler.bypassedHandlers.removeAll(handlersNames);
	}

	/**
	 * @description       a handler is considered bypassed if it was bypassed, or all handlers have been bypassed
	 *
	 * @param handlerName The class name of the handler we are checking is bypassed
	 * @return            `Boolean` Is this handler bypassed?
	 * @example
	 * TriggerHandler.isBypassed('AccountTriggerHandler');
	 */
	public static Boolean isBypassed(String handlerName) {
		return (globalBypass || TriggerHandler.bypassedHandlers.contains(handlerName));
	}

	/**
	 * @description return a list of the bypassed handlers
	 *
	 * @return      `List<String>`
	 * @example
	 * TriggerHandler.bypassList();
	 */
	public static List<String> bypassList() {
		List<String> bypasses = new List<String>(TriggerHandler.bypassedHandlers);
		bypasses.sort();
		// bypassAll clears bypassedHandlers, so bypasses is empty here
		if (globalBypass) {
			bypasses.add('bypassAll');
		}

		return bypasses;
	}

	/**
	 * @description clear all bypasses - by clearing the global bypass and by clearing the list of bypassed handlers
	 * @example
	 * TriggerHandler.clearAllBypasses();
	 */
	public static void clearAllBypasses() {
		clearGlobalBypass();
		clearBypassList();
	}

	/**
	 * @description clear only the global bypass flag, leaving the list of bypassed handlers intact
	 * <br>This is useful for keeping a base set of bypassed handlers intact for an entire operation
	 * @example
	 * TriggerHandler.clearGlobalBypass();
	 */
	public static void clearGlobalBypass() {
		globalBypass = false;
	}

	/**
	 * @description clear the entire bypass list, but keep the global bypass flag intact
	 * <br>This is useful for resetting the list of handlers to bypass while maintaining global bypassing
	 * @example
	 * TriggerHandler.clearBypassList();
	 */
	public static void clearBypassList() {
		TriggerHandler.bypassedHandlers.clear();
	}

	/**
	 * @description Set bypass status to a specific value. Eliminates the need to know the current bypass status
	 * @param  handlerName  The name of the TriggerHandler class
	 * @param  desiredValue `true` to bypass, and `false` to run the handler
	 * @example
	 * TriggerHandler.setBypass('AccountTriggerHandler', false);
	 */
	public static void setBypass(String handlerName, Boolean desiredValue) {
		if (globalBypass) {
			if (desiredValue == true) {
				TriggerHandler.bypass(handlerName);
			} else if (desiredValue == false) {
				clearGlobalBypass();
				TriggerHandler.clearBypass(handlerName);
			}
		}

		if (TriggerHandler.isBypassed(handlerName)) {
			if (desiredValue == false) {
				TriggerHandler.clearBypass(handlerName);
			}
		} else {
			if (desiredValue == true) {
				TriggerHandler.bypass(handlerName);
			}
		}
	}

	// handle limits
	/**
	 * @description Called in the trigger to force the class to debug query limits when it runs
	 * @example
	 * new AccountSampleTriggerHandler.showLimits().run();
	 */
	public static void showLimits() {
		showLimits(true);
	}

	/**
	 * @description   Called in the trigger to force the class to debug limits when it runs.
	 * <br>Set to true to show limits.
	 *
	 * @param enabled true to enable; false to disable
	 * @see TriggerHandler.showLimits[0]
	 */
	public static void showLimits(Boolean enabled) {
		showLimits = enabled;
	}

	/**
	 * @description       return the current loop count
	 *
	 * @param handlerName The handler class to check for the current loop count
	 * @return            `Integer`
	 */
	public static Integer getLoopCount(String handlerName) {
		if (TriggerHandler.loopCountMap.containsKey(handlerName)) {
			return TriggerHandler.loopCountMap.get(handlerName).getCount();
		}
		return 0;
	}

	//private instancemethods
	@TestVisible
	/**
	 * @description Base method called by constructor to set the current context
	 */
	private void setTriggerContext() {
		this.setTriggerContext(Trigger.operationType, false);
	}

	@TestVisible
	/**
	 * @description    Set the current trigger context based on the System.TriggerOperation
	 * <br>If we are not in a trigger context, then we set isTriggerExecuting to false
	 *
	 * @param opType   The operation type - set automatically by the system
	 * @param testMode Only used in test methods to force certain contexts
	 * @see TriggerHandler.isTriggerExecuting
	 */
	private void setTriggerContext(System.TriggerOperation opType, Boolean testMode) {
		if (!Trigger.isExecuting && !testMode) {
			this.isTriggerExecuting = false;
			return;
		} else {
			this.isTriggerExecuting = true;
		}

		if (Trigger.isExecuting && !testMode) {
			this.triggerEvent = Trigger.operationType;
		}

		String context = opType?.name();

		switch on context {
			when 'BEFORE_INSERT' {
				this.triggerEvent = System.TriggerOperation.BEFORE_INSERT;
			}
			when 'BEFORE_UPDATE' {
				this.triggerEvent = System.TriggerOperation.BEFORE_UPDATE;
			}
			when 'BEFORE_DELETE' {
				this.triggerEvent = System.TriggerOperation.BEFORE_DELETE;
			}
			when 'AFTER_INSERT' {
				this.triggerEvent = System.TriggerOperation.AFTER_INSERT;
			}
			when 'AFTER_UPDATE' {
				this.triggerEvent = System.TriggerOperation.AFTER_UPDATE;
			}
			when 'AFTER_DELETE' {
				this.triggerEvent = System.TriggerOperation.AFTER_DELETE;
			}
			when 'AFTER_UNDELETE' {
				this.triggerEvent = System.TriggerOperation.AFTER_UNDELETE;
			}
			when else {
				// we are not in trigger context
				this.isTriggerExecuting = false;
			}
		}
	}

	/**
	 * @description increment the loop count
	 *
	 * @exception   TriggerHandlerException
	 * @see TriggerHandler.TriggerHandlerException
	 */
	private void addToLoopCount() {
		String handlerName = getHandlerName();
		if (TriggerHandler.loopCountMap.containsKey(handlerName)) {
			Boolean exceeded = TriggerHandler.loopCountMap.get(handlerName).increment();
			if (exceeded) {
				Integer max = TriggerHandler.loopCountMap.get(handlerName).max;
				throw new TriggerHandlerException('Maximum loop count of ' + String.valueOf(max) + ' reached in ' + handlerName);
			}
		}
	}

	@TestVisible
	/**
	 * @description Make sure this trigger should continue to run
	 * <br>Returning `false` causes trigger handler to exit
	 *
	 * @return      `Boolean` is the run valid?
	 * @exception   TriggerHandlerException
	 * @see TriggerHandler.TriggerHandlerException
	 */
	private Boolean validateRun() {
		if (!this.isTriggerExecuting || this.triggerEvent == null) {
			throw new TriggerHandlerException(errorOutsideTriggerContext);
		}
		return (!globalBypass && !TriggerHandler.bypassedHandlers.contains(getHandlerName()));
	}

	/**
	 * @description The name of this handler. Set by `getHandlerName()`
	 */
	private String handlerName;

	@TestVisible
	/**
	 * @description Get the name of the current handler. This can be set by using the constructor with the string parameter to improve performance
	 *
	 * @return      `String` handlerName
	 * @see         TriggerHandler.handlerName
	 */
	private String getHandlerName() {
		if (String.isBlank(this.handlerName)) {
			this.handlerName = String.valueOf(this).substring(0, String.valueOf(this).indexOf(':'));
		}
		return this.handlerName;
	}

	//triggerEvent methods

	@TestVisible
	/**
	 * @description Virtual method for the implementing class to override
	 */
	protected virtual void beforeInsert() {
	}

	@TestVisible
	/**
	 * @description Virtual method for the implementing class to override
	 */
	protected virtual void beforeUpdate() {
	}
	@TestVisible
	/**
	 * @description Virtual method for the implementing class to override
	 */
	protected virtual void beforeDelete() {
	}

	@TestVisible
	/**
	 * @description Virtual method for the implementing class to override
	 */
	protected virtual void afterInsert() {
	}

	@TestVisible
	/**
	 * @description Virtual method for the implementing class to override
	 */
	protected virtual void afterUpdate() {
	}

	@TestVisible
	/**
	 * @description Virtual method for the implementing class to override
	 */
	protected virtual void afterDelete() {
	}

	@TestVisible
	/**
	 * @description Virtual method for the implementing class to override
	 */
	protected virtual void afterUndelete() {
	}

	// inner classes

	/**
	 * @description inner class for managing the loop count per handler
	 */
	@TestVisible
	private class LoopCount {
		private Integer max;
		private Integer count;

		/**
		 * @description Default loop count to 5
		 */
		public LoopCount() {
			this.max = 5;
			this.count = 0;
		}

		/**
		 * @description Constructor with specified max loops
		 *
		 * @param max   Max number of loops allowed
		 */
		public LoopCount(Integer max) {
			this.max = max;
			this.count = 0;
		}

		/**
		 * @description Increment the internal counter returning the results of
		 * this.exceeded().
		 * @return     `Boolean` true if count will exceed max count or is less
		 * than 0.
		 */
		public Boolean increment() {
			this.count++;
			return this.exceeded();
		}

		/**
		 * @description Determines if this we're about to exceed the loop count.
		 * @return     `Boolean` true if less than 0 or more than max.
		 */
		public Boolean exceeded() {
			return this.max >= 0 && this.count > this.max;
		}

		/**
		 * @description Returns the max loop count.
		 * @return     `Integer` max loop count.
		 */
		public Integer getMax() {
			return this.max;
		}

		/**
		 * @description Returns the current loop count.
		 * @return     `Integer` current loop count.
		 */
		public Integer getCount() {
			return this.count;
		}

		/**
		 * @description Sets the max loop size
		 * @param max   The integer to set max to.
		 */
		public void setMax(Integer max) {
			this.max = max;
		}
	}

	/**
	 * @description Exception class
	 */
	public class TriggerHandlerException extends Exception {
	}

	@TestVisible
	/**
	 * @description Error text - assumes English for debug logs
	 */
	private static String errorOutsideTriggerContext = 'Trigger handler called outside of Trigger execution'; //NOPMD
}
