# Sample Trigger Handler

This folder holds a sample trigger, a sample trigger handler, and a test for the [Salesforce Trigger Framework](../README.md). It is not a package directory, so a deploy of the framework does not install it.

## Design

- Each object has 1 trigger.
- Each trigger has 1 handler.

## What It Contains

### The Trigger

[`main/default/triggers/AccountSampleTrigger.trigger`](https://github.com/dschach/salesforce-trigger-framework/blob/main/sample-handler/main/default/triggers/AccountSampleTrigger.trigger) has no logic: it creates the handler and calls `run()`. It lists all 7 contexts, also the contexts that the handler does not override. So you write the trigger once and do not change it again. A new override in the handler runs with no change to the trigger.

<!-- START sample-code main/default/triggers/AccountSampleTrigger.trigger -->

```apex
/**
 * The sample trigger for the sample handler. It has no logic: it creates the handler and calls `run()`.
 * <br>It lists all 7 contexts. So you write it once and do not change it again: a new override in the handler runs with no change to the trigger.
 * <br>A context that the handler does not override costs little. `run()` calls the empty base method and then `andFinally()`.
 * @group SampleTriggerHandler
 */
trigger AccountSampleTrigger on Account(before insert, before update, before delete, after insert, after update, after delete, after undelete) {
  new AccountSampleTriggerHandler().run();
}
```

<!-- END sample-code -->

### The Handler

[`main/default/classes/AccountSampleTriggerHandler.cls`](https://github.com/dschach/salesforce-trigger-framework/blob/main/sample-handler/main/default/classes/AccountSampleTriggerHandler.cls) extends `TriggerHandler` and shows these parts of the framework:

- The constructor passes the class to `super()`, casts the trigger collections that the handler uses, and sets a loop limit with `setMaxLoopCount()`. The limit is high, so a bulk update does not reach it.
- Before insert, the handler removes extra spaces from each Account name. Before update, it does the same only for the names that changed. It finds them with the old records.
- After update, the handler copies a changed phone number to the child Accounts. For that update, it bypasses itself with `TriggerHandler.bypass(AccountSampleTriggerHandler.class)`, so the update does not run the handler again. It clears the bypass in a `finally` block.
- `andFinally()` runs after each of the 7 contexts, also the contexts that the handler does not override. The sample records the finished operation, and the test reads it.
- The handler is `inherited sharing`, and its query and DML statement name `SYSTEM_MODE`. A trigger runs without sharing, so the handler can update child Accounts that the running user cannot edit. Code Analyzer reports system mode with `FlagSystemMode`, so the method suppresses that rule, and its ApexDoc gives the reason.

<!-- START sample-code main/default/classes/AccountSampleTriggerHandler.cls -->

```apex
/**
 * A sample Account trigger handler that shows how to use the framework.
 * <br>Before insert and before update, it removes extra spaces from each new or changed Account name.
 * <br>After update, it copies a changed phone number to the child Accounts. It bypasses itself for that update, so the update does not run this handler again.
 * <br>A loop limit stops recursion that the bypass does not stop. `andFinally()` runs after each context.
 * <br>A trigger runs without sharing, so this `inherited sharing` handler does too. Each query and DML statement names `SYSTEM_MODE`, so the handler can update child Accounts that the running user cannot edit.
 * @author David Schach
 * @since 2021
 * @group SampleTriggerHandler
 * @group-content doc-assets/files/sampletriggerhandlerhome.html
 * @see AccountSampleTriggerHandlerTest
 */
public inherited sharing class AccountSampleTriggerHandler extends TriggerHandler {
  /**
   * The maximum number of runs of each trigger operation of this handler in 1 transaction. Each chunk of 200 records uses 1 run. So 50 allows an update of 10,000 records, which runs before update and after update 50 times each.
   */
  private static final Integer MAX_LOOP_COUNT = 50;

  /**
   * The trigger operations that this handler finished in the transaction, in order. `andFinally()` adds each one.
   */
  @TestVisible
  private static List<System.TriggerOperation> finishedOperations = new List<System.TriggerOperation>();

  /**
   * The new Accounts of the trigger, cast from `Trigger.new`.
   */
  private List<Account> newRecords;

  /**
   * The old Accounts of the trigger by Id, cast from `Trigger.oldMap`. It is null in an insert.
   */
  private Map<Id, Account> oldRecordsMap;

  /**
   * Creates the handler for the trigger. It passes its class to the base class, so the base class does no name lookup. It casts the trigger collections that the handler uses, and it sets the loop limit.
   * @example
   * new AccountSampleTriggerHandler().run();
   */
  public AccountSampleTriggerHandler() {
    super(AccountSampleTriggerHandler.class);
    this.newRecords = (List<Account>) Trigger.new;
    this.oldRecordsMap = (Map<Id, Account>) Trigger.oldMap;
    this.setMaxLoopCount(MAX_LOOP_COUNT);
  }

  /**
   * Removes extra spaces from the name of each new Account.
   */
  public override void beforeInsert() {
    normalizeNames(newRecords);
  }

  /**
   * Removes extra spaces from each Account name that changed.
   */
  public override void beforeUpdate() {
    List<Account> renamedAccounts = new List<Account>();
    for (Account updatedAccount : newRecords) {
      if (updatedAccount.Name != oldRecordsMap.get(updatedAccount.Id).Name) {
        renamedAccounts.add(updatedAccount);
      }
    }
    normalizeNames(renamedAccounts);
  }

  /**
   * Copies each changed phone number to the child Accounts.
   */
  public override void afterUpdate() {
    Map<Id, String> phoneByParentId = new Map<Id, String>();
    for (Account updatedAccount : newRecords) {
      if (updatedAccount.Phone != oldRecordsMap.get(updatedAccount.Id).Phone) {
        phoneByParentId.put(updatedAccount.Id, updatedAccount.Phone);
      }
    }
    if (phoneByParentId.isEmpty()) {
      return;
    }
    copyPhoneToChildAccounts(phoneByParentId);
  }

  /**
   * Records the finished operation. A real handler puts work here that must follow each context, for example a rollup.
   * <br>`andFinally()` runs after each context and each chunk of 200 records. For work that must happen only once for a DML statement, such as 1 platform event, check `getTriggerEvent()` first.
   */
  public override void andFinally() {
    finishedOperations.add(getTriggerEvent());
  }

  /**
   * Replaces each group of spaces in the Account names with 1 space, and removes the spaces at the start and the end.
   * @param accounts The Accounts to change.
   */
  private static void normalizeNames(List<Account> accounts) {
    for (Account changedAccount : accounts) {
      changedAccount.Name = changedAccount.Name.normalizeSpace();
    }
  }

  /**
   * Updates the phone number of the child Accounts. The handler is bypassed for that update.
   * <br>It leaves out a child Account that is in the same trigger run, because a trigger cannot update the records that it runs for.
   * <br>The query and the update run in system mode, so this method suppresses `FlagSystemMode`. The phone number must reach all child Accounts, also the ones that the running user cannot see or edit.
   * @param phoneByParentId The new phone number of each parent Account, by Id.
   */
  @SuppressWarnings('PMD.FlagSystemMode')
  private void copyPhoneToChildAccounts(Map<Id, String> phoneByParentId) {
    Set<Id> parentIds = phoneByParentId.keySet();
    List<Account> childAccounts = new List<Account>();
    for (Account childAccount : [SELECT Id, ParentId FROM Account WHERE ParentId IN :parentIds WITH SYSTEM_MODE]) {
      if (!oldRecordsMap.containsKey(childAccount.Id)) {
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
```

<!-- END sample-code -->

### The Test

[`main/default/classes/AccountSampleTriggerHandlerTest.cls`](https://github.com/dschach/salesforce-trigger-framework/blob/main/sample-handler/main/default/classes/AccountSampleTriggerHandlerTest.cls) proves each of these behaviors with real DML, with 1 test for each behavior. It also shows how a test bypasses a handler to set up data. The test class suppresses `FlagSystemMode` for its own setup and checks.

## Try It in a Scratch Org

Deploy the framework and the sample together, and run the sample test:

```bash
sf project deploy start --source-dir force-app --source-dir sample-handler --target-org <alias>
sf apex run test --class-names AccountSampleTriggerHandlerTest --target-org <alias> --wait 10
```

## More Information

The [Usage section of the framework README](../README.md#usage) tells how to write a handler and a trigger.

## Credits

This sample is part of [salesforce-trigger-framework](https://github.com/dschach/salesforce-trigger-framework), which is based on [sfdc-trigger-framework](https://github.com/kevinohara80/sfdc-trigger-framework) by Kevin O'Hara.
