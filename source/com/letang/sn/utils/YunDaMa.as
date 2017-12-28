package com.letang.sn.utils
{
	import flash.desktop.NativeApplication;
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.IOErrorEvent;
	import flash.filesystem.File;
	import flash.filesystem.FileMode;
	import flash.filesystem.FileStream;
	import flash.net.URLLoader;
	import flash.net.URLLoaderDataFormat;
	import flash.net.URLRequest;
	import flash.net.URLRequestMethod;
	import flash.net.URLVariables;
	import flash.system.Capabilities;
	import flash.utils.ByteArray;
	import flash.utils.setTimeout;
	
	import mx.controls.Alert;
	
	[Event(name="getMoneyComplete", type="flash.events.Event")]
	[Event(name="damaComplete", type="flash.events.Event")]
	[Event(name="damaError", type="flash.events.Event")]
	public class YunDaMa extends EventDispatcher
	{
		private static const apiURL:String = "http://api.yundama.com/api.php";
		
		public var isRunning:Boolean = false;
		
		[Bindable]
		public var username:String = "";
		[Bindable]
		public var password:String = "";
		
		private var appid:String = "4300";
		private var appkey:String = "e4f6085358adfbb8044b1965d65bbf49";
		private var codetype:int = 1005;
		private var timeout:int = 60;
		
		private var lastDamaPicID:int = -1;//最后一次打码的图片ID，用于处理延迟获取
		private var imgBytesBCP:ByteArray;//打码图片备份，以便重试
		private var moneyLoader:URLLoader;
		private var damaLoader:URLLoader;
		private var getCodeLoader:URLLoader;
		private var reportLoader:URLLoader;
		
		private var _money:int;
		public function get money():int
		{
			return _money;
		}
		
		private var _errorMsg:String;
		public function get errorMsg():String
		{
			return _errorMsg;
		}
		
		private var _code:String;
		public function get code():String
		{
			return _code;
		}
		
		/**构造*/
		public function YunDaMa(damaName:String,damaPass:String)
		{
			super(null);
			username = damaName;
			password = damaPass;
			moneyLoader = new URLLoader();
			moneyLoader.addEventListener(Event.COMPLETE, getMoneyCompleteHandler);
			moneyLoader.addEventListener(IOErrorEvent.IO_ERROR,getMoneyError);
			damaLoader = new URLLoader();
			damaLoader.dataFormat = URLLoaderDataFormat.BINARY;
			damaLoader.addEventListener(Event.COMPLETE, damaCompleteHandler);
			damaLoader.addEventListener(IOErrorEvent.IO_ERROR,damaErrorHandler);
			getCodeLoader = new URLLoader();
			getCodeLoader.addEventListener(Event.COMPLETE, getCodeUseCIDCompleteHandler);
			getCodeLoader.addEventListener(IOErrorEvent.IO_ERROR,getCodeUseCIDError);
			reportLoader = new URLLoader();
			reportLoader.addEventListener(Event.COMPLETE, reportCompleteHandler);
		}
		
		public function getMoney():void
		{
			var request:URLRequest = new URLRequest(apiURL);
			request.method = URLRequestMethod.POST;
			var data:URLVariables = new URLVariables();
			data.username = username;
			data.password = password;
			data.appid = appid;
			data.appkey = appkey;
			data.method = "balance";
			request.data = data;
			moneyLoader.load(request);
		}
		
		protected function getMoneyError(event:IOErrorEvent):void
		{
			if(!isRunning) return;
			trace("getMoneyIOError:"+event.text);
			setTimeout(getMoney,2000);
		}
		
		protected function getMoneyCompleteHandler(event:Event):void
		{
			//if(!isRunning) return;
			var loader:URLLoader = event.target as URLLoader;
			var result:Object = JSON.parse(loader.data);
			if(result.ret>=0) {
				_money = result.balance;
				dispatchEvent(new Event("getMoneyComplete"));
			} else {
				_errorMsg = ("ERROR:"+result.ret);
				dispatchEvent(new Event("damaError"));
			}
		}
		
		public function dama(imgBytes:ByteArray):void
		{
			imgBytesBCP = imgBytes;
			var request:URLRequest = new URLRequest(apiURL);
			request.method = URLRequestMethod.POST;
			request.contentType = 'multipart/form-data; boundary=' + UploadPostHelper.getBoundary();
			var data:Object = {};
			data.username = username;
			data.password = password;
			data.appid = appid;
			data.appkey = appkey;
			data.method = "upload";
			data.codetype = codetype;
			request.data = UploadPostHelper.getPostData("yzm.jpg", imgBytes, data);
			damaLoader.load(request);
		}
		
		protected function damaErrorHandler(event:IOErrorEvent):void
		{
			if(!isRunning) return;
			trace("damaIOErrorHandler:"+event.text);
			imgBytesBCP.position = 0;
			setTimeout(dama,2000,imgBytesBCP);
		}
		
		protected function damaCompleteHandler(event:Event):void
		{
			if(!isRunning) return;
			var loader:URLLoader = event.target as URLLoader;
			var result:Object = JSON.parse(loader.data);
			if(result.ret>=0) {
				lastDamaPicID = result.cid;
				if(result.text != null && result.text != "") {
					_code = result.text;
					dispatchEvent(new Event("damaComplete"));
				} else {
					getCodeUseCID();
				}
			} else if(String(result.ret) == "-3002") {//验证码正在识别
				lastDamaPicID = result.cid;
				setTimeout(getCodeUseCID,2000);
			} else {
				_errorMsg = ("ERROR:"+result.ret);
				dispatchEvent(new Event("damaError"));
			}
		}
		
		private function getCodeUseCID():void
		{
			var request:URLRequest = new URLRequest(apiURL);
			request.method = URLRequestMethod.POST;
			var data:URLVariables = new URLVariables();
			data.cid = lastDamaPicID;
			data.method = "result";
			request.data = data;
			getCodeLoader.load(request);
		}
		
		protected function getCodeUseCIDError(event:IOErrorEvent):void
		{
			if(!isRunning) return;
			trace("getCodeUseCID_IOError:"+event.text);
			setTimeout(getCodeUseCID,2000);
		}
		
		protected function getCodeUseCIDCompleteHandler(event:Event):void
		{
			if(!isRunning) return;
			var loader:URLLoader = event.target as URLLoader;
			var result:Object = JSON.parse(loader.data);
			if(result.ret>=0) {
				if(result.text != null && result.text != "") {
					_code = result.text;
					dispatchEvent(new Event("damaComplete"));
				} else {
					setTimeout(getCodeUseCID,2000);
				}
			} else if(String(result.ret) == "-3002") {//验证码正在识别
				setTimeout(getCodeUseCID,2000);
			} else {
				_errorMsg = ("REGET_ERROR:"+result.ret);
				dispatchEvent(new Event("damaError"));
			}
		}
		/**报错接口*/
		public function report():void
		{
			var request:URLRequest = new URLRequest(apiURL);
			request.method = URLRequestMethod.POST;
			var data:URLVariables = new URLVariables();
			data.username = username;
			data.password = password;
			data.appid = appid;
			data.appkey = appkey;
			data.cid = lastDamaPicID;
			data.flag = 0;
			data.method = "report";
			request.data = data;
			reportLoader.load(request);
		}
		protected function reportCompleteHandler(event:Event):void
		{
			if(!isRunning) return;
			var loader:URLLoader = event.target as URLLoader;
			var result:Object = JSON.parse(loader.data);
			if(result.ret>=0) {
				trace("验证码是错的，已经上报成功");
			} else {
				trace("验证码是错的，上报也失败了");
			}
		}
		
		public function replaceParms(file:File):void
		{
			try {
				var steam:FileStream = new FileStream();
				steam.open(file,FileMode.READ);
				var con:String = steam.readUTFBytes(steam.bytesAvailable);
				con = con.replace("{$1}",username);
				con = con.replace("{$2}",password);
				con = con.replace("{$3}",appid);
				con = con.replace("{$4}",appkey);
				var picFolder:File = file.parent;
				var picFName:String = picFolder.nativePath+File.separator;
				if(Capabilities.os.indexOf("Windows") != -1)
					picFName = "";
				con = con.replace("picPath = 'testFolder/'","picPath = '"+picFName+"'");
				steam.close();
				steam.open(file,FileMode.WRITE);
				steam.writeUTFBytes(con);
				steam.close();
			}catch(err:Error){
				Alert.show("YDM:文件系统异常!!!");
				setTimeout(NativeApplication.nativeApplication.exit,3000);
			}
		}
	}
}