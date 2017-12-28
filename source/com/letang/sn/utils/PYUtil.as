package com.letang.sn.utils
{
	import flash.desktop.NativeApplication;
	import flash.desktop.NativeProcess;
	import flash.desktop.NativeProcessStartupInfo;
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.IEventDispatcher;
	import flash.events.IOErrorEvent;
	import flash.events.ProgressEvent;
	import flash.filesystem.File;
	import flash.filesystem.FileMode;
	import flash.filesystem.FileStream;
	import flash.utils.ByteArray;
	import flash.utils.setTimeout;
	
	import mx.controls.Alert;
	import mx.managers.PopUpManager;
	
	[Event(name="validateComplete", type="flash.events.Event")]
	public class PYUtil extends EventDispatcher
	{
		[Embed(source="python/SNValidator.py",mimeType="application/octet-stream")]
		private var SNValidatorPY:Class;
		[Embed(source="python/SNWorker.py",mimeType="application/octet-stream")]
		private var SNWorkerPY:Class;
		[Embed(source="python/YDMHttp.py",mimeType="application/octet-stream")]
		private var YDMHttpPY:Class;
		
		private var _pythonPath:String = "";
		private var process:NativeProcess;
		private var _currentBatch:Array;
		private var _mainPyFilePath:String;
		private var alert:Alert;
		
		private var _pyResultCodes:Array;
		/**数组，与SN数组等长，每一项是数字：1=信息为真，2=信息为假，3=需要更换IP，4=验证码错了*/
		public function get pyResultCodes():Array
		{
			return _pyResultCodes;
		}
		
		private var _pyResultMsg:String = "";
		/**返回的输出信息*/
		public function get pyResultMsg():String
		{
			return _pyResultMsg;
		}
		
		public function PYUtil(pythonPath:String,target:IEventDispatcher=null)
		{
			_pythonPath = pythonPath;
			super(target);
		}
		
		public function validateSN(mainPyFilePath:String,currentBatch:Array):void
		{
			if(_pythonPath == null || _pythonPath == "") {
				Alert.show("Python路径未定义");
				return;
			}
			_pyResultMsg = "";
			_mainPyFilePath = mainPyFilePath;
			_currentBatch = currentBatch;
			if(checkProcessSupport()==false) return;
			var processArgs:Vector.<String> = new Vector.<String>();
			processArgs[0] = mainPyFilePath;
			for each (var sn:String in currentBatch) 
			{
				processArgs.push(sn);
			}
			registProcess(processArgs);
		}
		private function registProcess(processArgs:Vector.<String>):void
		{
			var rasdialFile:File = new File(_pythonPath);
			var nativeProcessStartupInfo:NativeProcessStartupInfo = new NativeProcessStartupInfo();
			nativeProcessStartupInfo.executable = rasdialFile;
			nativeProcessStartupInfo.arguments = processArgs;
			if(process != null) {//clean
				process.removeEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onOutputData);
				process.removeEventListener(ProgressEvent.STANDARD_ERROR_DATA, onErrorData);
				process.removeEventListener(IOErrorEvent.STANDARD_OUTPUT_IO_ERROR, onIOError);
				process.removeEventListener(IOErrorEvent.STANDARD_ERROR_IO_ERROR, onIOError);
				process.exit();
			}
			process = new NativeProcess();
			process.start(nativeProcessStartupInfo);
			process.addEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onOutputData);
			process.addEventListener(ProgressEvent.STANDARD_ERROR_DATA, onErrorData);
			process.addEventListener(IOErrorEvent.STANDARD_OUTPUT_IO_ERROR, onIOError);
			process.addEventListener(IOErrorEvent.STANDARD_ERROR_IO_ERROR, onIOError);
		}
		private function checkProcessSupport():Boolean
		{
			var rasdialFile:File = new File(_pythonPath);
			if(!rasdialFile.exists) {
				Alert.show(_pythonPath+"不存在");
				return false;
			}
			if(!NativeProcess.isSupported) {
				Alert.show("不支持命令行模式");
				return false;
			}
			return true;
		}
		public function onOutputData(event:ProgressEvent):void
		{
			var cmdOutput:String = process.standardOutput.readMultiByte(process.standardOutput.bytesAvailable,"gb2312");
			_pyResultMsg += (cmdOutput+"\n");
			_pyResultCodes = [];
			//
			for each (var sn:String in _currentBatch) 
			{
				var code:int = -1;
				if(_pyResultMsg.indexOf("SNRET:1:"+sn) != -1) {
					code = 1;
				} else if(_pyResultMsg.indexOf("SNRET:2:"+sn) != -1) {
					code = 2;
				} else if(_pyResultMsg.indexOf("SNRET:3:"+sn) != -1) {
					code = 3;
				} else if(_pyResultMsg.indexOf("SNRET:4:"+sn) != -1) {
					code = 4;
				}
				if(code != -1)
					_pyResultCodes.push(code);
			}
			dispatchEvent(new Event("validateComplete"));
		}
		public function onErrorData(event:ProgressEvent):void
		{
			var msg:String = process.standardError.readMultiByte(process.standardError.bytesAvailable,"gb2312");
			trace(msg);
			alert = Alert.show(msg,"onErrorData-30秒关闭");
			setTimeout(function():void {
				PopUpManager.removePopUp(alert);
				validateSN(_mainPyFilePath,_currentBatch);//retry
			},30000);
		}
		public function onIOError(event:IOErrorEvent):void
		{
			Alert.show(event.toString(),"onIOError");
		}
		
		public function setPythonPath(pythonPath:String):void
		{
			_pythonPath = pythonPath;
		}
		
		public function resetPythonFile():void
		{
			//拷贝PY文件
			try {
				var fileNames:Array = ["SNValidator.py","YDMHttp.py","SNWorker.py"];
				var file:File;
				var targetFolder:File = File.userDirectory.resolvePath("pyfiles");
				for each (var pyName:String in fileNames) 
				{
					file = File.applicationDirectory.resolvePath("files").resolvePath(pyName);
					file.copyTo(targetFolder.resolvePath(pyName),true);
				}
			}catch(err:Error){
				Alert.show("PY文件系统异常!!!");
				setTimeout(NativeApplication.nativeApplication.exit,3000);
			}
		}
		
		public function resetPythonFromEmbed():void
		{
			//生成PY文件
			try {
				var fileNames:Array = ["SNValidator.py","YDMHttp.py","SNWorker.py"];
				var fileClazz:Array = [SNValidatorPY,YDMHttpPY,SNWorkerPY];
				for (var i:int = 0; i < fileClazz.length; i++) 
				{
					var fileEmd:Class = fileClazz[i];
					var fileBytes:ByteArray = new fileEmd();
					var fileCon:String = fileBytes.readUTFBytes(fileBytes.bytesAvailable);
					var targetFolder:File = File.userDirectory.resolvePath("pyfiles");
					var pyName:String = fileNames[i];
					var file:File = targetFolder.resolvePath(pyName);
					var steam:FileStream = new FileStream();
					steam.open(file,FileMode.WRITE);
					steam.writeUTFBytes(fileCon);
					steam.close();
				}
				
			}catch(err:Error){
				trace(err);
				Alert.show("PY文件系统异常!!!");
				setTimeout(NativeApplication.nativeApplication.exit,3000);
			}
		}
		
		public function cleanTempFile():void
		{
			var targetFolder:File = File.userDirectory.resolvePath("pyfiles");
			var files:Array = targetFolder.getDirectoryListing();
			for each (var file:File in files) 
			{
				if(file.isDirectory)
					file.deleteDirectory(true);
				else
					file.deleteFile();
			}
		}
	}
}