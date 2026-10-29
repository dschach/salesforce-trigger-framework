/**
 * @description Sample trigger for the sample handler. It has no logic: it creates the handler and calls `run()`.
 * <br>It lists only the contexts that the handler overrides, so the trigger does not fire in a context where the handler has nothing to do.
 *
 * @group SampleTriggerHandler
 */
trigger AccountSampleTrigger on Account(before insert, before update, after update) {
	new AccountSampleTriggerHandler().run();
}