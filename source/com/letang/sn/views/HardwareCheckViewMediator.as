package com.letang.sn.views
{
	import com.letang.sn.utils.ADSLUtil;
	import com.letang.sn.utils.PYUtil;
	import com.letang.sn.utils.YunDaMa;
	import com.letang.sn.views.comp.HelpView;
	import com.letang.sn.views.comp.SettingView;
	import com.letang.sn.views.comp.WarningWin;
	
	import flash.data.EncryptedLocalStore;
	import flash.events.Event;
	import flash.events.TimerEvent;
	import flash.filesystem.File;
	import flash.filesystem.FileMode;
	import flash.filesystem.FileStream;
	import flash.net.FileFilter;
	import flash.system.Capabilities;
	import flash.utils.ByteArray;
	import flash.utils.Timer;
	import flash.utils.setTimeout;
	
	import mx.controls.Alert;
	import mx.managers.PopUpManager;
	
	public class HardwareCheckViewMediator
	{
		/**批处理数量*/
		[Bindable]
		public var batchNum:int = 10;
		
		[Bindable]
		public var pythonPath:String = "";
		[Bindable]
		public var adslName:String = "";
		[Bindable]
		public var adslPass:String = "";
		[Bindable]
		public var damaName:String = "";
		[Bindable]
		public var damaPass:String = "";
		
		[Bindable]
		public var validateMsg:String = "";
		[Bindable]
		/**来自Python的输出信息显示*/
		public var pyValidateMsg:String = "";
		[Bindable]
		public var snNum:int;
		[Bindable]
		public var wailtNum:int;
		[Bindable]
		public var snRealNum:int;
		[Bindable]
		public var snInvaNum:int;
		[Bindable]
		public var currentIndex:int = -1;
		[Bindable]
		public var currentBatchLen:int = 0;
		[Bindable]
		public var timerCode:String = "00:00";
		[Bindable]
		public var snFilePath:String;
		[Bindable]
		public var adslCount:int = 0;
		
		private var snFile:File;
		
		private var price:int = 12;//打码一次需要的题分
		private var csrfToken:String;
		private var jsession:String;
		private var dpsq:String;
		
		private var snList:Array;
		private var successList:Array;
		private var faultList:Array;
		private var tempSuccessList:Array;//暂存
		private var tempFaultList:Array;//暂存
		
		[Bindable]
		public var damaObj:YunDaMa;
		
		public var adslTool:ADSLUtil;
		private var pyTool:PYUtil;
		private var startTime:Number;//计算耗时用
		private var endTime:Number;//计算耗时用
		private var moneyTimer:Timer;//每隔1分钟，更新一次题分余额
		private var timeoutTimer:Timer;//如果5分钟仍没有结果，警告
		private var currentBatch:Array;
		
		[Bindable]
		public var damaMoney:String = "未知";
		
		private var view:HardwareCheckView;
		private var warningWin:WarningWin;
		private var settingView:SettingView;
		private var helpView:HelpView;
		
		public function HardwareCheckViewMediator(viewRef:HardwareCheckView)
		{
			view = viewRef;
		}
		
		public function init():void
		{
			successList = [];
			faultList = [];
			restorePathFromCache();
			damaObj = new YunDaMa(damaName,damaPass);
			damaObj.addEventListener("getMoneyComplete",getMoneyCompleteHandler);
			damaObj.getMoney();
			adslTool = new ADSLUtil(adslName,adslPass);
			adslTool.addEventListener("networkReady",networkReadyHandler);
			pyTool = new PYUtil(pythonPath);
			pyTool.addEventListener("validateComplete",pyValidateCompleteHandler);
			snFile = new File();
			snFile.addEventListener(Event.SELECT,snFileSelectedHandler);
			moneyTimer = new Timer(60000);
			moneyTimer.addEventListener(TimerEvent.TIMER,moneyTimerHandler);
			moneyTimer.start();
			timeoutTimer = new Timer(1000,300);
			timeoutTimer.addEventListener(TimerEvent.TIMER,showTimerValue);
			timeoutTimer.addEventListener(TimerEvent.TIMER_COMPLETE,timeoutTimerHandler);
			warningWin = new WarningWin();
			settingView = new SettingView();
			settingView.mediator = this;
			helpView = new HelpView();
		}
		
		private function restorePathFromCache():void
		{
			var storedValue:ByteArray = EncryptedLocalStore.getItem("pythonPath");
			if(storedValue != null) {
				pythonPath = storedValue.readUTFBytes(storedValue.length);
			}
			storedValue = EncryptedLocalStore.getItem("adslName");
			if(storedValue != null) {
				adslName = storedValue.readUTFBytes(storedValue.length);
			}
			storedValue = EncryptedLocalStore.getItem("adslPass");
			if(storedValue != null) {
				adslPass = storedValue.readUTFBytes(storedValue.length);
			}
			storedValue = EncryptedLocalStore.getItem("damaName");
			if(storedValue != null) {
				damaName = storedValue.readUTFBytes(storedValue.length);
			}
			storedValue = EncryptedLocalStore.getItem("damaPass");
			if(storedValue != null) {
				damaPass = storedValue.readUTFBytes(storedValue.length);
			}
		}
		
		protected function showTimerValue(event:TimerEvent):void
		{
			var sec:int = timeoutTimer.currentCount;
			var m:int = int(sec/60);
			var mStr:String = m>9?String(m):"0"+m;
			var s:int = sec%60;
			var sStr:String = s>9?String(s):"0"+s;
			timerCode = mStr+":"+sStr;
		}
		protected function timeoutTimerHandler(event:TimerEvent):void
		{
			PopUpManager.addPopUp(warningWin,view,true);
			PopUpManager.centerPopUp(warningWin);
			setTimeout(function():void{
				PopUpManager.removePopUp(warningWin);
				if(view.currentState=="normal") return;
				runTask();
			},10000);//显示十秒
		}
		
		protected function moneyTimerHandler(event:TimerEvent):void
		{
			damaObj.getMoney();
		}
		
		public function chooseFile():void
		{
			snFile.browse([new FileFilter("TXT", "*.txt")]);
		}
		
		protected function snFileSelectedHandler(event:Event):void
		{
			snFilePath = snFile.nativePath;
			var stream:FileStream = new FileStream();
			stream.open(snFile,FileMode.READ);
			var snStr:String = stream.readUTFBytes(stream.bytesAvailable);
			stream.close();
			snList = getNotNullArray(snStr.split("\n"));
			snNum = snList.length;
			restoreListFromCache();
		}
		
		private function getNotNullArray(arr:Array):Array
		{
			var newArr:Array = [];
			for each (var sn:String in arr) 
			{
				sn = sn.replace(/\s/g,"");
				if(sn != "") newArr.push(sn);
			}
			return newArr;
		}
		
		public function startTask():void
		{
			view.currentState = "running";
			damaObj.isRunning = true;
			var userSetIndex:int = 0;
			if(currentIndex<userSetIndex)
				currentIndex = userSetIndex;
			createBatch();
			runTask();
		}
		
		private function createBatch():void
		{
			currentBatch = [];
			tempSuccessList = [];
			tempFaultList = [];
			var count:int = 0;
			for (var i:int = currentIndex; i < snList.length; i++) 
			{
				count++;
				currentBatch.push(snList[i]);
				if(count==batchNum) break;
			}
			currentBatchLen = currentBatch.length;
		}
		
		private function runTask():void
		{
			timerCode = "00:00";
			wailtNum = snList.length-snRealNum-snInvaNum;
			validateMsg = "正在验证序列号："+currentBatch.join(",");
			timeoutTimer.stop();
			timeoutTimer.reset();
			timeoutTimer.start();
			getCSRFTokenByPY();
		}
		private function getCSRFTokenByPY():void
		{
			pyTool.resetPythonFromEmbed();
			//替换变量
			var targetFolder:File = File.userDirectory.resolvePath("pyfiles");
			var file:File = targetFolder.resolvePath("SNWorker.py");
			damaObj.replaceParms(file);
			//执行PY文件
			var mainFile:File = targetFolder.resolvePath("SNValidator.py");
			pyTool.validateSN(mainFile.nativePath,currentBatch);
		}
		
		protected function pyValidateCompleteHandler(event:Event):void
		{
			if(view.currentState=="normal") return;
			pyValidateMsg = pyTool.pyResultMsg;
			var pyResultCodes:Array = pyTool.pyResultCodes;
			if(pyResultCodes.length != currentBatch.length)
			{
				validateMsg += "\n结果还在返回中...";
				return;
			}
			var needRestADSL:Boolean = false;
			var goBackArr:Array = [];//需要回炉重新判断的
			for (var i:int = 0; i < pyResultCodes.length; i++) 
			{
				var code:int = pyResultCodes[i];
				var sn:String = currentBatch[i];
				if(code == 1) {       //有效
					tempSuccessList.push(sn);
				} else if(code == 2) {//无效
					tempFaultList.push(sn);
				} else if(code == 3) {//换IP
					goBackArr.push(sn);
					needRestADSL = true;
				} else if(code == 4) {//重新打码
					goBackArr.push(sn);
				}
			}
			updateDataView();
			if(goBackArr.length>0) {//有没处理完的
				currentBatch = goBackArr;
				currentBatchLen = currentBatch.length;
				if(needRestADSL) {
					validateMsg += "\n需要更换IP再试";
					adslTool.closeADSL();
					adslCount+=1;
					setTimeout(adslTool.openADSL,5000);
				} else {
					runTask();
				}
			} else {//下一个批次
				currentBatchLen = 0;
				markAndGoNext();
			}
		}
		
		protected function networkReadyHandler(event:Event):void
		{
			validateMsg += "\n网络已恢复，继续";
			runTask();
		}
		
		protected function getMoneyCompleteHandler(event:Event):void
		{
			damaMoney = String(damaObj.money)+"("+int(damaObj.money/price)+")";
			if(view.currentState=="normal") return;
			if(damaObj.money < price)
			{
				Alert.show("打码余额不足，无法继续");
				stopTask();
			}
		}
		
		public function stopTask():void
		{
			timeoutTimer.stop();
			view.currentState = "normal";
			damaObj.isRunning = false;
			pyTool.cleanTempFile();
		}
		
		private function updateDataView():void
		{
			var tempSLen:int = tempSuccessList==null?0:tempSuccessList.length;
			var tempFLen:int = tempFaultList==null?0:tempFaultList.length;
			snRealNum = successList.length+tempSLen;
			snInvaNum = faultList.length+tempFLen;
			wailtNum = snList.length-(snRealNum+snRealNum);
			setPBarValue();
			saveDataToCache();
		}
		
		/**标记检测结果，然后执行下一套*/
		private function markAndGoNext():void
		{
			if(tempSuccessList.length > 0)//合并
			{
				successList = successList.concat(tempSuccessList);
				tempSuccessList = [];
			}
			if(tempFaultList.length > 0)//合并
			{
				faultList = faultList.concat(tempFaultList);
				tempFaultList = [];
			}
			updateDataView();
			currentIndex = snRealNum+snInvaNum;
			if(currentIndex==snList.length) {//结束了
				stopTask();
				Alert.show("检测任务已经全部完成");
			} else {
				createBatch();
				runTask();
			}
		}
		private function saveDataToCache():void
		{
			var lineSymble:String = "\n";
			if(Capabilities.os.indexOf("Windows") != -1)
				lineSymble = "\r\n";
			var fileName:String = snFile.name.slice(0,snFile.name.length-4);
			//有效的
			var file:File = snFile.parent.resolvePath(fileName+"-有效.txt");
			var stream:FileStream;
			stream = new FileStream();
			stream.open(file,FileMode.WRITE);
			stream.writeUTFBytes(successList.join(lineSymble));
			stream.close();
			//无效的
			file = snFile.parent.resolvePath(fileName+"-无效.txt");
			stream = new FileStream();
			stream.open(file,FileMode.WRITE);
			stream.writeUTFBytes(faultList.join(lineSymble));
			stream.close();
		}
		private function restoreListFromCache():void
		{
			var fileName:String = snFile.name.slice(0,snFile.name.length-4);
			var lineSymble:String = "\n";
			//有效的
			var file:File = snFile.parent.resolvePath(fileName+"-有效.txt");
			var stream:FileStream;
			var snListStr:String;
			if(file.exists) {
				stream = new FileStream();
				stream.open(file,FileMode.READ);
				snListStr = stream.readUTFBytes(stream.bytesAvailable);
				if(snListStr != "")
					successList = getNotNullArray(snListStr.split(lineSymble));
				else
					successList = [];
				stream.close();
			}
			//无效的
			file = snFile.parent.resolvePath(fileName+"-无效.txt");
			if(file.exists) {
				stream = new FileStream();
				stream.open(file,FileMode.READ);
				snListStr = stream.readUTFBytes(stream.bytesAvailable);
				if(snListStr != "")
					faultList = getNotNullArray(snListStr.split(lineSymble));
				else
					faultList = [];
				stream.close();
			}
			snRealNum = successList.length;
			snInvaNum = faultList.length;
			currentIndex = snRealNum+snInvaNum;
			wailtNum = snList.length-snRealNum-snInvaNum;
			setPBarValue();
			//判断是否已经完成了
			if(currentIndex==snList.length)
			{
				Alert.show("该批次的任务已经完成!");
			}
		}
		
		/**显示整体进度*/
		private function setPBarValue():void
		{
			view.pBar.minimum = 0;
			view.pBar.maximum = snList.length;
			view.pBar.setProgress(currentIndex,snList.length);
			view.pBar.label = "当前进度: "+int(currentIndex/snList.length*100)+" %";
			view.pBar.validateNow();
		}
		
		/**下载检验过的列表*/
		public function openList(type:int):void
		{
			var fileName:String = snFile.name.slice(0,snFile.name.length-4);
			var fileKey:String = type==1?"-有效":"-无效";
			fileName += fileKey+".txt";
			var file:File = snFile.parent.resolvePath(fileName);
			if(file.exists)
				file.openWithDefaultApplication();
			else
				Alert.show("未找到日志文件");
		}
		
		
		public function savePythonPath():void
		{
			var bytes:ByteArray = new ByteArray();
			bytes.writeUTFBytes(pythonPath);
			EncryptedLocalStore.setItem("pythonPath", bytes);
			pyTool.setPythonPath(pythonPath);
		}
		
		public function saveADSLInfo():void
		{
			var bytes:ByteArray = new ByteArray();
			bytes.writeUTFBytes(adslName);
			EncryptedLocalStore.setItem("adslName", bytes);
			adslTool.adslName = adslName;
			bytes = new ByteArray();
			bytes.writeUTFBytes(adslPass);
			EncryptedLocalStore.setItem("adslPass", bytes);
			adslTool.adslPass = adslPass;
		}
		
		public function openSettingWindow():void
		{
			PopUpManager.addPopUp(settingView,view,true);
			PopUpManager.centerPopUp(settingView);
		}
		
		public function openHelpWindow():void
		{
			PopUpManager.addPopUp(helpView,view,true);
			PopUpManager.centerPopUp(helpView);
		}
		
		public function saveDamaInfo():void
		{
			var bytes:ByteArray = new ByteArray();
			bytes.writeUTFBytes(damaName);
			EncryptedLocalStore.setItem("damaName", bytes);
			damaObj.username = damaName;
			bytes = new ByteArray();
			bytes.writeUTFBytes(damaPass);
			EncryptedLocalStore.setItem("damaPass", bytes);
			damaObj.password = damaPass;
		}
	}
}