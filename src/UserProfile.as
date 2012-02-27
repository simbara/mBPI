/** Functions to handle the user profile
 * information
 */

import flash.events.Event;

import mx.managers.PopUpManager;

import spark.components.TextInput;
import spark.components.TitleWindow;


private var _stat:String;

public var currID:String;
public var userInfoPopUp:UserInfo;



/* Launch pop up window to query for unique ID */
private function launchPopUp():void
{
	userInfoPopUp = UserInfo(PopUpManager.createPopUp(this, UserInfo, true));
	userInfoPopUp.addEventListener(Event.REMOVED_FROM_STAGE, init);
}

/* Position pop up window */
private function positionPopUp():void
{
	PopUpManager.centerPopUp(this);
}

/* Get the ID & continue to application */
private function getUserInfo():void 
{
	//save id in global var
	currID = idField.text; 
	_stat = "Getting User ID " + currID + "......."; trace(_stat);
	PopUpManager.removePopUp(this); 
	_stat = "Pop up closed ..."; trace(_stat);
}
