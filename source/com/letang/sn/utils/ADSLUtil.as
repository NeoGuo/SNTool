package com.letang.sn.utils
{
	import flash.desktop.NativeProcess;
	import flash.desktop.NativeProcessStartupInfo;
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.IOErrorEvent;
	import flash.events.ProgressEvent;
	import flash.filesystem.File;
	import flash.net.URLLoader;
	import flash.net.URLRequest;
	import flash.system.Capabilities;
	import flash.utils.setTimeout;
	
	import mx.controls.Alert;
	
	[Event(name="networkReady", type="flash.events.Event")]
	public class ADSLUtil extends EventDispatcher
	{
		private var rasdialPath:String = "C:\\Windows\\System32\\rasdial.exe";
		private var process:NativeProcess;
		
		public var adslName:String;
		public var adslPass:String;
		
		public function ADSLUtil(v1:String=null,v2:String=null)
		{
			super(null);
			if(v1 != null && v2 != null) {
				adslName = v1;
				adslPass = v2;
			}
		}
		
		public function closeADSL():void
		{
			if(checkProcessSupport()==false) return;
			var processArgs:Vector.<String> = new Vector.<String>();
			processArgs[0] = "宽带连接";
			processArgs[1] = "/DISCONNECT";
			registProcess(processArgs);
		}
		private function registProcess(processArgs:Vector.<String>):void
		{
			var rasdialFile:File = new File(rasdialPath);
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
			if(Capabilities.os.indexOf("Mac OS") != -1) {
				Alert.show("苹果系统不支持");
				return false;
			}
			var rasdialFile:File = new File(rasdialPath);
			if(!rasdialFile.exists) {
				Alert.show(rasdialPath+"不存在");
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
			trace("CMD: "+ process.standardOutput.readMultiByte(process.standardOutput.bytesAvailable,"gb2312"));
		}
		public function onErrorData(event:ProgressEvent):void
		{
			Alert.show("ERROR -", process.standardError.readMultiByte(process.standardError.bytesAvailable,"gb2312"));
		}
		public function onIOError(event:IOErrorEvent):void
		{
			Alert.show(event.toString());
		}
		/**切换IP*/
		public function openADSL():void
		{
			if(checkProcessSupport()==false) return;
			var processArgs:Vector.<String> = new Vector.<String>();
			processArgs[0] = "宽带连接";
			processArgs[1] = adslName;
			processArgs[2] = adslPass;
			registProcess(processArgs);
			setTimeout(testLoadBaidu,3000);
		}
		private function testLoadBaidu():void
		{
			var baiduLoader:URLLoader = new URLLoader();
			baiduLoader.addEventListener(Event.COMPLETE,baiduLoaderComplete);
			baiduLoader.addEventListener(IOErrorEvent.IO_ERROR,baiduLoadError);
			baiduLoader.load(new URLRequest("http://www.baidu.com"));
		}
		protected function baiduLoaderComplete(event:Event):void
		{
			var baiduLoader:URLLoader = URLLoader(event.target);
			baiduLoader.removeEventListener(Event.COMPLETE,baiduLoaderComplete);
			baiduLoader.removeEventListener(IOErrorEvent.IO_ERROR,baiduLoadError);
			dispatchEvent(new Event("networkReady"));
		}
		protected function baiduLoadError(event:IOErrorEvent):void
		{
			var baiduLoader:URLLoader = URLLoader(event.target);
			setTimeout(function():void {
				baiduLoader.load(new URLRequest("http://www.baidu.com"));
			},2000);
		}
		
	}
}