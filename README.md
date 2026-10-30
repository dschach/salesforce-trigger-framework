[![codecov](https://codecov.io/gh/dschach/salesforce-trigger-framework/branch/main/graph/badge.svg?token=1StpM73gpE)](https://codecov.io/gh/dschach/salesforce-trigger-framework)
[![CI](https://github.com/dschach/salesforce-trigger-framework/actions/workflows/ci.yml/badge.svg?branch=main&event=push)](https://github.com/dschach/salesforce-trigger-framework/actions/workflows/ci.yml)
[![Twitter](https://img.shields.io/twitter/follow/dschach.svg?style=social)](https://x.com/dschach)

# Salesforce Trigger Framework

<!-- START doctoc -->

- [Credit](#credit)
- [Documentation](#documentation)
  - [Changelog](#changelog)
- [Overview](#overview)
- [Usage](#usage)
  - [Trigger Handler](#trigger-handler)
  - [Pass the Handler Class to super()](#pass-the-handler-class-to-super)
  - [Trigger](#trigger)
  - [Data Access](#data-access)
- [Features](#features)
  - [Bypass API](#bypass-api)
  - [Check Bypass Status](#check-bypass-status)
  - [Global Bypass](#global-bypass)
  - [Set Bypass](#set-bypass)
  - [Max Loop Count](#max-loop-count)
  - [Debug Statements](#debug-statements)
  - [Send the Messages to Your Logging Framework](#send-the-messages-to-your-logging-framework)
  - [Universal Action](#universal-action)
- [Test a Handler Without DML](#test-a-handler-without-dml)
- [Overridable Methods](#overridable-methods)
- [Upgrade From Version 1](#upgrade-from-version-1)
  - [Changes for Handlers and Triggers](#changes-for-handlers-and-triggers)
  - [Changes for Tests](#changes-for-tests)
  - [Deprecated Members](#deprecated-members)
- [API Reference](#api-reference)
- [Contributing](#contributing)
- [License](#license)

<!-- END doctoc -->

## Credit

This framework is based on [sfdc-trigger-framework](https://github.com/kevinohara80/sfdc-trigger-framework) by Kevin O'Hara. Its MIT license notice is in [NOTICE](https://github.com/dschach/salesforce-trigger-framework/blob/main/NOTICE).

## Documentation

[Class Documentation](https://davidschach.com/salesforce-trigger-framework/TriggerHandler.html)

### Changelog

[Complete Changelog](CHANGELOG.md)

## Overview

(adapted from Kevin O'Hara)

A trigger should have no logic. Logic in a trigger is difficult to test and to maintain. The best practice is to put the trigger logic in a handler class.

This framework has 1 base class, **TriggerHandler**. Each of your trigger handlers extends it. The base class has a method for each trigger context, and it calls the correct method when the trigger fires.

The base class also controls how the triggers run. It has methods that bypass handlers, count and limit the runs of each handler, and write debug lines.

Most important, the framework is small and simple to use.

**Deploy to a scratch org:**
[Deploy instructions](./DEPLOY.md)

**Deploy to a Salesforce org:**
[![Deploy](https://raw.githubusercontent.com/afawcett/githubsfdeploy/master/deploy.png)](https://githubsfdeploy.herokuapp.com/?owner=dschach&repo=salesforce-trigger-framework)

## Usage

### Trigger Handler

To create a trigger handler, create a class that extends [TriggerHandler.cls](https://github.com/dschach/salesforce-trigger-framework/blob/main/force-app/main/default/classes/TriggerHandler.cls). This is an Opportunity trigger handler:

```apex
public inherited sharing class OpportunityTriggerHandler extends TriggerHandler {
}
```

To add logic to a trigger context, override the method of that context in the handler. This handler has logic for before update and after update.

**Note:** The static trigger collections, such as `Trigger.new` and `Trigger.oldMap`, hold `SObject` records, not `Opportunity` or `Account` records. So you must cast them in the handler. The constructor is a good place for the casts. You must cast `Trigger.newMap` and `Trigger.oldMap`. Cast `Trigger.new` and `Trigger.old` too, so that all 4 collections are the same.

```apex
public inherited sharing class OpportunityTriggerHandler extends TriggerHandler {
  private List<Opportunity> newRecords;
  private List<Opportunity> oldRecords;
  private Map<Id, Opportunity> newRecordsMap;
  private Map<Id, Opportunity> oldRecordsMap;

  public OpportunityTriggerHandler() {
    super(OpportunityTriggerHandler.class);
    this.newRecords = (List<Opportunity>) Trigger.new;
    this.oldRecords = (List<Opportunity>) Trigger.old;
    this.newRecordsMap = (Map<Id, Opportunity>) Trigger.newMap;
    this.oldRecordsMap = (Map<Id, Opportunity>) Trigger.oldMap;
  }

  public override void beforeUpdate() {
    for (Opportunity o : newRecords) {
      /* do something */
    }
  }

  public override void afterUpdate() {
    /* do something */
  }

  /* add overrides for other contexts */
}
```

The class in `super()` is optional, but it makes the handler faster. Without it, the framework finds the name from the running class when a bypass or a loop count first needs it. That lookup serializes all fields of the handler, also the record lists. With the class, the handler name is `Type.getName()`, so `TriggerHandler.bypass(OpportunityTriggerHandler.class)` always matches. A handler that is an inner class must pass its class, because the lookup gives only the short name of an inner class. [Pass the Handler Class to super()](#pass-the-handler-class-to-super) has more examples.

This repository has a sample [AccountSampleTriggerHandler](https://github.com/dschach/salesforce-trigger-framework/tree/main/sample-handler/main/default/classes) class and a sample [trigger](https://github.com/dschach/salesforce-trigger-framework/blob/main/sample-handler/main/default/triggers/AccountSampleTrigger.trigger). The sample is not a package directory, so the Deploy to Salesforce button and `sf project deploy start` install only the framework. To try the sample in a scratch org, run `sf project deploy start --source-dir force-app --source-dir sample-handler`. The [sample README](sample-handler/README.md) tells what the sample shows.

### Pass the Handler Class to super()

The value to pass is the name of your handler class, followed by `.class`. In Apex, `ClassName.class` is the `Type` of that class. The framework uses `Type.getName()` as the handler name, so a bypass by type always matches the handler.

```apex
public inherited sharing class OpportunityTriggerHandler extends TriggerHandler {
  private List<Opportunity> newRecords;
  private List<Opportunity> oldRecords;

  public OpportunityTriggerHandler() {
    super(OpportunityTriggerHandler.class);
    this.newRecords = (List<Opportunity>) Trigger.new;
    this.oldRecords = (List<Opportunity>) Trigger.old;
  }
}
```

Call `super()` first. Then cast the trigger collections that the handler uses.

For a handler that is an inner class, write the outer class name, a dot, and the inner class name. The handler name is then `SalesHandlers.OpportunityTriggerHandler`, and `TriggerHandler.bypass(SalesHandlers.OpportunityTriggerHandler.class)` matches it. An inner-class handler must pass its class. Without the class, the framework finds only the short name, `OpportunityTriggerHandler`.

```apex
public inherited sharing class SalesHandlers {
  public inherited sharing class OpportunityTriggerHandler extends TriggerHandler {
    private List<Opportunity> newRecords;
    private List<Opportunity> oldRecords;

    public OpportunityTriggerHandler() {
      super(SalesHandlers.OpportunityTriggerHandler.class);
      this.newRecords = (List<Opportunity>) Trigger.new;
      this.oldRecords = (List<Opportunity>) Trigger.old;
    }
  }
}
```

A handler with more than 1 constructor passes the class in the constructor that calls `super()`. The other constructors call that constructor with `this()`. In this example, the trigger uses the first constructor, which passes `Trigger.new` and `Trigger.old` to the second. A test can call the second constructor with its own records.

```apex
public inherited sharing class OpportunityTriggerHandler extends TriggerHandler {
  private List<Opportunity> newRecords;
  private List<Opportunity> oldRecords;

  public OpportunityTriggerHandler() {
    this((List<Opportunity>) Trigger.new, (List<Opportunity>) Trigger.old);
  }

  public OpportunityTriggerHandler(List<Opportunity> newRecords, List<Opportunity> oldRecords) {
    super(OpportunityTriggerHandler.class);
    this.newRecords = newRecords;
    this.oldRecords = oldRecords;
  }
}
```

To see the name that the framework uses, call `getHandlerName()` in the handler, or `OpportunityTriggerHandler.class.getName()` from any code.

### Trigger

To use the handler, create an instance in the trigger and call `run()`. This trigger runs the handler above.

List all 7 contexts, also the contexts that the handler does not override yet. Then you write the trigger once and do not change it again: a new override in the handler runs with no change to the trigger. A context that the handler does not override costs little, because `run()` calls the empty base method and then `andFinally()`. Some objects do not support all contexts, for example an object that cannot be undeleted. For such an object, leave out the contexts that it does not support.

```apex
trigger OpportunityTrigger on Opportunity(before insert, before update, before delete, after insert, after update, after delete, after undelete) {
  new OpportunityTriggerHandler().run();
}
```

### Data Access

A trigger runs without sharing, so a handler declared `inherited sharing` runs without sharing too. A handler often must read or change records that the running user cannot see or edit, for example related records. So the examples here name `SYSTEM_MODE` on each query and DML statement: `WITH SYSTEM_MODE` in SOQL, and `AccessLevel.SYSTEM_MODE` in `Database` methods. System mode ignores the object and field permissions of the user, and the sharing of the class controls the record access.

If a handler must obey the object, field, and record permissions of the running user, use `WITH USER_MODE` and `AccessLevel.USER_MODE` instead.

## Features

### Bypass API

A handler can stop other handlers for a time. Bypass the other handler, do the DML, and clear the bypass:

```apex
public inherited sharing class OpportunityTriggerHandler extends TriggerHandler {
  private Map<Id, Opportunity> newRecordsMap;

  public OpportunityTriggerHandler() {
    super(OpportunityTriggerHandler.class);
    this.newRecordsMap = (Map<Id, Opportunity>) Trigger.newMap;
  }

  public override void afterUpdate() {
    List<Opportunity> opps = [SELECT Id, AccountId FROM Opportunity WHERE Id IN :newRecordsMap.keySet() WITH SYSTEM_MODE];

    Account acc = [SELECT Id, Name FROM Account WHERE Id = :opps.get(0).AccountId WITH SYSTEM_MODE];

    TriggerHandler.bypass('AccountTriggerHandler');

    acc.Name = 'No Trigger';
    Database.update(acc, AccessLevel.SYSTEM_MODE); /* does not run the AccountTriggerHandler */

    TriggerHandler.clearBypass('AccountTriggerHandler');

    acc.Name = 'With Trigger';
    Database.update(acc, AccessLevel.SYSTEM_MODE); /* runs the AccountTriggerHandler */
  }
}
```

Bypass names match in any case. You can also bypass by type, as in `TriggerHandler.bypass(AccountTriggerHandler.class)`, and the compiler then checks the name. A null or blank name, a null type, or a null list throws `TriggerHandler.TriggerHandlerException`.

### Check Bypass Status

A handler can be bypassed by name, or all handlers can be bypassed together. 3 methods tell you which:

- `isBypassed(name)` or `isBypassed(type)` is `true` when the handler is bypassed by name or by type. It does not include the global bypass.
- `isGlobalBypassed()` is `true` when all handlers are bypassed.
- `isSkipped(name)` or `isSkipped(type)` is `true` when either of them is true, so the handler does not run.

```apex
if (TriggerHandler.isSkipped(AccountTriggerHandler.class)) {
  /* the Account trigger handler does not run */
}
```

### Global Bypass

To bypass all handlers, call `bypassAll()`:

```apex
TriggerHandler.bypassAll();
```

The named bypasses stay, and they apply again after `clearGlobalBypass()`. `bypassList()` returns only the named bypasses. To check the global bypass, call `isGlobalBypassed()`.

To clear all bypasses for the transaction, call `clearAllBypasses()`:

```apex
/* the bypasses are no longer necessary */

TriggerHandler.clearAllBypasses();

/* all handlers run again */
```

`clearAllBypasses()` clears the named bypasses and the global bypass. To clear only 1 of them, call `clearBypassList()` or `clearGlobalBypass()`.

### Set Bypass

To bypass a handler for a time and then give back its earlier bypass state, use `setBypass()`. You do not have to know the state first:

```apex
Boolean isBypassed = TriggerHandler.isBypassed('AccountTriggerHandler');
TriggerHandler.bypass('AccountTriggerHandler');

/* update the records here */

TriggerHandler.setBypass('AccountTriggerHandler', isBypassed);
```

`setBypass(name, false)` clears only the named bypass, and `isBypassed()` tells only about the named bypass. So this example gives back the exact earlier state, and a global bypass stays on. `setBypass()` also takes a type, as in `TriggerHandler.setBypass(AccountTriggerHandler.class, isBypassed)`, and the compiler then checks the name.

To bypass all handlers for a time, and then go back to the earlier named bypasses, call `bypassAll()` and then `clearGlobalBypass()`. The named bypasses stay during the global bypass, so you do not have to store them:

```apex
Boolean wasGlobalBypassed = TriggerHandler.isGlobalBypassed();
TriggerHandler.bypassAll();

/* update the records here */

if (!wasGlobalBypassed) {
  TriggerHandler.clearGlobalBypass();
}
```

The check of `isGlobalBypassed()` keeps a global bypass that was on before.

### Max Loop Count

To limit recursion, set a maximum loop count for a handler. Each trigger operation has its own count:

- `setMaxLoopCount(max)` sets the same limit for each operation.
- `setMaxLoopCount(System.TriggerOperation.AFTER_UPDATE, max)` sets the limit of 1 operation.
- A maximum of 0 or a negative value means no limit.

A DML statement on more than 200 records runs the trigger once for each chunk of 200 records. Each chunk uses 1 run of its operation. A bypassed run does not count. A run that the limit stops counts. When the count of an operation passes its maximum, `run()` sends a warning to `log()` and returns. By default, `log()` writes it to the debug log. It does not call the context method or `andFinally()`.

This handler runs its update logic once for an update of up to 200 records. The update in `afterUpdate()` fires the trigger again, and the handler skips those runs.

```apex
public inherited sharing class OpportunityTriggerHandler extends TriggerHandler {
  private Map<Id, Opportunity> newRecordsMap;

  public OpportunityTriggerHandler() {
    super(OpportunityTriggerHandler.class);
    this.newRecordsMap = (Map<Id, Opportunity>) Trigger.newMap;
    this.setMaxLoopCount(1); /* 1 run of each trigger operation */
  }

  public override void afterUpdate() {
    List<Opportunity> opps = [SELECT Id FROM Opportunity WHERE Id IN :newRecordsMap.keySet() WITH SYSTEM_MODE];
    Database.update(opps, AccessLevel.SYSTEM_MODE);
  }
}
```

`clearMaxLoopCount()` removes the limit of all operations, and the counts continue. `TriggerHandler.getLoopCount('OpportunityTriggerHandler', System.TriggerOperation.AFTER_UPDATE)` returns the current count of 1 operation. The count is -1 for an operation with no call of `setMaxLoopCount()`, because the framework does not count its runs. After a call with 0 or a negative value, the framework counts the runs but does not stop any.

You can also set the limit in the trigger, before `run()`:

```apex
trigger OpportunityTrigger on Opportunity(before insert, before update, before delete, after insert, after update, after delete, after undelete) {
  new OpportunityTriggerHandler().setMaxLoopCount(5).run();
}
```

### Debug Statements

The framework can write 2 kinds of lines:

- The limits line shows the Apex query and DML limits after a handler runs.
- The debug lines show the entry and exit of each handler in the debug log. Use them only when necessary, because they make the org slower.

`TriggerHandler.showLimits()` and `TriggerHandler.showDebug()` make all handlers that run later in the transaction write these lines. Call them in the _trigger_:

```apex
TriggerHandler.showLimits();
TriggerHandler.showDebug();
new AccountSampleTriggerHandler().run();
TriggerHandler.showLimits(false);
TriggerHandler.showDebug(false);
```

Or call them in your _trigger handler_, before and after a DML statement:

```apex
TriggerHandler.showLimits();
TriggerHandler.showDebug();

Database.update(leadsList, AccessLevel.SYSTEM_MODE);

TriggerHandler.showLimits(false);
TriggerHandler.showDebug(false);
```

For 1 handler only, chain `showHandlerLimits()` and `showHandlerDebug()` in your trigger:

```apex
trigger OpportunityTrigger on Opportunity(before insert, before update, before delete, after insert, after update, after delete, after undelete) {
  new OpportunityTriggerHandler().showHandlerDebug().showHandlerLimits().run();
}
```

The older chainable `debug()` and `limits()` are deprecated, because they act for all handlers, not only for the handler that you chain them on. The setting of a handler wins over the setting for all handlers. So `showHandlerDebug(false)` stops the debug lines for 1 handler while `TriggerHandler.showDebug()` keeps them for the other handlers. `showHandlerDebug(null)` makes the handler use the setting for all handlers again.

```apex
trigger OpportunityTrigger on Opportunity(before insert, before update, before delete, after insert, after update, after delete, after undelete) {
  new OpportunityTriggerHandler().showHandlerDebug(false).showHandlerLimits(false).run();
}
```

### Send the Messages to Your Logging Framework

The framework writes all its messages through 1 protected method, `log(LoggingLevel level, String message)`. The messages are the entry, exit, and limits lines, and the loop limit warning. By default, `log()` writes to the debug log. To send the messages to the logging framework of your org, override it in a handler:

```apex
public inherited sharing class OpportunityTriggerHandler extends TriggerHandler {
  protected override void log(LoggingLevel level, String message) {
    /* send the message to your logging framework here */
    super.log(level, message);
  }
}
```

#### Example: Nebula Logger

With [Nebula Logger](https://github.com/jongpie/NebulaLogger) installed, this handler sends each framework message to Nebula Logger. A tag shows where the message came from:

```apex
public inherited sharing class OpportunityTriggerHandler extends TriggerHandler {
  protected override void log(LoggingLevel level, String message) {
    Logger.newEntry(level, message).addTag('TriggerHandler');
    if (level == LoggingLevel.WARN) {
      Logger.saveLog();
    }
  }
}
```

Nebula Logger keeps the entries in memory until `Logger.saveLog()` runs. The next `Logger.saveLog()` call in the transaction saves the `DEBUG` entries, for example at the end of your own code. The loop limit warning comes when `run()` stops early, and `andFinally()` does not run then. So the example saves each `WARN` entry at once. Each `Logger.saveLog()` call publishes a platform event, so do not save each `DEBUG` entry at once. With the managed package of Nebula Logger, write `Nebula.Logger` instead of `Logger`.

### Universal Action

`andFinally()` holds the actions that must run in all trigger contexts, after all other actions. Credit to James Simone for this idea. In his words, it "runs after every context - can be used to easily implement something like apex-rollup!" ([The Joys of Apex](https://www.jamessimone.net/blog/joys-of-apex/lightweight-trigger-handler/))

`andFinally()` runs after the context method returns, in all trigger contexts, also in a context that the handler does not override. It also runs when the context method catches its own exception or calls `addError()`, which is not an exception.

It does not run in these cases:

- The handler is bypassed by name or by type, or all handlers are bypassed. Then nothing in the handler runs.
- The loop limit of the trigger operation stops the run. Then only `log()` runs, with the loop limit warning.
- The context method throws an exception that it does not catch. The exception reaches the caller and stops all processing.

After a run of the handler starts its context method, a bypass cannot stop the `andFinally()` of that run. For example, the `afterUpdate()` method of an Account handler bypasses the Account handler, updates other Accounts, and clears the bypass:

1. The first update of an Account starts the first run of the handler, which calls `afterUpdate()`.
2. `afterUpdate()` bypasses the Account handler and updates the other Accounts. That update starts a second run of the handler, which is bypassed: its `afterUpdate()` and its `andFinally()` do not run.
3. `afterUpdate()` clears the bypass and returns. The first run then calls its `andFinally()`, which is the last step of the first update.

If `andFinally()` throws, the exception reaches the caller, and the handler does not write the exit and limits lines.

## Test a Handler Without DML

A test can run a handler without an insert. `setTestContext(System.TriggerOperation operation)` makes the handler run as if a trigger fired the operation. It returns the handler, so that `run()` can follow. Give the handler its records first, for example through a `@TestVisible` field:

```apex
public inherited sharing class OpportunityTriggerHandler extends TriggerHandler {
  @TestVisible
  private List<Opportunity> newRecords;

  public OpportunityTriggerHandler() {
    super(OpportunityTriggerHandler.class);
    this.newRecords = (List<Opportunity>) Trigger.new;
  }

  public override void beforeInsert() {
    for (Opportunity opp : newRecords) {
      opp.StageName = 'Prospecting';
    }
  }
}
```

```apex
@IsTest
private inherited sharing class OpportunityTriggerHandlerTest {
  @IsTest
  private static void beforeInsertSetsStage() {
    Opportunity opp = new Opportunity(Name = 'Test');
    OpportunityTriggerHandler handler = new OpportunityTriggerHandler();
    handler.newRecords = new List<Opportunity>{ opp };
    handler.setTestContext(System.TriggerOperation.BEFORE_INSERT).run();
    Assert.areEqual('Prospecting', opp.StageName, 'before insert did not set the stage');
  }
}
```

Outside a test, `setTestContext()` changes nothing: the handler keeps the context of the real trigger. A test that needs the full trigger, the sharing, or the database must still insert records.

## Overridable Methods

A handler can override these methods. All trigger contexts are supported.

- `beforeInsert()`
- `beforeUpdate()`
- `beforeDelete()`
- `afterInsert()`
- `afterUpdate()`
- `afterDelete()`
- `afterUndelete()`
- `andFinally()`
- `log(LoggingLevel level, String message)`, to send the framework messages to your logging framework

A handler can also call 3 protected methods:

- `getTriggerEvent()` returns the current `System.TriggerOperation`.
- `getHandlerName()` returns the name of the handler.
- `setTestContext(System.TriggerOperation operation)` lets a test run the handler without DML.

## Upgrade From Version 1

Version 2.0 has breaking changes. Before you upgrade, check your handlers, your triggers, and your tests for the items below.

The classes now use API version 67.0, not 58.0. The target org must support API version 67.0.

### Changes for Handlers and Triggers

- **The String constructor is removed.** Replace the name in quotes with the class:

  ```apex
  // before 2.0
  super('OpportunityTriggerHandler');
  // 2.0 and later
  super(OpportunityTriggerHandler.class);
  ```

  Maybe you passed a name that is not the class name, for example a short name. Then a bypass or a loop count with that name no longer matches. Change each bypass call to use the class, for example `TriggerHandler.bypass(OpportunityTriggerHandler.class)`. Pass `OpportunityTriggerHandler.class.getName()` to `getLoopCount()`.

- **`TriggerHandler` is abstract.** `new TriggerHandler()` does not compile. Create a class that extends it.
- **The named bypasses and the global bypass are independent.** `setBypass(name, false)` no longer clears the global bypass. `bypassAll()` no longer clears the named bypasses. To clear all bypasses, call `clearAllBypasses()`.
- **`isBypassed()` tells only about the named bypass.** Under a global bypass alone, it returns `false`. To find if a handler runs, call `isSkipped()`. For the global bypass, call `isGlobalBypassed()`.
- **The list of bypasses has no `BypassAll` entry.** `bypassList()` and `bypassSet()` return only the named bypasses. For the global bypass, call `isGlobalBypassed()`.
- **The loop limit applies to each trigger operation.** A handler that called `setMaxLoopCount(2)` for 1 run of before update and after update together must call `setMaxLoopCount(1)`.
- **`getLoopCount()` returns -1 for a handler or an operation with no limit,** not 0.
- **`setMaxLoopCount(0)` means no limit.** Before 2.0, a maximum of 0 stopped all runs. To stop a handler, bypass it.

### Changes for Tests

- These test-visible members are removed or renamed. A test that used them does not compile:
  - `showDebug` and `showLimits` are now `doShowDebug` and `doShowLimits`.
  - `loopCountMap`, `bypassedHandlers`, `globalBypass`, and `BYPASS_ALL_ALIAS` are removed. Use `getLoopCount()`, `bypassList()`, and `isGlobalBypassed()`.
  - The no-arg `LoopCounter()` constructor is removed. Give the counter a maximum.
- `setTriggerContext(System.TriggerOperation, Boolean)` is removed, and `setTriggerContext()` and `validateRun()` are no longer test-visible. To set a trigger context in a test, call `setTestContext(operation)`.
- The context methods and `andFinally()` are no longer test-visible. Run the handler with `setTestContext()` and `run()`, or call the public override of the handler.

### Deprecated Members

These members still work. A later major release removes them.

| Deprecated                            | Use instead                                                             |
| ------------------------------------- | ----------------------------------------------------------------------- |
| `bypassSet()`                         | `bypassList()`                                                          |
| `getLoopCount(String handlerName)`    | `getLoopCount(String handlerName, System.TriggerOperation operation)`   |
| `debug()`, `debug(Boolean enabled)`   | `showHandlerDebug()` for 1 handler, or `showDebug()` for all handlers   |
| `limits()`, `limits(Boolean enabled)` | `showHandlerLimits()` for 1 handler, or `showLimits()` for all handlers |

## API Reference

This table lists all public members of `TriggerHandler`. The [class documentation](https://davidschach.com/salesforce-trigger-framework/TriggerHandler.html) has the full details and examples.

| Member                                                                       | What it does                                                                                                                                                                                      |
| ---------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `TriggerHandler()`                                                           | Constructor. The framework finds the handler name from the running class when it first needs it.                                                                                                  |
| `protected TriggerHandler(Type handlerType)`                                 | Constructor for a subclass, with the handler type. The handler name is `Type.getName()`, which matches `bypass(Type)`. The framework does no name lookup.                                         |
| `run()`                                                                      | Call it from the trigger. Runs the context method of the current operation, then `andFinally()`.                                                                                                  |
| `setMaxLoopCount(Integer max)`                                               | Limits how many times this handler runs, with the same limit for each trigger operation. 0 or a negative value removes the limit. Returns the handler, so you can chain calls.                    |
| `setMaxLoopCount(System.TriggerOperation operation, Integer max)`            | Limits how many times this handler runs for 1 trigger operation. 0 or a negative value removes the limit. Returns the handler, so you can chain calls.                                            |
| `clearMaxLoopCount()`                                                        | Removes the limit of all trigger operations of this handler. The counts continue.                                                                                                                 |
| `static getLoopCount(String handlerName)`                                    | Deprecated: use the form with the operation. Returns the total count of all operations of a handler, or -1 when `setMaxLoopCount()` was never called for it. A later major release removes it.    |
| `static getLoopCount(String handlerName, System.TriggerOperation operation)` | Returns the count of 1 trigger operation of a handler, or -1 when `setMaxLoopCount()` was never called for it.                                                                                    |
| `static bypass(String handlerName)`                                          | Bypasses a handler by name. The name matches in any case.                                                                                                                                         |
| `static bypass(Type handlerType)`                                            | Bypasses a handler by type, for example `bypass(AccountTriggerHandler.class)`.                                                                                                                    |
| `static bypass(List<String> handlerNames)`                                   | Bypasses a list of handlers by name.                                                                                                                                                              |
| `static bypassAll()`                                                         | Bypasses all handlers. The named bypasses stay.                                                                                                                                                   |
| `static clearBypass(String handlerName)`                                     | Clears the bypass of a handler by name.                                                                                                                                                           |
| `static clearBypass(Type handlerType)`                                       | Clears the bypass of a handler by type.                                                                                                                                                           |
| `static clearBypass(List<String> handlerNames)`                              | Clears the bypass of a list of handlers by name.                                                                                                                                                  |
| `static isBypassed(String handlerName)`                                      | Returns `true` when the handler is bypassed by name or by type. The result does not include the global bypass.                                                                                    |
| `static isBypassed(Type handlerType)`                                        | The same check, by type.                                                                                                                                                                          |
| `static isGlobalBypassed()`                                                  | Returns `true` when all handlers are bypassed.                                                                                                                                                    |
| `static isSkipped(String handlerName)`                                       | Returns `true` when the handler does not run: it is bypassed by name or by type, or all handlers are bypassed.                                                                                    |
| `static isSkipped(Type handlerType)`                                         | The same check, by type.                                                                                                                                                                          |
| `static bypassList()`                                                        | Returns a sorted list of the handlers that are bypassed by name or by type.                                                                                                                       |
| `static bypassSet()`                                                         | Deprecated: use `bypassList()`. Returns a set of the handlers that are bypassed by name or by type. A later major release removes it.                                                             |
| `static setBypass(String handlerName, Boolean desiredValue)`                 | Bypasses the handler for `true`. For `false`, clears only its named bypass.                                                                                                                       |
| `static setBypass(Type handlerType, Boolean desiredValue)`                   | The same, by type.                                                                                                                                                                                |
| `static clearAllBypasses()`                                                  | Clears the global bypass and all named bypasses.                                                                                                                                                  |
| `static clearGlobalBypass()`                                                 | Clears only the global bypass.                                                                                                                                                                    |
| `static clearBypassList()`                                                   | Clears only the named bypasses.                                                                                                                                                                   |
| `limits()`, `limits(Boolean enabled)`                                        | Deprecated: use `showHandlerLimits()` or `showLimits()`. Sets whether all handlers write the limits line. Returns the handler, so you can chain calls. A later major release removes them.        |
| `static showLimits()`, `static showLimits(Boolean enabled)`                  | Sets whether all handlers that run later in the transaction write the limits line.                                                                                                                |
| `showHandlerLimits()`, `showHandlerLimits(Boolean enabled)`                  | Sets whether this handler writes the limits line. With null, the handler uses the setting for all handlers. Returns the handler, so you can chain calls.                                          |
| `debug()`, `debug(Boolean enabled)`                                          | Deprecated: use `showHandlerDebug()` or `showDebug()`. Sets whether all handlers write the entry and exit lines. Returns the handler, so you can chain calls. A later major release removes them. |
| `static showDebug()`, `static showDebug(Boolean enabled)`                    | Sets whether all handlers that run later in the transaction write the entry and exit lines.                                                                                                       |
| `showHandlerDebug()`, `showHandlerDebug(Boolean enabled)`                    | Sets whether this handler writes the entry and exit lines. With null, the handler uses the setting for all handlers. Returns the handler, so you can chain calls.                                 |
| `TriggerHandler.TriggerHandlerException`                                     | The framework throws it when `run()` is called outside a trigger, and when a bypass or loop count method gets a null or blank argument.                                                           |

## Contributing

[CONTRIBUTING.md](https://github.com/dschach/salesforce-trigger-framework/blob/main/CONTRIBUTING.md) tells how to set up the project, test a change, and open a pull request. Each contributor follows the [Code of Conduct](https://github.com/dschach/salesforce-trigger-framework/blob/main/CODE_OF_CONDUCT.md).

## License

The framework uses the BSD 3-Clause license in [LICENSE](https://github.com/dschach/salesforce-trigger-framework/blob/main/LICENSE). [NOTICE](https://github.com/dschach/salesforce-trigger-framework/blob/main/NOTICE) holds the MIT license notice of the original code by Kevin O'Hara.
