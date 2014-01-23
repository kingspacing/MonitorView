package com.monitor.view
{
	import com.greensock.TweenLite;
	import com.monitor.common.TimeUtils;
	import com.monitor.event.MonitorEvent;
	import com.monitor.model.*;
	
	import flash.display.MovieClip;
	import flash.display.SimpleButton;
	import flash.display.Sprite;
	import flash.display.StageDisplayState;
	import flash.events.Event;
	import flash.events.FocusEvent;
	import flash.events.IOErrorEvent;
	import flash.events.MouseEvent;
	import flash.events.NetStatusEvent;
	import flash.events.ProgressEvent;
	import flash.events.TimerEvent;
	import flash.media.SoundTransform;
	import flash.media.Video;
	import flash.net.NetConnection;
	import flash.net.NetStream;
	import flash.net.URLLoader;
	import flash.net.URLRequest;
	import flash.system.Capabilities;
	import flash.text.*;
	import flash.ui.Mouse;
	import flash.utils.*;
	
	import mx.utils.StringUtil;
	
	
	public class MonitorView extends MultiScreenUI
	{
		// static const
		private static const MAX_INT_VALUE:int = int.MAX_VALUE;
		private static const SCREEN_WIDTH:Number = Capabilities.screenResolutionX;
		private static const SCREEN_HEIGHT:Number = Capabilities.screenResolutionY;
		
		
		//variables
		private var _list:Array = [];
		private var _client:Object = new Object();
		private var _totalPageNumOfNine:int = 0;
		private var _totalPageNumOfSixteen:int = 0;
		private var _curPageNumOfNine:int = 1;
		private var _curPageNumOfSixteen:int = 1;
		private var _curIndex:int = 0;
		private var _curPageMinIndex:int = 0;
		private var _curPageMaxIndex:int = 0;
		private var _curPageStartIndex:int = 0;
		private var _curPageEndIndex:int = 0;
		private var _curVideoX:Number = 0;
		private var _curVideoY:Number = 0;
		private var _curVideoTitleX:Number = 0;
		private var _curVideoTitleY:Number = 0;
		private var _curVideoTimeX:Number = 0;
		private var _curVideoTimeY:Number = 0;
		private var _curVideoTitleTextHeight:Number = 0;
		private var _isNineScreenInterface:Boolean = true;
		private var _playIntervalTime:int = 30;
	
		
		//interval
		private var _lockMouseInterval:Number;
		private var _closeTipInterval:Number;
		private var _closeTipLock:Boolean = false;
		private var _hideTimeSettingInterval:Number;
		private var _hideTimeSettingLock:Boolean = false;
	
		
		//timer
		private var _loadTimer:Timer = new Timer(1);
		private var _loadTimerLock:Boolean = false;
		private var _loopTimer:Timer = new Timer(_playIntervalTime * 1000); 
		private var _updateVideoTimeTimer:Timer = new Timer(1000);
		
		
		//container
		private var _nsContainer:Vector.<NetStream>;
		private var _ncContainer:Vector.<NetConnection>;
		private var _videoBox:Vector.<Video>;
		private var _videoContainer:Vector.<Sprite>;
		private var _playerBGContainer:Vector.<MovieClip>;
		private var _videoTitleContainer:Vector.<TextField>;
		private var _videoTimeContainer:Vector.<TextField>;
		
		
		//load live data
		private var _liveCount:int; 
		private var _liveData:Array;
		private var _liveRequest:URLRequest;
		private var _liveLoader:URLLoader; 
		
		public function MonitorView()
		{
			init();
		}
		
		/**
		 *
		 * 控件说明
		 * MultiScreenUI ：两帧动画，frameRate1对应9画面背景界面， frameRate2对应16画面背景界面
		 * nineBtn ：9画面按钮
		 * sixteenBtn ：16画面按钮
		 * playMethod ：轮播方式按钮，两帧动画，分别对应自动轮播和手动轮播
		 * gobackBtn ：上一页按钮
		 * gofront ：下一页按钮
		 * pageNumberTxt ：页码显示文本框
		 * fullscreenBtn ：全屏按钮
		 * quitFullscreenBtn : 退出全屏按钮
		 * backErrorTip : TextField , 显示提示信息
		 * timeSettingMC : 轮播时间设置
		 * 
		 */		
		private function init():void
		{
			loadLiveData();
			initControlState();
			addListener();
		}
		
		private function initControlState():void
		{
			this.bottomBar.gobackBtn.visible = false;
			this.bottomBar.gofrontBtn.visible = false;
			this.gotoAndStop(1);
		}
		
		private function addListener():void
		{
			this.bottomBar.changeScreenBtn.nineBtn.addEventListener(MouseEvent.CLICK, onNineBtnClick);
			this.bottomBar.changeScreenBtn.sixteenBtn.addEventListener(MouseEvent.CLICK, onSixteenBtnClick);
			this.bottomBar.playMethod.addEventListener(MouseEvent.CLICK, onPlayMethodClick);
			this.bottomBar.gobackBtn.addEventListener(MouseEvent.CLICK, onGoBackBtnClick);
			this.bottomBar.gofrontBtn.addEventListener(MouseEvent.CLICK, onGoFrontBtnClick);
			this.bottomBar.fullscreenBtn.addEventListener(MouseEvent.CLICK, onFullScreenBtnClick);
			this.bottomBar.quitFullscreenBtn.addEventListener(MouseEvent.CLICK, onQuitFullScreenBtnClick);
			this.bottomBar.timeSettingMC.addEventListener(FocusEvent.FOCUS_IN, onTimeSettingFocusIn);
			this.bottomBar.timeSettingMC.addEventListener(FocusEvent.FOCUS_OUT, onTimeSettingFocusOut);
			this.bottomBar.playMethod.addEventListener(MouseEvent.MOUSE_OVER, onPlayMethodMouseOver);
			this.bottomBar.playMethod.addEventListener(MouseEvent.MOUSE_OUT, onPlayMethodMouseOut);			
			this.addEventListener(Event.REMOVED_FROM_STAGE, destroy);
			
			this._loopTimer.start();
			this._loopTimer.addEventListener(TimerEvent.TIMER, loopTimerTickHandler);
		}
		
		/**
		 *
		 * 获取直播信息 
		 * 
		 */		
		private function loadLiveData():void
		{
			_liveRequest = new URLRequest();
			_liveRequest.url = LiveModel.LIVE_URL;
			_liveLoader = new URLLoader();
			_liveLoader.load(_liveRequest);
			_liveLoader.addEventListener(Event.COMPLETE, onLiveDataLoadComplete);
			_liveLoader.addEventListener(IOErrorEvent.IO_ERROR, onLiveDataLoadIOError);
			_liveLoader.addEventListener(ProgressEvent.PROGRESS, onLiveDataLoadProgress);
		}
		
		protected function onLiveDataLoadProgress(event:ProgressEvent):void
		{
			trace ("加载进度：" + (event.bytesLoaded / event.bytesTotal) * 100 + "%");
		}
		
		protected function onLiveDataLoadIOError(event:IOErrorEvent):void
		{
			trace ("load xml Error:" + event);
		}
		
		/**
		 * 
		 * @param event
		 * 解析数据，创建初始界面
		 *  
		 */		
		protected function onLiveDataLoadComplete(event:Event):void
		{
			parseXML(XML(_liveLoader.data));
			createMainInterface(); 
		}		
		
		protected function parseXML(xml:XML):void
		{
			var data:Array = new Array();
			for each (var live:XML in xml.live)
			{
				var vo:LiveVO = new LiveVO();
				vo.liveID = live.@id.toString();
				vo.liveName = live.@name.toString();
				vo.liveHDURL = live.@HD.toString();  
				vo.liveSDURL = live.@SD.toString();
				data.push(vo);
			}
			this._liveData = data;
			this._liveCount = data.length;
		}
		
		/**
		 *
		 * 创建初始界面 
		 * 
		 */		
		private function createMainInterface():void
		{
			_nsContainer = new Vector.<NetStream>(_liveCount);
			_ncContainer = new Vector.<NetConnection>(_liveCount);
			_videoBox = new Vector.<Video>(_liveCount);
			_videoTitleContainer = new Vector.<TextField>(_liveCount);
			_videoTimeContainer = new Vector.<TextField>(_liveCount);
			_videoContainer = new Vector.<Sprite>();
			
			//初始化相关索引
			_curPageMinIndex = 0;
			_curPageStartIndex = 0;
			this._liveCount <= 9 ? _curPageMaxIndex = _liveCount - 1 : _curPageMaxIndex = 8;
			_curPageEndIndex = _curPageMaxIndex;
			this._isNineScreenInterface = true;
			
			//初始化页码
			figureOutTotalPageNum();
		
			//添加播放器背景到容器中
			initPlayerBGContainer();
			
			//循环添加视频界面
			_loadTimer.start();
			_loadTimer.addEventListener(TimerEvent.TIMER, onLoadTimer);
			
			//更新当前时间
			_updateVideoTimeTimer.start();
			_updateVideoTimeTimer.addEventListener(TimerEvent.TIMER, onUpdateVideoTimeTimer);
		}
		
		/**
		 * 
		 * @param event
		 * 更新当前播放时间
		 * 
		 */		
		private function onUpdateVideoTimeTimer(event:TimerEvent):void
		{
			var _len:int = _videoTimeContainer.length;
			for (var i:int=0; i < _len; i++)
			{
				if (_videoTimeContainer[i])
				{
					_videoTimeContainer[i].text = TimeUtils.dateToTimeFomat();
				}
			}
		}
		
		/**
		 * 
		 * 初始化页码信息
		 *  
		 */		
		private function figureOutTotalPageNum():void
		{
			_liveCount % 9 == 0 ? _totalPageNumOfNine = _liveCount / 9 : _totalPageNumOfNine = _liveCount / 9 + 1;
			_liveCount % 16 == 0 ? _totalPageNumOfSixteen = _liveCount / 16 : _totalPageNumOfSixteen = _liveCount / 16 + 1;
			this.bottomBar.pageNumberTxt.text = String(this._curPageNumOfNine + "/" + _totalPageNumOfNine);
			
			trace ("9分屏共有：" + _totalPageNumOfNine + "页");
			trace ("16分屏共有：" + _totalPageNumOfSixteen + "页");
		}
		
		/**
		 *
		 * 将播放器背景统一管理，方便界面布局 
		 * 
		 */		
		private function initPlayerBGContainer():void
		{
			this._playerBGContainer = new Vector.<MovieClip>();
			this._playerBGContainer.push(this.playerBG1);
			this._playerBGContainer.push(this.playerBG2);
			this._playerBGContainer.push(this.playerBG3);
			this._playerBGContainer.push(this.playerBG4);
			this._playerBGContainer.push(this.playerBG5);
			this._playerBGContainer.push(this.playerBG6);
			this._playerBGContainer.push(this.playerBG7);
			this._playerBGContainer.push(this.playerBG8);
			this._playerBGContainer.push(this.playerBG9);
			if (!_isNineScreenInterface)
			{
				this._playerBGContainer.push(this.playerBG10);
				this._playerBGContainer.push(this.playerBG11);
				this._playerBGContainer.push(this.playerBG12);
				this._playerBGContainer.push(this.playerBG13);
				this._playerBGContainer.push(this.playerBG14);
				this._playerBGContainer.push(this.playerBG15);
				this._playerBGContainer.push(this.playerBG16);
			}
			
			var len:int = _playerBGContainer.length;
			for (var i:int=0; i < len; i++)
			{
				_playerBGContainer[i].gotoAndStop(1);
			}
		}
		
		private function onLoadTimer(event:TimerEvent):void
		{
			if (!this._loadTimerLock)
			{
				this._loadTimerLock = true;
				createLoadInterface();
			}
		}
		
		/**
		 *
		 * 创建视频监控界面 
		 * 
		 */		
		private function createLoadInterface():void
		{
			if (_curPageStartIndex > _curPageEndIndex)  
			{
				this._loadTimer.stop(); 
				this._loadTimer.removeEventListener(TimerEvent.TIMER, onLoadTimer);
				this._loadTimerLock = false;
				
				for (var i:int=_curPageMinIndex; i <= _curPageMaxIndex; i++)
				{
					_nsContainer[i].resume();
				}
				
				//控制无信号视频背景提示切换
				var _bgLength:int = this._curPageMaxIndex - this._curPageMinIndex + 1;
				if (this._isNineScreenInterface)
				{
					if (_bgLength < 9)
					{
						for (var index:int=_bgLength; index<_playerBGContainer.length; index++)
						{
							_playerBGContainer[index].gotoAndStop(2);
						}
					}
				}
				else
				{
					if (_bgLength < 16)
					{
						for (var index2:int=_bgLength; index2<_playerBGContainer.length; index2++)
						{
							_playerBGContainer[index2].gotoAndStop(2);
						}
					}
				}
					
				//控制标题、事件文本显示
				var _titleLength:int = _videoTitleContainer.length
				for (var j:int=0; j<_titleLength; j++)
				{
					if (_videoTitleContainer[j])
					{
						_videoTitleContainer[j].visible = true;
					}
				}
				
				var _timeLength:int = _videoTimeContainer.length
				for (var k:int=0; k<_timeLength; k++)
				{
					if (_videoTimeContainer[k])
					{
						_videoTimeContainer[k].visible = true;
					}
				}
				return;
			}
			
			//添加播放器
			this._videoBox[_curPageStartIndex] = new Video();
			this._videoBox[_curPageStartIndex].width = this._playerBGContainer[_curIndex].width;
			this._videoBox[_curPageStartIndex].height = this._playerBGContainer[_curIndex].height;
			this._videoBox[_curPageStartIndex].x = this._playerBGContainer[_curIndex].x;
			this._videoBox[_curPageStartIndex].y = this._playerBGContainer[_curIndex].y;
			this._videoBox[_curPageStartIndex].name = "videoBox" + _curPageStartIndex;
			
			//添加标题
			this._videoTitleContainer[_curPageStartIndex] = new TextField();
			this._videoTitleContainer[_curPageStartIndex].autoSize = TextFieldAutoSize.LEFT;
			this._videoTitleContainer[_curPageStartIndex].x = this._videoBox[_curPageStartIndex].x;
			this._videoTitleContainer[_curPageStartIndex].y = this._videoBox[_curPageStartIndex].y;
			this._videoTitleContainer[_curPageStartIndex].text = _liveData[_curPageStartIndex].liveName;
			this._videoTitleContainer[_curPageStartIndex].setTextFormat(new TextFormat("微软雅黑", 12, 0x00FF00, true));
			this._curVideoTitleTextHeight = this._videoTitleContainer[_curPageStartIndex].textHeight;
			this._videoTitleContainer[_curPageStartIndex].name = "videoTitle" + _curPageStartIndex;
			this._videoTitleContainer[_curPageStartIndex].selectable = false;
			this._videoTitleContainer[_curPageStartIndex].visible = false;
			
			//添加时间
			this._videoTimeContainer[_curPageStartIndex] = new TextField();
			this._videoTimeContainer[_curPageStartIndex].autoSize = TextFieldAutoSize.LEFT;
			this._videoTimeContainer[_curPageStartIndex].x = this._videoBox[_curPageStartIndex].x;
			this._videoTimeContainer[_curPageStartIndex].y = this._videoTitleContainer[_curPageStartIndex].y + this._videoTitleContainer[_curPageStartIndex].textHeight;
			this._videoTimeContainer[_curPageStartIndex].text = TimeUtils.dateToTimeFomat();
			this._videoTimeContainer[_curPageStartIndex].setTextFormat(new TextFormat("微软雅黑", 10, 0x00FF00, true));
			this._videoTimeContainer[_curPageStartIndex].defaultTextFormat = new TextFormat("微软雅黑", 10, 0x00FF00, true);
			this._videoTimeContainer[_curPageStartIndex].name = "videoTime" + _curPageStartIndex;
			this._videoTimeContainer[_curPageStartIndex].selectable = false;
			this._videoTimeContainer[_curPageStartIndex].visible = false;	
		
			//添加到舞台
			this._videoContainer[_curIndex] = new Sprite();
			this._videoContainer[_curIndex].addChild(this._videoBox[_curPageStartIndex]);
			this._videoContainer[_curIndex].addChild(this._videoTitleContainer[_curPageStartIndex]);
			this._videoContainer[_curIndex].addChild(this._videoTimeContainer[_curPageStartIndex]);
			this.addChild(this._videoContainer[_curIndex]);
			
			//添加缩放处理监听
			this._videoContainer[_curIndex].buttonMode = true;
			this._videoContainer[_curIndex].addEventListener(MouseEvent.CLICK, onVideoContainerMouseClick);
			this._videoTitleContainer[_curPageStartIndex].addEventListener(MouseEvent.CLICK, onTextFieldClick);
			this._videoTimeContainer[_curPageStartIndex].addEventListener(MouseEvent.CLICK, onTextFieldClick);
			
			//建立连接
			connect();
		}
		
		/**
		 * 
		 * @param event
		 * 阻断文本框点击事件
		 * 
		 */		
		private function onTextFieldClick(event:MouseEvent):void
		{
			event.stopImmediatePropagation();
			event.preventDefault();
			event.stopPropagation();
		}
		
		/**
		 * 
		 * @param event
		 * 响应鼠标点击播放器放大缩小功能
		 * 
		 */
		private function onVideoContainerMouseClick(event:MouseEvent):void
		{
			var target:Sprite = event.target as Sprite;
			var index:int = getIndexByVideoBox(target);
			var videoName:String = String("videoBox" + index);
			var videoTitle:String = String("videoTitle" + index);
			var videoTime:String = String("videoTime" + index);
			var targetVideo:Video = event.target.getChildByName(videoName);
			var targetVideoTitle:TextField = (event.target as Sprite).getChildByName(videoTitle) as TextField;
			var targetVideoTime:TextField = (event.target as Sprite).getChildByName(videoTime) as TextField;
			
			this.mouseEnabled = false;
			this.mouseChildren = false;
			this._lockMouseInterval = setInterval(unlockMouse, 1000);
			
			if (targetVideo.width < 1000){
				
				TweenLite.to(targetVideo, 1, {width : 1000, height : 625});
				TweenLite.to(targetVideo, 1, {x : 0, y : 0});
				TweenLite.to(targetVideoTitle, 1, {x : 0, y : 0});
				TweenLite.to(targetVideoTime, 1, {x : 0, y : targetVideoTitle.textHeight});
				
				this._curVideoX = targetVideo.x;
				this._curVideoY = targetVideo.y;
				this._curVideoTitleX = targetVideo.x;
				this._curVideoTitleY = targetVideo.y;
				this._curVideoTimeX = this._curVideoTitleX;
				this._curVideoTimeY = this._curVideoTitleY + this._curVideoTitleTextHeight;
				
				this.setChildIndex(target, numChildren - 1);
				
				if (index != MonitorView.MAX_INT_VALUE)
				{
					_nsContainer[index].soundTransform = new SoundTransform(0.5);
					//_nsContainer[index].play("mp4:" + this._liveData[index].liveHDURL);
					trace ("=========当前由SD切换到HD===========");
				}
			}
			else
			{
				if (this._isNineScreenInterface)
				{
					TweenLite.to(targetVideo, 1, {width : 330, height : 190});
					TweenLite.to(targetVideo, 1, {x : _curVideoX, y : _curVideoY});
					TweenLite.to(targetVideoTitle, 1, {x : _curVideoTitleX, y : _curVideoTitleY});
					TweenLite.to(targetVideoTime, 1, {x : _curVideoTimeX, y : _curVideoTimeY});
				}
				else
				{
					TweenLite.to(targetVideo, 1, {width : 246.25, height : 141.25});
					TweenLite.to(targetVideo, 1, {x : this._curVideoX, y : this._curVideoY});
					TweenLite.to(targetVideoTitle, 1, {x : _curVideoTitleX, y : _curVideoTitleY});
					TweenLite.to(targetVideoTime, 1, {x : _curVideoTimeX, y : _curVideoTimeY});
				}
				this.setChildIndex(target, numChildren - 1);  
				if (index != MonitorView.MAX_INT_VALUE)
				{
					_nsContainer[index].soundTransform = new SoundTransform(0);
					//_nsContainer[index].play("mp4:" + this._liveData[index].liveSDURL);
					trace ("=========当前由HD切换到SD===========");
				}
			}
		}
		
		private function unlockMouse():void
		{
			this.mouseEnabled = true;
			this.mouseChildren = true;
			clearInterval(_lockMouseInterval);
		}
		
		private function getIndexByVideoBox(target:Sprite):int
		{
			for (var i:int=0; i < _videoBox.length; i++)
			{
				if (_videoBox[i] == target.getChildAt(0) as Video)
				{
					return i; 
				}
			}
			return MAX_INT_VALUE; 
		}
		
		/**
		 *
		 * 建立连接 
		 * 
		 */		
		private function connect():void
		{
			_ncContainer[_curPageStartIndex] = new NetConnection();
			_ncContainer[_curPageStartIndex].client = this;
			_ncContainer[_curPageStartIndex].addEventListener(NetStatusEvent.NET_STATUS, onNetStatus);
			_ncContainer[_curPageStartIndex].addEventListener(IOErrorEvent.IO_ERROR, onIOError);
			_ncContainer[_curPageStartIndex].connect("rtmp://localhost/vod"); 
		}
		
		public function onBWDone():void{}
		
		protected function onIOError(event:IOErrorEvent):void
		{
			trace (event);
		}
		
		private function onNetStatus(event:NetStatusEvent):void
		{
			var name:String = event.info["code"];
			//trace (name);
			switch (name)
			{
				case "NetConnection.Connect.Success":
					    trace (name);
						initNetStream();
					break;
				case "NetConnection.Connect.Closed":
					break;
				default:
					break;
			}
		}
		
		/**
		 *
		 * 添加视频流 
		 * 
		 */		
		private function initNetStream():void
		{
			trace ("initNetStream" + _curPageStartIndex);
			
			_nsContainer[_curPageStartIndex] = new NetStream(_ncContainer[_curPageStartIndex]);  
			_nsContainer[_curPageStartIndex].bufferTime = 5;
			_client.onMetaData = onMetaData;
			_client.onPlayStatus = forNsStatus; 
			_nsContainer[_curPageStartIndex].client = _client; 
			_nsContainer[_curPageStartIndex].inBufferSeek = true;
			_nsContainer[_curPageStartIndex].soundTransform = new SoundTransform(0);
			_nsContainer[_curPageStartIndex].addEventListener(NetStatusEvent.NET_STATUS, onNetStatus);
			_nsContainer[_curPageStartIndex].addEventListener(IOErrorEvent.IO_ERROR, onIOError);
			_videoBox[_curPageStartIndex].attachNetStream(_nsContainer[_curPageStartIndex]);
			_nsContainer[_curPageStartIndex].play("mp4:" + this._liveData[_curPageStartIndex].liveSDURL);
			_nsContainer[_curPageStartIndex].pause();
			_nsContainer[_curPageStartIndex].seek(0);  
			_loadTimerLock = false;
			_curIndex++;	
			_curPageStartIndex++;
		}
		
		private function onMetaData(metadata:Object):void
		{
			//trace (metadata.duration);
		}
		
		private function forNsStatus(info:Object):void
		{
			if (info.code == "NetStream.Play.Complete")
			{
				trace(info.code);
			}
		}
		
		/**
		 * 
		 * @param event
		 * 轮播时间设定
		 * 
		 */		
		private function onTimeSettingFocusIn(event:FocusEvent):void
		{
			if (_hideTimeSettingLock)
			{
				clearInterval(_hideTimeSettingInterval);
				_hideTimeSettingLock = false;
			}
			this.bottomBar.timeSettingMC.visible = true;
			this.bottomBar.timeSettingMC.intervalTimeInputBox.text = "";
		}
		
		/**
		 * 
		 * @param event
		 * 轮播时间设定
		 * 
		 */		
		private function onTimeSettingFocusOut(event:FocusEvent):void
		{
			if (StringUtil.trim(this.bottomBar.timeSettingMC.intervalTimeInputBox.text) == "")
			{
				this.bottomBar.timeSettingMC.intervalTimeInputBox.text = String(this._playIntervalTime);
			}
			else
			{
				this._playIntervalTime = int(this.bottomBar.timeSettingMC.intervalTimeInputBox.text);
			}
			
			if (!_hideTimeSettingLock)
			{
				_hideTimeSettingLock = true;
				_hideTimeSettingInterval = setInterval(hideTimeSetting, 2000);
			}
			
			if (_loopTimer.delay != Number(_playIntervalTime * 1000))
			{
				this._loopTimer.reset();
				this._loopTimer.delay = _playIntervalTime * 1000;
				_loopTimer.start();
				_loopTimer.addEventListener(TimerEvent.TIMER, loopTimerTickHandler);
				this.bottomBar.timeTipMC.timeContentTxt.text = String(_playIntervalTime);
				this.bottomBar.timeTipMC.timeContentTxt.width =  this.bottomBar.timeTipMC.timeContentTxt.textWidth + 6;
				this.bottomBar.timeTipMC.timeContentTxt.x = this.bottomBar.timeTipMC.timeTipTxt.x + this.bottomBar.timeTipMC.timeTipTxt.width;
				this.bottomBar.timeTipMC.timeUnitTxt.x = this.bottomBar.timeTipMC.timeContentTxt.x + this.bottomBar.timeTipMC.timeContentTxt.width;
				this.bottomBar.timeTipMC.visible = true;
				
			}
				
		}
		
		private function hideTimeSetting():void
		{
			this.bottomBar.timeSettingMC.visible = false;
			this.bottomBar.timeTipMC.visible = false;
			clearInterval(_hideTimeSettingInterval);
			_hideTimeSettingInterval = 0;
			_hideTimeSettingLock = false;
		}
			
		
		private function onPlayMethodMouseOver(event:MouseEvent):void
		{
			if (this.bottomBar.playMethod.currentFrame == 1)
			{
				if (_hideTimeSettingInterval)
				{
					clearInterval(_hideTimeSettingInterval);
					_hideTimeSettingInterval = 0;
					_hideTimeSettingLock = false
				}
				this.bottomBar.timeSettingMC.visible = true;
			}
		}
		
		private function onPlayMethodMouseOut(event:MouseEvent):void
		{
			if (_hideTimeSettingInterval)
			{
				clearInterval(_hideTimeSettingInterval);
				_hideTimeSettingInterval = 0;
				_hideTimeSettingLock = false;
			}
			
			if (!_hideTimeSettingLock)
			{
				_hideTimeSettingInterval = setInterval(hideTimeSetting, 2000);
				_hideTimeSettingLock = true;
			}
		}
		
		/**
		 * 
		 * @param event
		 * 跳转到下一页
		 * 
		 */		
		private function loopTimerTickHandler(event:TimerEvent):void
		{
			gotoNextPage();
		}
		
		private function onNineBtnClick(event:MouseEvent):void
		{
			this.gotoAndStop(1);
			createNineScreenInterface();
		}
		
		/**
		 *
		 * 生成9画面 
		 * 
		 */		
		private function createNineScreenInterface():void
		{
			clear();
			this._isNineScreenInterface = true;
			this._loadTimerLock = false;
			this._curIndex = 0;
			this._curPageNumOfNine = getPageNumByCurPageMinIndex();
			this._curPageStartIndex = (this._curPageNumOfNine - 1) * 9;
			this._curPageEndIndex = getEndIndexByCurPageMinIndex();
			this._curPageMinIndex = this._curPageStartIndex;
			this._curPageMaxIndex = this._curPageEndIndex;
			this.pageNumberText = String(this._curPageNumOfNine + "/" + this._totalPageNumOfNine);
			this.initPlayerBGContainer();
			this._loadTimer.reset();
			this._loadTimer.start();
			this._loadTimer.addEventListener(TimerEvent.TIMER, onLoadTimer);
		}
		
		private function onSixteenBtnClick(event:MouseEvent):void
		{
			this.gotoAndStop(2);
			createSixteenScreenInterface();
		}
		
		/**
		 *
		 * 生成16画面视频 
		 * 
		 */		
		private function createSixteenScreenInterface():void
		{
			clear();
			this._isNineScreenInterface = false;
			this._loadTimerLock = false;
			this._curIndex = 0;
			this._curPageNumOfNine = getPageNumByCurPageMinIndex();
			this._curPageStartIndex = (this._curPageNumOfSixteen - 1) * 16;
			this._curPageEndIndex = getEndIndexByCurPageMinIndex();
			this._curPageMinIndex = this._curPageStartIndex;
			this._curPageMaxIndex = this._curPageEndIndex;
			this.pageNumberText = String(this._curPageNumOfSixteen + "/" + this._totalPageNumOfSixteen);
			this.initPlayerBGContainer();
			this._loadTimer.reset();
			this._loadTimer.start();
			this._loadTimer.addEventListener(TimerEvent.TIMER, onLoadTimer);
		}
		
		/**
		 * 
		 * @param event
		 * 切换轮播方式为手动或自动
		 * 
		 */		
		private function onPlayMethodClick(event:MouseEvent):void
		{
			if (this.bottomBar.playMethod.currentFrame == 1)
			{
				this.bottomBar.playMethod.play();
				this.bottomBar.gobackBtn.visible = true;
				this.bottomBar.gofrontBtn.visible = true;
				this.bottomBar.timeSettingMC.visible = false;
				this._loopTimer.stop();
				this._loopTimer.removeEventListener(TimerEvent.TIMER, loopTimerTickHandler);
			}
			else
			{
				this.bottomBar.playMethod.play();
				this.bottomBar.gobackBtn.visible = false;
				this.bottomBar.gofrontBtn.visible = false;
				this.bottomBar.timeSettingMC.visible = true;
				this._loopTimer.reset();
				this._loopTimer.start();
				this._loopTimer.addEventListener(TimerEvent.TIMER, loopTimerTickHandler);
			}
		}
		
		/**
		 * 
		 * @param event
		 *退回到前一页处理
		 *  
		 */		
		private function onGoBackBtnClick(event:MouseEvent):void
		{
			if (this._isNineScreenInterface)
			{
				if (this._curPageNumOfNine == 1)
				{
					this.bottomBar.backErrorTip.visible = true;
					if (!this._closeTipLock)
					{
						this._closeTipLock = true;
						_closeTipInterval = setInterval(closeTip, 1500);
					}
					return;
				}
				else
				{
					clear();
					this._isNineScreenInterface = true;
					this._loadTimerLock = false;
					this._curIndex = 0;
					if (this._curPageNumOfNine > 1)
					{
						this._curPageNumOfNine = getPageNumByCurPageMinIndex() - 1;
					}
					this._curPageStartIndex = (this._curPageNumOfNine - 1) * 9;
					this._curPageEndIndex = getEndIndexByCurPageMinIndex();
					this._curPageMinIndex = this._curPageStartIndex;
					this._curPageMaxIndex = this._curPageEndIndex;
					this.pageNumberText = String(this._curPageNumOfNine + "/" + this._totalPageNumOfNine);
					this.initPlayerBGContainer();
					this._loadTimer.reset();
					this._loadTimer.start();
					this._loadTimer.addEventListener(TimerEvent.TIMER, onLoadTimer);
				}
			}
			else
			{
				if (this._curPageNumOfSixteen == 1)
				{
					this.bottomBar.backErrorTip.visible = true;
					if (!this._closeTipLock)
					{
						this._closeTipLock = true;
						_closeTipInterval = setInterval(closeTip, 1500);
					}
					return;
				}
				else
				{
					clear();
					this._isNineScreenInterface = false;
					this._loadTimerLock = false;
					this._curIndex = 0;
					if (this._curPageNumOfSixteen > 1)
					{
						this._curPageNumOfSixteen = getPageNumByCurPageMinIndex() - 1;
					}
					this._curPageStartIndex = (this._curPageNumOfSixteen - 1) * 16;
					this._curPageEndIndex = getEndIndexByCurPageMinIndex();
					this._curPageMinIndex = this._curPageStartIndex;
					this._curPageMaxIndex = this._curPageEndIndex;
					this.pageNumberText = String(this._curPageNumOfSixteen + "/" + this._totalPageNumOfSixteen);
					this.initPlayerBGContainer();
					this._loadTimer.reset();
					this._loadTimer.start();
					this._loadTimer.addEventListener(TimerEvent.TIMER, onLoadTimer);
				}
			}
		}
		
		private function closeTip():void
		{
			this._closeTipLock = false;
			this.bottomBar.backErrorTip.visible = false;
			clearInterval(_closeTipInterval);
		}
		
		/**
		 * 
		 * @param event
		 * 跳转处理
		 *  
		 */		
		private function onGoFrontBtnClick(event:MouseEvent):void
		{
			gotoNextPage();
		}
		
		/**
		 *
		 * 跳转到后一页 
		 * 
		 */		
		private function gotoNextPage():void
		{
			if (this._isNineScreenInterface)
			{
				clear();
				this._isNineScreenInterface = true;
				this._loadTimerLock = false;
				this._curIndex = 0;
				if (this._curPageNumOfNine < this._totalPageNumOfNine)
				{
					this._curPageNumOfNine = getPageNumByCurPageMinIndex() + 1;
				}
				else
				{
					this._curPageNumOfNine = 1;
				}
				this._curPageStartIndex = (this._curPageNumOfNine - 1) * 9;
				this._curPageEndIndex = getEndIndexByCurPageMinIndex();
				this._curPageMinIndex = this._curPageStartIndex;
				this._curPageMaxIndex = this._curPageEndIndex;
				this.pageNumberText = String(this._curPageNumOfNine + "/" + this._totalPageNumOfNine);
				this.initPlayerBGContainer();
				this._loadTimer.reset();
				this._loadTimer.start();
				this._loadTimer.addEventListener(TimerEvent.TIMER, onLoadTimer);
			}
			else
			{
				clear();
				this._isNineScreenInterface = false;
				this._loadTimerLock = false;
				this._curIndex = 0;
				if (this._curPageNumOfSixteen < this._totalPageNumOfSixteen)
				{
					this._curPageNumOfSixteen = getPageNumByCurPageMinIndex() + 1;
				}
				else
				{
					this._curPageNumOfSixteen = 1;
				}
				this._curPageStartIndex = (this._curPageNumOfSixteen - 1) * 16;
				this._curPageEndIndex = getEndIndexByCurPageMinIndex();
				this._curPageMinIndex = this._curPageStartIndex;
				this._curPageMaxIndex = this._curPageEndIndex;
				this.pageNumberText = String(this._curPageNumOfSixteen + "/" + this._totalPageNumOfSixteen);
				this.initPlayerBGContainer();
				this._loadTimer.reset();
				this._loadTimer.start();
				this._loadTimer.addEventListener(TimerEvent.TIMER, onLoadTimer);
			}
		}
		
		/**
		 * 
		 * @param event
		 *进入全屏
		 *  
		 */		
		private function onFullScreenBtnClick(event:MouseEvent):void
		{
			this.bottomBar.fullscreenBtn.visible = false;
			this.bottomBar.quitFullscreenBtn.visible = true;
			this.width = MonitorView.SCREEN_WIDTH;
			this.height = MonitorView.SCREEN_HEIGHT;
			stage.displayState = StageDisplayState.FULL_SCREEN_INTERACTIVE;
		}
		
		/**
		 * 
		 * @param event
		 * 退出全屏
		 * 
		 */		
		private function onQuitFullScreenBtnClick(event:MouseEvent):void
		{
			this.bottomBar.fullscreenBtn.visible = true;
			this.bottomBar.quitFullscreenBtn.visible = false;
			this.width = 1000;
			this.height = 625;
			stage.displayState = StageDisplayState.NORMAL;
		}	
		
		/**
		 *
		 * 更新退出全屏后界面位置 
		 * 
		 */		
		public function updateScale():void
		{
			this.width = 1000;
			this.height = 625;
			this.bottomBar.fullscreenBtn.visible = true;
			this.bottomBar.quitFullscreenBtn.visible = false;
			stage.displayState = StageDisplayState.NORMAL;
		}
		
		/**
		 * 
		 * @return 返回当前所在的页数 
		 * 
		 */		
		private function getPageNumByCurPageMinIndex():int
		{
			var _index:int = 0;
			if (this._isNineScreenInterface)
			{
				for (var i:int=0; i < this._totalPageNumOfNine; i++)
				{
					if (this._curPageMinIndex >= (9 * i - 1))
					{
						_index++;
					}
				}
			}
			else
			{
				for (var j:int=0; j < this._totalPageNumOfSixteen; j++)
				{
					if (this._curPageMinIndex >= (16 * j - 1)) 
					{
						_index++;
					}
				}
			}
			return _index;
		}
		
		/**
		 * 
		 * @return 返回当前页最大索引
		 * 
		 */		
		private function getEndIndexByCurPageMinIndex():int
		{
			var index:int = 0;
			if (this._isNineScreenInterface)
			{
				if (_curPageNumOfNine >= _totalPageNumOfNine)
					index = this._liveCount - 1;
				else
					index = this._curPageStartIndex + 8; 
			}
			else
			{
				if (_curPageNumOfSixteen >= _totalPageNumOfSixteen)
					index = this._liveCount - 1;
				else
					index = this._curPageStartIndex + 15; 
			}
			return index;
		}
		
		/**
		 *
		 * 移除播放器界面、事件监听等 
		 * 
		 */		
		private function clear():void
		{
			for (var i:int=0; i < this._liveCount; i++)
			{
				if (_nsContainer[i])
				{
					_nsContainer[i].pause();
					_nsContainer[i].close();
					_nsContainer[i].removeEventListener(NetStatusEvent.NET_STATUS, onNetStatus);
					_nsContainer[i].removeEventListener(IOErrorEvent.IO_ERROR, onIOError);
					_nsContainer[i].soundTransform = null;
					_nsContainer[i] = null;
				}
				
				if (_ncContainer[i])
				{
					_ncContainer[i].close();
					_ncContainer[i].removeEventListener(NetStatusEvent.NET_STATUS, onNetStatus);
					_ncContainer[i].removeEventListener(IOErrorEvent.IO_ERROR, onIOError);
					_ncContainer[i] = null;
				}
			}
			
			if (this._videoContainer)
			{
				for (var j:int=0; j < this._videoContainer.length; j++)
				{
					if (_videoContainer[j])
					{
						var _length:int = _videoContainer[j].numChildren;
						for (var k:int=0; k < _length; k++)
						{
							_videoContainer[j].removeChildAt(0);
							if (_videoContainer[j].numChildren == 0)
							{
								this.removeChild(_videoContainer[j]);
								_videoContainer[j] = null;
							}
						}
					}
				}
			}
		}
		
		/**
		 * 
		 * @param value : 页码文本框显示的内容
		 * 
		 */		
		public function set pageNumberText(value:String):void
		{
			this.bottomBar.pageNumberTxt.text = value;
		}
		
		/**
		 * 
		 * @param type
		 * @param listener
		 * @param useCapture
		 * @param priority
		 * @param useWeakReference
		 * 
		 */		
		override public function addEventListener(type:String, listener:Function, useCapture:Boolean=false, priority:int=0, useWeakReference:Boolean=false):void
		{
			_list.push([type,listener,useCapture])
			super.addEventListener(type,listener,useCapture,priority,useWeakReference)
		}
		
		private function destroy(e:Event):void
		{
			if(e.currentTarget != e.target)return;
			
			//删除子对象
			trace("删除前有子对象",numChildren)
			while(numChildren > 0)
			{
				removeChildAt(0);
			}
			trace("删除后有子对象",numChildren);
			
			//删除动态属性
			for(var k:String in this){
				trace("删除属性",k)
				delete this[k]
			}
			
			//删除侦听
			trace("删除前注册事件数:" + _list.length)
			for(var i:uint=0;i<_list.length;i++){
				trace("删除Listener",_list[i][0])
				removeEventListener(_list[i][0],_list[i][1],_list[i][2])
			}
			_list = null;
		}
	}
}
