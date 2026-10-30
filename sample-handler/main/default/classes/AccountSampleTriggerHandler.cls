/**
 * A sample Account trigger handler that shows the framework in use.
 * <br>Before insert and before update, it removes extra spaces from each new or changed Account name.
 * <br>After update, it copies a changed phone number to the child Accounts. It bypasses itself for that update, so the update does not run this handler again.
 * <br>A loop limit protects against recursion that the bypass does not stop, and `andFinally()` runs after each context.
 * <br>A trigger runs without sharing, so this `inherited sharing` handler does too. Every query and DML statement names `SYSTEM_MODE`, so the handler can update child Accounts that the running user cannot edit.
 * @author David Schach
 * @since 2021
 * @group SampleTriggerHandler
 * @group-content doc-assets/files/sampletriggerhandlerhome.html
 * @see AccountSampleTriggerHandlerTest
 */
public inherited sharing class AccountSampleTriggerHandler extends TriggerHandler {
	/**
	 * The maximum number of runs of this handler in 1 transaction. Each trigger context and each chunk of 200 records uses 1 run, so 100 allows an update of 10,000 records, which runs before update and after update 50 times each.
	 */
	private static final Integer MAX_LOOP_COUNT = 100;

	/**
	 * The trigger operations this handler finished in the transaction, in order. `andFinally()` adds each one.
	 */
	@TestVisible
	private static List<System.TriggerOperation> finishedOperations = new List<System.TriggerOperation>();

	private List<Account> newRecords;
	private Map<Id, Account> oldRecordsMap;

	/**
	 * Constructor for the trigger. It passes the class name, so the base class never resolves it at runtime.
	 * @see AccountSampleTriggerHandler.AccountSampleTriggerHandler[1]
	 * @example
	 * new AccountSampleTriggerHandler().run();
	 */
	public AccountSampleTriggerHandler() {
		this(AccountSampleTriggerHandler.class.getName());
	}

	/**
	 * Constructor with the handler name. It casts the trigger collections that the handler uses, and it sets the loop limit.
	 * @param className The name of this class, exactly as `Type.getName()` returns it.
	 */
	public AccountSampleTriggerHandler(String className) {
		super(className);
		this.newRecords = (List<Account>) Trigger.new;
		this.oldRecordsMap = (Map<Id, Account>) Trigger.oldMap;
		this.setMaxLoopCount(MAX_LOOP_COUNT);
	}

	/**
	 * Remove extra spaces from the name of each new Account.
	 */
	public override void beforeInsert() {
		normalizeNames(this.newRecords);
	}

	/**
	 * Remove extra spaces from each Account name that changed.
	 */
	public override void beforeUpdate() {
		List<Account> renamedAccounts = new List<Account>();
		for (Account updatedAccount : this.newRecords) {
			if (updatedAccount.Name != this.oldRecordsMap.get(updatedAccount.Id).Name) {
				renamedAccounts.add(updatedAccount);
			}
		}
		normalizeNames(renamedAccounts);
	}

	/**
	 * Copy each changed phone number to the child Accounts.
	 */
	public override void afterUpdate() {
		Map<Id, String> phoneByParentId = new Map<Id, String>();
		for (Account updatedAccount : this.newRecords) {
			if (updatedAccount.Phone != this.oldRecordsMap.get(updatedAccount.Id).Phone) {
				phoneByParentId.put(updatedAccount.Id, updatedAccount.Phone);
			}
		}
		if (phoneByParentId.isEmpty()) {
			return;
		}
		copyPhoneToChildAccounts(phoneByParentId);
	}

	/**
	 * Record the finished operation. A real handler puts work here that must follow every context, such as a rollup or 1 platform event for the whole trigger.
	 */
	public override void andFinally() {
		finishedOperations.add(this.getTriggerEvent());
	}

	/**
	 * Replace each run of spaces in the Account names with 1 space, and remove the spaces at the start and the end.
	 * @param accounts The Accounts to change.
	 */
	private static void normalizeNames(List<Account> accounts) {
		for (Account changedAccount : accounts) {
			changedAccount.Name = changedAccount.Name.normalizeSpace();
		}
	}

	/**
	 * Update the phone number of the child Accounts, with this handler bypassed for that update.
	 * <br>A child Account that is in the same trigger run is left out, because a trigger cannot update the records it is running for.
	 * <br>The query and the update run in system mode, so `FlagSystemMode` is suppressed for this method. The phone number must reach every child Account, also a child Account that the running user cannot see or edit.
	 * @param phoneByParentId The new phone number of each parent Account, by Id.
	 */
	@SuppressWarnings('PMD.FlagSystemMode')
	private void copyPhoneToChildAccounts(Map<Id, String> phoneByParentId) {
		Set<Id> parentIds = phoneByParentId.keySet();
		List<Account> childAccounts = new List<Account>();
		for (Account childAccount : [SELECT Id, ParentId FROM Account WHERE ParentId IN :parentIds WITH SYSTEM_MODE]) {
			if (!this.oldRecordsMap.containsKey(childAccount.Id)) {
				childAccount.Phone = phoneByParentId.get(childAccount.ParentId);
				childAccounts.add(childAccount);
			}
		}
		if (childAccounts.isEmpty()) {
			return;
		}
		// This handler is running, so it was not bypassed before. The finally block restores that state, also when the update fails.
		TriggerHandler.bypass(AccountSampleTriggerHandler.class);
		try {
			Database.update(childAccounts, AccessLevel.SYSTEM_MODE);
		} finally {
			TriggerHandler.clearBypass(AccountSampleTriggerHandler.class);
		}
	}
}