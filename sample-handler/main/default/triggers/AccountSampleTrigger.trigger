/**
 * @description Sample trigger for the sample handler. It has no logic: it creates the handler and calls `run()`.
 * <br>It lists all 7 contexts, so it is written once and never edited again: a new override in the handler runs without a change to the trigger.
 * <br>A context that the handler does not override costs little: `run()` calls the empty base method and then `andFinally()`.
 *
 * @group SampleTriggerHandler
 */
trigger AccountSampleTrigger on Account(before insert, before update, before delete, after insert, after update, after delete, after undelete) {
	new AccountSampleTriggerHandler().run();
}