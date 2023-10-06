/**
 * @description Sample trigger showing simple implementation of trigger handler.
 * <br/>Note that the handler class is specified in the handler, though it could be specified here
 *
 * @group SampleTriggerHandler
 */
trigger AccountSampleTrigger on Account(before insert, after insert, before update, after update, before delete, after delete, after undelete) {
	TriggerHandler.showLimits();
	new AccountSampleTriggerHandler('AccountSampleTriggerHandler').debug(true).run();
}