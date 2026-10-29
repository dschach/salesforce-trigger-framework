# Sample trigger handler

This folder holds a sample trigger, trigger handler, and test for the [Salesforce Trigger Framework](../README.md). It is not a package directory, so a deploy of the framework does not install it.

## What it contains

- `main/default/triggers/AccountSampleTrigger.trigger` has no logic: it creates the handler and calls `run()`. It lists all 7 contexts, even the ones the handler does not override, so the trigger is written once and never edited again. A new override in the handler runs without a change to the trigger:

  ```apex
  trigger AccountSampleTrigger on Account(before insert, before update, before delete, after insert, after update, after delete, after undelete) {
  	new AccountSampleTriggerHandler().run();
  }
  ```

- `main/default/classes/AccountSampleTriggerHandler.cls` extends `TriggerHandler` and shows these parts of the framework:
  - The constructor passes the class name to `super()`, casts the trigger collections that the handler uses, and sets a loop limit with `setMaxLoopCount()`. The limit is high enough that a bulk update does not reach it.
  - Before insert, it removes extra spaces from each Account name. Before update, it does the same only for the names that changed, which it finds with the old records.
  - After update, it copies a changed phone number to the child Accounts. It bypasses itself with `TriggerHandler.bypass(AccountSampleTriggerHandler.class)` for that update, so the update does not run the handler again, and it clears the bypass in a `finally` block.
  - `andFinally()` runs after each of the 7 contexts, also the ones the handler does not override. The sample records the finished operation, which the test reads.
  - The handler is `inherited sharing`, and its query and DML statement name `SYSTEM_MODE`. A trigger runs without sharing, so the handler can update child Accounts that the running user cannot edit.
- `main/default/classes/AccountSampleTriggerHandlerTest.cls` proves each of these behaviors with real DML, 1 test per behavior. It also shows how a test bypasses a handler to set up data.

## Try it in a scratch org

Deploy the framework and the sample together, and run the sample test:

```bash
sf project deploy start --source-dir force-app --source-dir sample-handler --target-org <alias>
sf apex run test --class-names AccountSampleTriggerHandlerTest --target-org <alias> --wait 10
```
