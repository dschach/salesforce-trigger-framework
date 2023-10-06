/**
 * @description Metadata-driven Trigger Handler that builds on TriggerHandler, allowing both to exist together
 *
 * @author      David Schach
 * @since       2023
 */
public with sharing virtual class MetadataTriggerHandler extends TriggerHandler {
	/**
	 * @description Exception class
	 */
	public class MetadataTriggerHandlerException extends Exception {
	}
}