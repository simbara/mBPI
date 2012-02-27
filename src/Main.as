import flash.data.SQLConnection;
import flash.data.SQLResult;
import flash.data.SQLStatement;
import flash.display.Sprite;
import flash.events.Event;
import flash.events.TouchEvent;
import flash.filesystem.File;
import flash.filters.BitmapFilterQuality;
import flash.filters.BitmapFilterType;
import flash.filters.GradientGlowFilter;
import flash.geom.*;
import flash.text.TextFormat;
import flash.ui.Multitouch;
import flash.ui.MultitouchInputMode;
import flash.utils.ByteArray;
import flash.utils.Timer;

import mx.collections.ArrayCollection;
import mx.controls.Alert;
import mx.controls.Text;
import mx.controls.textClasses.TextRange;
import mx.core.IFlexDisplayObject;
import mx.core.UIComponent;
import mx.events.CloseEvent;
import mx.formatters.DateFormatter;
import mx.graphics.codec.JPEGEncoder;
import mx.managers.PopUpManager;

import spark.components.Button;
import spark.components.HGroup;
import spark.components.TextArea;
import spark.components.TitleWindow;

include "UserProfile.as";

private var ring:Sprite;
private var ui:UIComponent = new UIComponent();
private var texter:UIComponent = new UIComponent();
private var touchMoveID:int = 0; 
private var i:int = 1;	
private var timer:Timer = new Timer(200);

private var conn:SQLConnection;
private var createStmt:SQLStatement;
private var insertStmt:SQLStatement;
private var selectStmt:SQLStatement;
private var playbackItem:BitmapData;
private var playbackPosition:int = 0;
private var intervalId:uint;
[Bindable] private var recording:ArrayCollection = new ArrayCollection();

//[Embed(source="assets/back.jpg")]
//[Bindable] public var back:Class;
//[Embed(source="assets/front.jpg")]
//[Bindable] public var front:Class;

private var mytext:TextArea = text;
private var tf:TextFormat = new TextFormat();
private var idField:TextInput;
private var continueButton:Button;
private var _status:String;
private var dbFile:File;
private var dbFileName:String;

public var jpgSource:BitmapData; 


/* Database Operations */
private function init(evt:Event):void
{
	conn = new SQLConnection();

	//if(idField) //ID has been entered
	//{
	_status = "Creating and/or opening database for " + userInfoPopUp.currID;	trace(_status);

	//var formatStr:String = currID + "_" + getDateTime("YYYYMMDD_L:NNA");
	var formatStr:String = userInfoPopUp.currID + "_" + getDateTime("YYYYDDMM");
	
	dbFileName = "PainJournal/" + formatStr + ".db";
	//dbFileName = formatStr + ".db";
	dbFile = File.documentsDirectory.resolvePath(dbFileName); //save unique DB file to SD Card instead of application storage
	dbFile.parent.createDirectory();
	
	try
	{
		conn.open(dbFile);
		
		// Use this line for an in-memory database
		//conn.open(null);
	}
	catch (error:SQLError)
	{
		_status = "Error opening database " + dbFileName;	trace(_status);

		trace("error.message:", error.message);
		trace("error.details:", error.details);
		
		return;
	}
	
	createTable();
	//}
}


private function createTable():void
{
	_status = "Creating table ................";	trace(_status);

	createStmt = new SQLStatement();
	
	createStmt.sqlConnection = conn;
	var sql:String = "";
	sql += "CREATE TABLE IF NOT EXISTS test_tbl(id INTEGER PRIMARY KEY AUTOINCREMENT, body_img BLOB)";
	createStmt.text = sql;
	
	try
	{				
		createStmt.execute();
	}
	catch (error:SQLError)
	{
		_status = "Error creating table!"; trace(_status);
		
		trace("CREATE TABLE error:", error);
		trace("error.message:", error.message);
		trace("error.details:", error.details);
		
		return;
	}
}


/* Get date used for display & db file names */
private function getDateTime(dateFormat:String):String
{
	var theDate:Date = new Date();
	var theFormat:DateFormatter = new DateFormatter();
	theFormat.formatString = dateFormat;
	return theFormat.format(theDate);
}


/* Touch and Button Event Handling */
private function onAddedToStage(event:Event):void 
{

	Multitouch.inputMode=MultitouchInputMode.TOUCH_POINT; 
	addEventListener(TouchEvent.TOUCH_BEGIN, taphandler);
	
	if(Capabilities.cpuArchitecture=="ARM")
	{
		NativeApplication.nativeApplication.addEventListener(Event.ACTIVATE, handleActivate, false, 0, true);
		NativeApplication.nativeApplication.addEventListener(Event.DEACTIVATE, handleDeactivate, false, 0, true);
		NativeApplication.nativeApplication.addEventListener(KeyboardEvent.KEY_DOWN, handleKeys, false, 0, true);
	}
	
	var myDate:Date = new Date(); 
	var formatter:DateFormatter = new DateFormatter();
	formatter.formatString = "EEEE, MMM. D, YYYY";
	day.text = formatter.format(myDate);
	
	launchPopUp();	//launch pop up to get unique id
} 

private function handleDelButtonClick(event:Event):void
{
	ui.removeChild(ui.getChildAt(ui.numChildren-1));
}

private function handleSaveButtonClick(event:Event):void
{
	jpgSource = new BitmapData(imageBorder.width, imageBorder.height);
	jpgSource.draw(stage);
	//recording.addItem(jpgSource);  //to memory
	addData(jpgSource);  //to database	
		
	text.text = "";
	while (ui.numChildren) ui.removeChildAt(0);
}

private function addData(jpg_source:BitmapData):void
{
	
	_status = "Adding data to table .............";	trace(_status);
	var imgEncoder:JPEGEncoder = new JPEGEncoder();
	var imgBytes:ByteArray = imgEncoder.encode(jpg_source); // The PNGEncoder allows you to convert BitmapData object into a ByteArray for storage in an SQLite blob field
	//trace(imgBytes.toString());
	insertStmt = new SQLStatement();
	insertStmt.sqlConnection = conn;
	var sql:String = "";

	sql += "INSERT INTO test_tbl(body_img) VALUES(:imgBytes)";
	insertStmt.text = sql;
	insertStmt.parameters[":imgBytes"] = imgBytes;

	try
	{
		insertStmt.execute();
	}
	catch (error:SQLError)
	{
		_status = "Error inserting data!";	trace(_status);
	
		trace("INSERT error:", error);
		trace("error.message:", error.message);
		trace("error.details:", error.details);
	
		return;
	}

	_status = "Ready to load data ............";	trace(_status);
}

private function handlePlayButtonClick(event:Event):void
{	
	if (playBtn.label == "PLAY") {
		playBtn.label = "STOP";
		getData(); //from local db
		intervalId = setInterval(playData, 1000);
	}
	else if (playBtn.label == "STOP" /*&& playbackPosition == 0*/) {
		playBtn.label = "PLAY";
		clearInterval(intervalId);
		while (ui.numChildren) ui.removeChildAt(0);
	}

}

private function playData():void
{
	//from memory
	/*var playbackItem_mem:BitmapData = recording[playbackPosition];
	var myBitmap_mem:Bitmap = new Bitmap(playbackItem_mem);
	ui.addChild(myBitmap_mem);*/
		
	var byteArray:ByteArray = new ByteArray();
	var loader:Loader = new Loader();
	
	byteArray = recording[playbackPosition].body_img as ByteArray;
	
	/* Debug/Trace messages */
//	if(byteArray.bytesAvailable > 0)
//		trace("Data found");
//	else
//		trace("No data in field");
	
	configureListeners(loader.contentLoaderInfo);
	loader.loadBytes(byteArray);
	_status = "Loading image data for display ..............";	trace(_status);
	ui.addChild(loader);
	this.addElement(ui);
	
	playbackPosition += 1;
	if (playbackPosition == recording.length) 
	{
		playbackPosition = 0;
	}
	
}

private function configureListeners(dispatcher:IEventDispatcher):void 
{
	dispatcher.addEventListener(Event.COMPLETE, completeHandler);	
	dispatcher.addEventListener(IOErrorEvent.IO_ERROR, ioErrorHandler);
}

private function completeHandler(event:Event):void {
	trace("completeHandler: " + event);
	var loaderInfo:LoaderInfo = LoaderInfo(event.target);
}

private function ioErrorHandler(event:IOErrorEvent):void {
	trace("ioErrorHandler: " + event);
}

private function getData():void
{
	_status = "Loading data ............";	trace(_status);
	
	selectStmt = new SQLStatement();
	selectStmt.sqlConnection = conn;
	//var sql:String = "SELECT CAST(body_img AS ByteArray) AS body_img FROM test_tbl";
	var sql:String = "SELECT body_img FROM test_tbl";
	selectStmt.text = sql;
	
	try
	{
		selectStmt.execute();
	}
	catch (error:SQLError)
	{
		_status = "Error loading data!";	trace(_status);
		
		trace("SELECT error:", error);
		trace("error.message:", error.message);
		trace("error.details:", error.details);
		
		return;
	}
	
	_status = "Data loaded";	trace(_status);
	
	var result:SQLResult = selectStmt.getResult();
	
	recording = new ArrayCollection(result.data);

	/* Debug/Trace messages */	
//	var numRows:int = result.data.length;
//	for (var i:int = 0; i < numRows; i++)
//	{
//		var output:String = "";
//		for (var prop:String in result.data[i])
//		{
//			output += prop + ": " + result.data[i][prop] + "; ";
//		}
//			trace("row[" + i.toString() + "]\t", output);
//	}				
}

private function taphandler(event:TouchEvent):void
{
	if(touchMoveID != 0) {
		return;
	}
	touchMoveID = event.touchPointID; 
	
	if (event.stageX > imageBorder.width + imageBorder.x) return;
	if (event.stageY > imageBorder.height + imageBorder.y) return;
	if (event.stageX < imageBorder.x || event.stageY < imageBorder.y) return;
	if (event.stageX < 180 && event.stageY < 220) {
		if (this.currentState == 'State1') {
			this.currentState = 'State2';
			return;
		} else {
			this.currentState = 'State1';	
			return;
		}
	}
	if (event.stageX > 480-180 && event.stageY < 220) return;
	if (event.stageX < 100 && event.stageY < 400) return;
	if (event.stageX > 480-130 && event.stageY < 400) return;
	if (event.stageX < 150 && event.stageY > 450) return;
	if (event.stageX > 480-160 && event.stageY > 450) return;
	
	createRing();
	ring.x = event.stageX;
	ring.y = -40 + event.stageY; // place ring above the finger
	addEventListener(TouchEvent.TOUCH_END, onTouchEnd);
	timer.addEventListener(TimerEvent.TIMER, scaleTimer, false, 0, false);
	i = 1;
	timer.start();
}

private function scaleTimer(event:TimerEvent):void
{
	//				tf.color = 0xEE6002;
	//				if (i<3) { 
	//					tf.color = 0xE6B800;
	//				}
	//				if (i>7) { 
	//					tf.color = 0xEE6002;
	//				}
	//				mytext.setStyle("textFormat",tf);
	text.text = i.toString();
	if (i<10) {
		i++;
		ring.scaleX *= 1.1;
		ring.scaleY *= 1.1;
	}
}		

private function onTouchEnd(event:TouchEvent):void 
{ 
	if(event.touchPointID != touchMoveID) { 
		return; 
	} 
	removeEventListener(TimerEvent.TIMER, scaleTimer);
	touchMoveID = 0; 
	timer.stop();
	timer.removeEventListener(TouchEvent.TOUCH_END, onTouchEnd);
}


private function createRing():void
{
	ring = new Sprite();
	ring.graphics.clear();
	var circRad:Number = 20;
	var fillType:String = GradientType.RADIAL;
	var colors:Array = [0xff4500, 0xffb6c1]; 
	var alphas:Array = [0.8,0.3];
	var ratios:Array = [0,255]; 
	var matr:Matrix = new Matrix();
	matr.createGradientBox(2*circRad,2*circRad,0,-circRad,-circRad);
	var spreadMethod:String = SpreadMethod.PAD;
	var interp:String = InterpolationMethod.LINEAR_RGB;
	var focalPtRatio:Number = 0;
	ring.graphics.beginGradientFill(fillType, colors, alphas, ratios, matr, spreadMethod, interp, focalPtRatio);  
	ring.graphics.drawCircle(0, 0, circRad);
	ring.cacheAsBitmap = true;
	
	ui.addChild(ring);
	this.addElement(ui);
}

private function handleActivate(event:Event):void
{
	NativeApplication.nativeApplication.systemIdleMode = SystemIdleMode.KEEP_AWAKE;
}

private function handleDeactivate(event:Event):void
{
	NativeApplication.nativeApplication.exit();
}

private function handleKeys(event:KeyboardEvent):void
{
	if(event.keyCode == Keyboard.BACK)
		NativeApplication.nativeApplication.exit();
}


