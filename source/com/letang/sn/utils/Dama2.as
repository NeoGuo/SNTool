package com.letang.sn.utils
{
	import com.adobe.crypto.MD5;
	
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.IEventDispatcher;
	import flash.net.URLLoader;
	import flash.net.URLRequest;
	import flash.net.URLRequestMethod;
	import flash.net.URLVariables;
	import flash.utils.ByteArray;
	
	[Event(name="getMoneyComplete", type="flash.events.Event")]
	[Event(name="damaComplete", type="flash.events.Event")]
	[Event(name="damaError", type="flash.events.Event")]
	public class Dama2 extends EventDispatcher
	{
		private static const moneyURL:String = "http://api.dama2.com:7766/app/d2Balance";//查询余额
		private static const damaURL:String = "http://api.dama2.com:7766/app/d2File";//打码
		
		private var appID:String = "";
		private var user:String = "";
		private var pw:String = "";
		private var pwd:String;//加密的秘钥
		private var appKey:String = "";
		private var type:int = 53;
		
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
		
		public function Dama2(target:IEventDispatcher=null)
		{
			super(target);
			pwd = createPWD();
		}
		
		private function createPWD():String
		{
			var md5PWD:String;
			var userMD5:String = MD5.hash(user);
			var pwMD5:String = MD5.hash(pw);
			var cMD5:String = MD5.hash(userMD5+pwMD5);
			md5PWD = MD5.hash(appKey+cMD5);
			return md5PWD;
		}
		
		private function createSign(...args):String
		{
			var finalSign:String;
			var aMD5:String = appKey+user;
			for each (var a:String in args) 
			{
				aMD5 += a;
			}
			var bMD5:String = MD5.hash(aMD5);
			finalSign = bMD5.slice(0,8);
			return finalSign;
		}
		
		public function getMoney():void
		{
			var request:URLRequest = new URLRequest(moneyURL);
			request.method = URLRequestMethod.GET;
			var data:URLVariables = new URLVariables();
			data.appID = appID;
			data.user = user;
			data.pwd = pwd;
			data.sign = createSign();
			request.data = data;
			var loader:URLLoader = new URLLoader();
			loader.addEventListener(Event.COMPLETE, getMoneyCompleteHandler);
			loader.load(request);
		}
		
		protected function getMoneyCompleteHandler(event:Event):void
		{
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
		
		public function dama(fileDataBase64:String,pngBytes:ByteArray):void
		{
			var request:URLRequest = new URLRequest(damaURL);
			request.method = URLRequestMethod.POST;
			var data:URLVariables = new URLVariables();
			data.appID = appID;
			data.user = user;
			data.pwd = pwd;
			data.type = type;
			data.fileDataBase64 = fileDataBase64;
			//pngBytes.position = 0;
			trace(pngBytes.length);
			//var pngStr:String = convertByteArrayToString(pngBytes);
			//trace(pngStr);
			data.sign = createSign(pngBytes);
			request.data = data;
			var loader:URLLoader = new URLLoader();
			loader.addEventListener(Event.COMPLETE, damaCompleteHandler);
			loader.load(request);
		}
		protected function damaCompleteHandler(event:Event):void
		{
			var loader:URLLoader = event.target as URLLoader;
			var result:Object = JSON.parse(loader.data);
			if(result.ret>=0) {
				trace(result.reuslt);
				dispatchEvent(new Event("damaComplete"));
			} else {
				_errorMsg = ("ERROR:"+result.ret);
				dispatchEvent(new Event("damaError"));
			}
		}
		public function convertByteArrayToString(bytes:ByteArray):String   
		{   
			var str:String;   
			if (bytes)   
			{   
				bytes.position=0;   
				str=bytes.readUTFBytes(bytes.length);   
			}   
			return str;   
		}
		private function byteArrayTo16(ba:ByteArray):String
		{  
			ba.position=0;  
			var b_str:String="";  
			while (ba.bytesAvailable > 0) {  
				var b_s:String=ba.readUnsignedByte().toString(16);  
				//              trace("b_s:",b_s);  
				if(b_s.length<2) b_s="0"+b_s;  
				b_str+=b_s;  
			}  
			return b_str;  
		}
	}
}