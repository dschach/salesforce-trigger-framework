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
  - [Data access](#data-access)
- [Cool Stuff](#cool-stuff)
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
- [API Reference](#api-reference)

<!-- END doctoc -->

## Credit

Based on Kevin O'Hara's famous framework [sfdc-trigger-framework](https://github.com/kevinohara80/sfdc-trigger-framework). Its MIT license notice is in [NOTICE](NOTICE).

## Documentation

[Class Documentation](https://davidschach.com/salesforce-trigger-framework/TriggerHandler.html)

### Changelog

[Complete Changelog](CHANGELOG.md)

## Overview

(from Kevin O'Hara)

Triggers should (IMO) be logicless. Putting logic into your triggers creates un-testable, difficult-to-maintain code. It's widely accepted that a best-practice is to move trigger logic into a handler class.

This trigger framework bundles a single **TriggerHandler** base class that you can inherit from in all of your trigger handlers. The base class includes context-specific methods that are automatically called when a trigger is executed.

The base class also provides a secondary role as a supervisor for Trigger execution. It acts like a watchdog, monitoring trigger activity and providing an api for controlling certain aspects of execution and control flow.

But the most important part of this framework is that it's minimal and simple to use.

**Deploy to a scratch org:**
[Deploy instructions](./DEPLOY.md)

**Deploy to a Salesforce org:**
[![Deploy](https://raw.githubusercontent.com/afawcett/githubsfdeploy/master/deploy.png)](https://githubsfdeploy.herokuapp.com/?owner=dschach&repo=salesforce-trigger-framework)

## Usage

### Trigger Handler

To create a trigger handler, create a class that extends [TriggerHandler.cls](https://github.com/dschach/salesforce-trigger-framework/blob/main/force-app/main/default/classes/TriggerHandler.cls). Here is the declaration of an Opportunity trigger handler.

```apex
public inherited sharing class OpportunityTriggerHandler extends TriggerHandler {
}
```

To add logic to a trigger context, override that context's method in your trigger handler. Here is how we would add logic to a `beforeUpdate, afterUpdate` trigger.

**Note:** When referencing the Trigger static maps within a class, SObjects are returned versus SObject subclasses like Opportunity, Account, etc. This means that you must cast when you reference them in your trigger handler. You could do this in your constructor if you wanted. Technically, you only need to cast for oldMap and newMap, but for completeness, I encourage casting Trigger.new and Trigger.old as well.

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

Passing the class to `super()` is optional, and it makes the handler faster. Without it, the framework works out the name from the running class the first time a bypass or a loop count needs it, and that lookup serializes every field of the handler, including the record lists. With the class, the handler name is `Type.getName()`, so `TriggerHandler.bypass(OpportunityTriggerHandler.class)` always matches. A handler that is an inner class must pass its class, because the lookup gives only the short name of an inner class. [Pass the Handler Class to super()](#pass-the-handler-class-to-super) has more examples.

A sample [AccountSampleTriggerHandler](https://github.com/dschach/salesforce-trigger-framework/tree/main/sample-handler/main/default/classes) class has been included in this repository, as well as a sample [trigger](https://github.com/dschach/salesforce-trigger-framework/blob/main/sample-handler/main/default/triggers/AccountSampleTrigger.trigger). The sample is not a package directory, so the Deploy to Salesforce button and `sf project deploy start` install only the framework. To try the sample in a scratch org, run `sf project deploy start --source-dir sample-handler`. The [sample README](sample-handler/README.md) describes what it shows.

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

Call `super()` first, and then cast the trigger collections that the handler uses.

For a handler that is an inner class, write the outer class name, a dot, and the inner class name. The handler name is then `SalesHandlers.OpportunityTriggerHandler`, and `TriggerHandler.bypass(SalesHandlers.OpportunityTriggerHandler.class)` matches it. An inner-class handler must pass its class, because without it the framework finds only the short name, `OpportunityTriggerHandler`.

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

To see the name that the framework uses, call `getHandlerName()` in the handler, or `OpportunityTriggerHandler.class.getName()` anywhere.

#### Upgrade From the String Constructor

Version 2.0 removes the constructor that takes the handler name as a String. Replace the name in quotes with the class:

```apex
// before 2.0
super('OpportunityTriggerHandler');
// 2.0 and later
super(OpportunityTriggerHandler.class);
```

If you passed a name that is not the class name, for example a short name, a bypass or a loop count that uses that name no longer matches. Change each bypass call to use the class, for example `TriggerHandler.bypass(OpportunityTriggerHandler.class)`, and pass `OpportunityTriggerHandler.class.getName()` to `getLoopCount()`.

### Trigger

To use the trigger handler, you only need to construct an instance of your trigger handler within the trigger itself and call the `run()` method. Here is an example of an Opportunity trigger.

This is the way to write a trigger that will run the trigger handler above. List all 7 contexts, even the ones the handler does not override yet. Then you write the trigger once and never edit it again: a new override in the handler runs without a change to the trigger. A context that the handler does not override costs little, because `run()` calls the empty base method and then `andFinally()`. Some objects do not support every context, for example an object that cannot be undeleted. For such an object, leave out the contexts that it does not support.

```apex
trigger OpportunityTrigger on Opportunity(before insert, before update, before delete, after insert, after update, after delete, after undelete) {
  new OpportunityTriggerHandler().run();
}
```

### Data access

A trigger runs without sharing, so a handler declared `inherited sharing` runs without sharing too. A handler often must read or change records that the running user cannot see or edit, such as related records. So the examples here name `SYSTEM_MODE` on every query and DML statement: `WITH SYSTEM_MODE` in SOQL, and `AccessLevel.SYSTEM_MODE` in `Database` methods. System mode ignores the user's object and field permissions, and the sharing of the class decides record access.

If a handler must respect the running user's object, field, and record permissions, use `WITH USER_MODE` and `AccessLevel.USER_MODE` instead.

## Cool Stuff

### Bypass API

What if you want to tell other trigger handlers to halt execution? That's easy with the bypass api:

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
    Database.update(acc, AccessLevel.SYSTEM_MODE); /* won't invoke the AccountTriggerHandler */

    TriggerHandler.clearBypass('AccountTriggerHandler');

    acc.Name = 'With Trigger';
    Database.update(acc, AccessLevel.SYSTEM_MODE); /* will invoke the AccountTriggerHandler */
  }
}
```

Bypass names match regardless of case. You can also bypass by type, as in `TriggerHandler.bypass(AccountTriggerHandler.class)`, so the compiler checks the name. A null or blank name, a null type, or a null list throws `TriggerHandler.TriggerHandlerException`.

### Check Bypass Status

A handler can be bypassed by name, or all handlers can be bypassed together. 3 methods tell you which:

- `isBypassed(name)` or `isBypassed(type)` is `true` when the handler is bypassed by name or by type. It does not include the global bypass.
- `isGlobalBypassed()` is `true` when all handlers are bypassed.
- `isSkipped(name)` or `isSkipped(type)` is `true` when either of them is true, so the handler will not run.

```apex
if (TriggerHandler.isSkipped(AccountTriggerHandler.class)) {
  /* ... do something if the Account trigger handler will not run! */
}
```

### Global Bypass

To bypass all handlers, use the `bypassAll` method:

```apex
TriggerHandler.bypassAll();
```

The named bypasses stay, so `clearGlobalBypass()` brings them back. `bypassList()` returns only the named bypasses. To check the global bypass, call `isGlobalBypassed()`.

To clear all bypasses for the transaction, simply use the `clearAllBypasses` method, as in:

```apex
/* ... done with bypasses! */

TriggerHandler.clearAllBypasses();

/* ... now handlers won't be ignored! */
```

This clears the list of bypassed handlers and the global bypass. To clear only one of them, use `clearBypassList()` or `clearGlobalBypass()`.

### Set Bypass

If you are not sure in a transaction if a handler is bypassed, but want to bypass it (or clear the bypass) and then set it to its original value, use the `setBypass` method:

```apex
Boolean isBypassed = TriggerHandler.isBypassed('AccountTriggerHandler');
TriggerHandler.bypass('AccountTriggerHandler');

/* do something here */

TriggerHandler.setBypass('AccountTriggerHandler', isBypassed);
```

`setBypass(name, false)` clears only the named bypass, and `isBypassed()` answers only the named bypass. So this idiom gives back exactly the state before it. A global bypass stays on through it.

To bypass all handlers for a while, and then go back to the handlers that were bypassed by name before, call `bypassAll()` and then `clearGlobalBypass()`. The named bypasses stay during the global bypass, so you do not need to store them:

```apex
Boolean wasGlobalBypassed = TriggerHandler.isGlobalBypassed();
TriggerHandler.bypassAll();

/* do something here */

if (!wasGlobalBypassed) {
  TriggerHandler.clearGlobalBypass();
}
```

The check of `isGlobalBypassed()` keeps a global bypass that was on before.

### Max Loop Count

To limit recursion, you can set a maximum loop count for a trigger handler. The count is kept per handler name, and every trigger context the handler runs in uses 1 count, so a trigger on `before update` and `after update` uses 2 counts for 1 update. A DML statement on more than 200 records runs the trigger once for each chunk of 200 records, and each chunk uses counts too. When the count passes the maximum, `run()` writes a warning to the debug log and returns without calling the context method or `andFinally()`.

This handler runs its update logic once for an update of up to 200 records. The update inside `afterUpdate()` fires the trigger again, and those runs are skipped.

```apex
public inherited sharing class OpportunityTriggerHandler extends TriggerHandler {
  private Map<Id, Opportunity> newRecordsMap;

  public OpportunityTriggerHandler() {
    super(OpportunityTriggerHandler.class);
    this.newRecordsMap = (Map<Id, Opportunity>) Trigger.newMap;
    this.setMaxLoopCount(2); /* 1 count for before update, 1 for after update */
  }

  public override void afterUpdate() {
    List<Opportunity> opps = [SELECT Id FROM Opportunity WHERE Id IN :newRecordsMap.keySet() WITH SYSTEM_MODE];
    Database.update(opps, AccessLevel.SYSTEM_MODE);
  }
}
```

`clearMaxLoopCount()` removes the limit, and `TriggerHandler.getLoopCount('OpportunityTriggerHandler')` returns the current count. The count is 0 for a handler that never set a maximum.

In version 1.2, the ability to chain methods was added. Now, you can set the max loop count in a single line in your trigger:

```apex
trigger OpportunityTrigger on Opportunity(before insert, before update, before delete, after insert, after update, after delete, after undelete) {
  new OpportunityTriggerHandler().setMaxLoopCount(5).run();
}
```

### Debug Statements

There are two methods that will show additional information.

`TriggerHandler.showLimits()` will debug Apex query and DML limits when the trigger handler has completed.

`TriggerHandler.showDebug()` will show trigger entry and exit in debug logs. Use sparingly, as it will decrease org performance.

Both flags are static, so they apply to every handler that runs later in the transaction. To use one or both of these, either add them to the _trigger_

```apex
TriggerHandler.showLimits();
TriggerHandler.showDebug();
new AccountSampleTriggerHandler().run();
TriggerHandler.showLimits(false);
TriggerHandler.showDebug(false);
```

or put them in your Apex _trigger handler_ code before and after DML statements.

```apex
TriggerHandler.showLimits();
TriggerHandler.showDebug();

Database.update(leadsList, AccessLevel.SYSTEM_MODE);

TriggerHandler.showLimits(false);
TriggerHandler.showDebug(false);
```

In version 1.2, the ability to chain methods _in triggers_ was added. Now, you can specify showing debug messages and limits in a single line in your trigger:

```apex
trigger OpportunityTrigger on Opportunity(before insert, before update, before delete, after insert, after update, after delete, after undelete) {
  new OpportunityTriggerHandler().debug().limits().run(); // debug() is the same as debug(true)
}
```

Or stop showing them.

```apex
trigger OpportunityTrigger on Opportunity(before insert, before update, before delete, after insert, after update, after delete, after undelete) {
  new OpportunityTriggerHandler().debug(false).limits(false).run();
}
```

### Send the Messages to Your Logging Framework

The framework writes every message, the entry, exit, and limits lines and the loop limit warning, through 1 protected method, `log(LoggingLevel level, String message)`. By default it writes to the debug log. Override it in a handler to send the messages to the logging framework of your org:

```apex
public inherited sharing class OpportunityTriggerHandler extends TriggerHandler {
  protected override void log(LoggingLevel level, String message) {
    /* send the message to your logging framework here */
    super.log(level, message);
  }
}
```

#### Example: Nebula Logger

With [Nebula Logger](https://github.com/jongpie/NebulaLogger) installed, this handler sends every framework message to Nebula Logger, with a tag that shows where the message came from:

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

Nebula Logger keeps entries in memory until `Logger.saveLog()` runs. The `DEBUG` entries are saved by the next `Logger.saveLog()` call in the transaction, for example at the end of your own code. The loop limit warning comes when `run()` stops early, and `andFinally()` does not run then, so the example saves each `WARN` entry at once. Each `Logger.saveLog()` call publishes a platform event, so do not save every `DEBUG` entry at once. With the managed package of Nebula Logger, write `Nebula.Logger` instead of `Logger`.

### Universal Action

Version 1.1 added a new method/context: `andFinally()` can contain actions that should happen in every trigger context, after all other actions. It does not run when the handler is bypassed, when the loop limit is exceeded, or when the context method throws an exception. Credit to James Simone for this idea. As he writes, "runs after every context - can be used to easily implement something like apex-rollup!" ([The Joys of Apex](https://www.jamessimone.net/blog/joys-of-apex/lightweight-trigger-handler/))

## Test a Handler Without DML

A test can run a handler without inserting records. `setTestContext(System.TriggerOperation operation)` makes the handler run as if a trigger fired the operation, and it returns the handler, so that `run()` can follow. Give the handler its records first, for example through a `@TestVisible` field:

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

Outside a test, `setTestContext()` changes nothing: the handler keeps the context of the real trigger. A test that needs the whole trigger, the sharing, or the database still inserts records.

## Overridable Methods

Here are all of the methods that you can override. All of the context possibilities are supported.

- `beforeInsert()`
- `beforeUpdate()`
- `beforeDelete()`
- `afterInsert()`
- `afterUpdate()`
- `afterDelete()`
- `afterUndelete()`
- `andFinally()`
- `log(LoggingLevel level, String message)`, to send the framework's messages to your logging framework

A handler can also call 3 protected methods: `getTriggerEvent()` returns the current `System.TriggerOperation`, `getHandlerName()` returns the handler's name, and a test can call `setTestContext(System.TriggerOperation operation)` to run the handler without DML.

## API Reference

Every public member of `TriggerHandler`. The [class documentation](https://davidschach.com/salesforce-trigger-framework/TriggerHandler.html) has the full details and examples.

| Member                                                       | What it does                                                                                                                                             |
| ------------------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `TriggerHandler()`                                           | Constructor. The handler name is worked out from the running class when it is first needed.                                                              |
| `protected TriggerHandler(Type handlerType)`                 | Constructor for a subclass, with the handler type. The handler name is `Type.getName()`, which matches `bypass(Type)` and skips the runtime name lookup. |
| `run()`                                                      | Called from the trigger. Runs the context method for the current operation, then `andFinally()`.                                                         |
| `setMaxLoopCount(Integer max)`                               | Limits how many times this handler runs. 0 means the handler never runs, and a negative value removes the limit. Returns the handler, for chaining.      |
| `clearMaxLoopCount()`                                        | Removes the limit on how many times this handler runs.                                                                                                   |
| `static getLoopCount(String handlerName)`                    | Returns the loop count of a handler, or 0 when no maximum was set for it.                                                                                |
| `static bypass(String handlerName)`                          | Bypasses a handler by name. The name matches regardless of case.                                                                                         |
| `static bypass(Type handlerType)`                            | Bypasses a handler by type, for example `bypass(AccountTriggerHandler.class)`.                                                                           |
| `static bypass(List<String> handlerNames)`                   | Bypasses a list of handlers by name.                                                                                                                     |
| `static bypassAll()`                                         | Bypasses every handler. The named bypasses stay.                                                                                                         |
| `static clearBypass(String handlerName)`                     | Clears the bypass of a handler by name.                                                                                                                  |
| `static clearBypass(Type handlerType)`                       | Clears the bypass of a handler by type.                                                                                                                  |
| `static clearBypass(List<String> handlerNames)`              | Clears the bypass of a list of handlers by name.                                                                                                         |
| `static isBypassed(String handlerName)`                      | Returns `true` when the handler is bypassed by name or type. The global bypass is not part of the answer.                                                |
| `static isBypassed(Type handlerType)`                        | The same check, by type.                                                                                                                                 |
| `static isGlobalBypassed()`                                  | Returns `true` when all handlers are bypassed.                                                                                                           |
| `static isSkipped(String handlerName)`                       | Returns `true` when the handler will not run: it is bypassed by name or type, or all handlers are bypassed.                                              |
| `static isSkipped(Type handlerType)`                         | The same check, by type.                                                                                                                                 |
| `static bypassList()`                                        | Returns a sorted list of the handlers that are bypassed by name or type.                                                                                 |
| `static bypassSet()`                                         | Deprecated: use `bypassList()`. Returns a set of the handlers that are bypassed by name or type. A later major release removes it.                       |
| `static setBypass(String handlerName, Boolean desiredValue)` | Bypasses the handler for `true`. For `false`, clears only its named bypass.                                                                              |
| `static clearAllBypasses()`                                  | Clears the global bypass and the list of named bypasses.                                                                                                 |
| `static clearGlobalBypass()`                                 | Clears only the global bypass.                                                                                                                           |
| `static clearBypassList()`                                   | Clears only the list of named bypasses.                                                                                                                  |
| `limits()`, `limits(Boolean enabled)`                        | Turns the limits debug output on, or on and off. Returns the handler, for chaining.                                                                      |
| `static showLimits()`, `static showLimits(Boolean enabled)`  | The same, without chaining.                                                                                                                              |
| `debug()`, `debug(Boolean enabled)`                          | Turns the entry and exit debug output on, or on and off. Returns the handler, for chaining.                                                              |
| `static showDebug()`, `static showDebug(Boolean enabled)`    | The same, without chaining.                                                                                                                              |
| `TriggerHandler.TriggerHandlerException`                     | Thrown when `run()` is called outside a trigger, and when a bypass or loop count method gets a null or blank argument.                                   |
