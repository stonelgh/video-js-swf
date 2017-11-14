package{

    //import mx.graphics.codec.JPEGEncoder;
    import com.adobe.images.JPGEncoder;
    import com.videojs.VideoJSApp;
    import com.videojs.events.VideoJSEvent;
    import com.videojs.structs.ExternalEventName;
    import com.videojs.structs.ExternalErrorEventName;
    import com.videojs.Base64;
    import flash.display.BitmapData;
    import flash.display.Sprite;
    import flash.display.StageAlign;
    import flash.display.StageScaleMode;
    import flash.media.Video;
    import flash.events.Event;
    import flash.events.IOErrorEvent;
    import flash.events.MouseEvent;
    import flash.events.TimerEvent;
    import flash.external.ExternalInterface;
    import flash.geom.Matrix;
    import flash.geom.Rectangle;
    import flash.net.FileReference;
    import flash.net.NetStream;
    import flash.net.URLLoader;
    import flash.net.URLRequest;
    import flash.net.URLRequestHeader;
    import flash.net.URLRequestMethod;
    import flash.net.URLVariables;
    import flash.system.Security;
    import flash.ui.ContextMenu;
    import flash.ui.ContextMenuItem;
    import flash.utils.ByteArray;
    import flash.utils.Timer;
    import flash.utils.setTimeout;

    [SWF(backgroundColor="#000000", frameRate="60", width="480", height="270")]
    public class VideoJS extends Sprite{

        public const VERSION:String = CONFIG::version;

        private var _app:VideoJSApp;
        private var _stageSizeTimer:Timer;

        public function VideoJS(){
            _stageSizeTimer = new Timer(250);
            _stageSizeTimer.addEventListener(TimerEvent.TIMER, onStageSizeTimerTick);
            addEventListener(Event.ADDED_TO_STAGE, onAddedToStage);
        }

        private function init():void{
            // Allow JS calls from other domains
            Security.allowDomain("*");
            Security.allowInsecureDomain("*");

            if(loaderInfo.hasOwnProperty("uncaughtErrorEvents")){
                // we'll want to suppress ANY uncaught debug errors in production (for the sake of ux)
                // IEventDispatcher(loaderInfo["uncaughtErrorEvents"]).addEventListener("uncaughtError", onUncaughtError);
            }

            if(ExternalInterface.available){
                registerExternalMethods();
            }

            _app = new VideoJSApp();
            addChild(_app);

            _app.model.stageRect = new Rectangle(0, 0, stage.stageWidth, stage.stageHeight);

            // add content-menu version info

            var _ctxVersion:ContextMenuItem = new ContextMenuItem("VideoJS Flash Component v" + VERSION, false, false);
            var _ctxAbout:ContextMenuItem = new ContextMenuItem("Copyright © 2014 Brightcove, Inc.", false, false);
            var _ctxMenu:ContextMenu = new ContextMenu();
            _ctxMenu.hideBuiltInItems();
            //_ctxMenu.customItems.push(_ctxVersion, _ctxAbout);
            this.contextMenu = _ctxMenu;
        }

        private function registerExternalMethods():void{
            ExternalInterface.marshallExceptions = true;
            try{
                ExternalInterface.addCallback("vjs_appendBuffer", onAppendBufferCalled);
                ExternalInterface.addCallback("vjs_appendChunkReady", onAppendChunkReadyCalled);
                ExternalInterface.addCallback("vjs_echo", onEchoCalled);
                ExternalInterface.addCallback("vjs_endOfStream", onEndOfStreamCalled);
                ExternalInterface.addCallback("vjs_abort", onAbortCalled);
                ExternalInterface.addCallback("vjs_discontinuity", onDiscontinuityCalled);

                ExternalInterface.addCallback("vjs_getProperty", onGetPropertyCalled);
                ExternalInterface.addCallback("vjs_setProperty", onSetPropertyCalled);
                ExternalInterface.addCallback("vjs_autoplay", onAutoplayCalled);
                ExternalInterface.addCallback("vjs_src", onSrcCalled);
                ExternalInterface.addCallback("vjs_load", onLoadCalled);
                ExternalInterface.addCallback("vjs_play", onPlayCalled);
                ExternalInterface.addCallback("vjs_pause", onPauseCalled);
                ExternalInterface.addCallback("vjs_resume", onResumeCalled);
                ExternalInterface.addCallback("vjs_stop", onStopCalled);

                // This callback should only be used when in data generation mode as it
                // will adjust the notion of current time without notifiying the player
                ExternalInterface.addCallback("vjs_adjustCurrentTime", onAdjustCurrentTimeCalled);

                ExternalInterface.addCallback("getProperty", onGetPropertyCalled);
                ExternalInterface.addCallback("setProperty", onSetPropertyCalled);
                ExternalInterface.addCallback("play", onPlayCalled);
                ExternalInterface.addCallback("pause", onPauseCalled);
                ExternalInterface.addCallback("resume", onResumeCalled);
                ExternalInterface.addCallback("stop", onStopCalled);
                ExternalInterface.addCallback("snapshot", onSnapshotCalled);
                ExternalInterface.addCallback("setClick", onSetClickCalled);
                ExternalInterface.addCallback("detectStall", onDetectStallCalled);
                ExternalInterface.addCallback("sync", onSyncCalled);
                ExternalInterface.addCallback("step", onStepCalled);
                ExternalInterface.addCallback("seekRelative", onSeekRelativeCalled);
            }
            catch(e:SecurityError){
                if (loaderInfo.parameters.debug != undefined && loaderInfo.parameters.debug == "true") {
                    throw new SecurityError(e.message);
                }
            }
            catch(e:Error){
                if (loaderInfo.parameters.debug != undefined && loaderInfo.parameters.debug == "true") {
                    throw new Error(e.message);
                }
            }
            finally{}



            setTimeout(finish, 50);

        }

        private function finish():void{

            if(loaderInfo.parameters.mode != undefined){
                _app.model.mode = loaderInfo.parameters.mode;
            }

            // Hard coding these in for now until we can come up with a better solution for 5.0 to avoid XSS.
            _app.model.jsEventProxyName = 'videojs.Flash.onEvent';
            _app.model.jsErrorEventProxyName = 'videojs.Flash.onError';

            /*if(loaderInfo.parameters.eventProxyFunction != undefined){
                _app.model.jsEventProxyName = loaderInfo.parameters.eventProxyFunction;
            }

            if(loaderInfo.parameters.errorEventProxyFunction != undefined){
                _app.model.jsErrorEventProxyName = loaderInfo.parameters.errorEventProxyFunction;
            }*/

            if(loaderInfo.parameters.autoplay != undefined && loaderInfo.parameters.autoplay == "true"){
                _app.model.autoplay = true;
            }

            if(loaderInfo.parameters.preload != undefined && loaderInfo.parameters.preload != ""){
                _app.model.preload = String(loaderInfo.parameters.preload);
            }

            if(loaderInfo.parameters.muted != undefined && loaderInfo.parameters.muted == "true"){
                _app.model.muted = true;
            }

            if(loaderInfo.parameters.loop != undefined && loaderInfo.parameters.loop == "true"){
                _app.model.loop = true;
            }

            if(loaderInfo.parameters.src != undefined && loaderInfo.parameters.src != ""){
              if (isExternalMSObjectURL(loaderInfo.parameters.src)) {
                _app.model.srcFromFlashvars = null;
                openExternalMSObject(loaderInfo.parameters.src);
              } else {
                _app.model.srcFromFlashvars = String(loaderInfo.parameters.src);
              }
            } else{
              if(loaderInfo.parameters.rtmpConnection != undefined && loaderInfo.parameters.rtmpConnection != ""){
                _app.model.rtmpConnectionURL = loaderInfo.parameters.rtmpConnection;
              }

              if(loaderInfo.parameters.rtmpStream != undefined && loaderInfo.parameters.rtmpStream != ""){
                _app.model.rtmpStream = loaderInfo.parameters.rtmpStream;
              }
            }

            // Hard coding this in for now until we can come up with a better solution for 5.0 to avoid XSS.
            ExternalInterface.call('videojs.Flash.onReady', ExternalInterface.objectID);

            /*if(loaderInfo.parameters.readyFunction != undefined){
              try{
                ExternalInterface.call(_app.model.cleanEIString(loaderInfo.parameters.readyFunction), ExternalInterface.objectID);
              }
              catch(e:Error){
                if (loaderInfo.parameters.debug != undefined && loaderInfo.parameters.debug == "true") {
                  throw new Error(e.message);
                }
              }
            }*/
        }

        private function onAddedToStage(e:Event):void{
            //stage.addEventListener(MouseEvent.CLICK, onStageClick);
            stage.addEventListener(Event.RESIZE, onStageResize);
            stage.scaleMode = StageScaleMode.NO_SCALE;
            stage.align = StageAlign.TOP_LEFT;
            _stageSizeTimer.start();
        }

        private function onStageSizeTimerTick(e:TimerEvent):void{
            if(stage.stageWidth > 0 && stage.stageHeight > 0){
                _stageSizeTimer.stop();
                _stageSizeTimer.removeEventListener(TimerEvent.TIMER, onStageSizeTimerTick);
                init();
            }
        }

        private function onStageResize(e:Event):void{
            if(_app != null){
                _app.model.stageRect = new Rectangle(0, 0, stage.stageWidth, stage.stageHeight);
                _app.model.broadcastEvent(new VideoJSEvent(VideoJSEvent.STAGE_RESIZE, {}));
                //_app.model.broadcastEventExternally('onStageResize', _app.model.stageRect.width, _app.model.stageRect.height);
            }
        }

        private function onAppendBufferCalled(base64str:String):void{
            var bytes:ByteArray = Base64.decode(base64str);
            // write the bytes to the provider
            _app.model.appendBuffer(bytes);
        }

        private function onAppendChunkReadyCalled(fnName:String):void{
            var bytes:ByteArray = Base64.decode(ExternalInterface.call(fnName));

            // write the bytes to the provider
            _app.model.appendBuffer(bytes);
        }

        private function onAdjustCurrentTimeCalled(pValue:Number):void {
            _app.model.adjustCurrentTime(pValue);
        }

        private function onEchoCalled(pResponse:* = null):*{
            return pResponse;
        }

        private function onEndOfStreamCalled():*{
            _app.model.endOfStream();
        }

        private function onAbortCalled():*{
            _app.model.abort();
        }

        private function onDiscontinuityCalled():*{
            _app.model.discontinuity();
        }

        private function onGetPropertyCalled(pPropertyName:String = ""):*{

            switch(pPropertyName){
                case "mode":
                    return _app.model.mode;
                case "autoplay":
                    return _app.model.autoplay;
                case "loop":
                    return _app.model.loop;
                case "preload":
                    return _app.model.preload;
                    break;
                case "metadata":
                    return _app.model.metadata;
                    break;
                case "duration":
                    return _app.model.duration;
                    break;
                case "eventProxyFunction":
                    return _app.model.jsEventProxyName;
                    break;
                case "errorEventProxyFunction":
                    return _app.model.jsErrorEventProxyName;
                    break;
                case "currentSrc":
                    return _app.model.src;
                    break;
                case "currentTime":
                    return _app.model.time;
                    break;
                case "time":
                    return _app.model.time;
                    break;
                case "initialTime":
                    return 0;
                    break;
                case "defaultPlaybackRate":
                    return 1;
                    break;
                case "ended":
                    return _app.model.hasEnded;
                    break;
                case "volume":
                    return _app.model.volume;
                    break;
                case "muted":
                    return _app.model.muted;
                    break;
                case "paused":
                    return _app.model.paused;
                    break;
                case "seeking":
                    return _app.model.seeking;
                    break;
                case "networkState":
                    return _app.model.networkState;
                    break;
                case "readyState":
                    return _app.model.readyState;
                    break;
                case "buffered":
                    return _app.model.buffered;
                    break;
                case "bufferedBytesStart":
                    return 0;
                    break;
                case "bufferedBytesEnd":
                    return _app.model.bufferedBytesEnd;
                    break;
                case "bytesTotal":
                    return _app.model.bytesTotal;
                    break;
                case "videoWidth":
                    return _app.model.videoWidth;
                    break;
                case "videoHeight":
                    return _app.model.videoHeight;
                    break;
                case "rtmpConnection":
                    return _app.model.rtmpConnectionURL;
                    break;
                case "rtmpStream":
                    return _app.model.rtmpStream;
                    break;
                case "getVideoPlaybackQuality":
                    return _app.model.videoPlaybackQuality;
                    break;
                case "bufferTime":
                    if(_app.model.provider && _app.model.provider.netStream)
                        return _app.model.provider.netStream.bufferTime;
                    break;
                case "bufferTimeMax":
                    if(_app.model.provider && _app.model.provider.netStream)
                        return _app.model.provider.netStream.bufferTimeMax;
                    break;
                case "bufferLength":
                    if(_app.model.provider && _app.model.provider.netStream)
                        return _app.model.provider.netStream.bufferLength;
                    break;
                case "inBufferSeek":
                    if(_app.model.provider && _app.model.provider.netStream)
                        return _app.model.provider.netStream.inBufferSeek;
                    break;
            }
            return null;
        }

        private function onSetPropertyCalled(pPropertyName:String = "", pValue:* = null):void{
            switch(pPropertyName){
                case "duration":
                    _app.model.duration = Number(pValue);
                    break;
                case "mode":
                    _app.model.mode = String(pValue);
                    break;
                case "loop":
                    _app.model.loop = _app.model.humanToBoolean(pValue);
                    break;
                case "background":
                    _app.model.backgroundColor = _app.model.hexToNumber(String(pValue));
                    _app.model.backgroundAlpha = 1;
                    break;
                case "eventProxyFunction":
                    _app.model.jsEventProxyName = String(pValue);
                    break;
                case "errorEventProxyFunction":
                    _app.model.jsErrorEventProxyName = String(pValue);
                    break;
                case "autoplay":
                    _app.model.autoplay = _app.model.humanToBoolean(pValue);
                    if (_app.model.autoplay) {
                        _app.model.preload = "auto";
                    }
                    break;
                case "preload":
                    _app.model.preload = String(pValue);
                    break;
                case "src":
                    // same as when vjs_src() is called directly
                    onSrcCalled(pValue);
                    break;
                case "currentTime":
                    _app.model.seekBySeconds(Number(pValue));
                    break;
                case "currentPercent":
                    _app.model.seekByPercent(Number(pValue));
                    break;
                case "muted":
                    _app.model.muted = _app.model.humanToBoolean(pValue);
                    break;
                case "volume":
                    _app.model.volume = Number(pValue);
                    break;
                case "rtmpConnection":
                    _app.model.rtmpConnectionURL = String(pValue);
                    break;
                case "rtmpStream":
                    _app.model.rtmpStream = String(pValue);
                    break;
                case "bufferTime":
                    if(_app.model.provider && _app.model.provider.netStream)
                        _app.model.provider.netStream.bufferTime = Number(pValue);
                    break;
                case "bufferTimeMax":
                    if(_app.model.provider && _app.model.provider.netStream)
                        _app.model.provider.netStream.bufferTimeMax = Number(pValue);
                    break;
                case "inBufferSeek":
                    if(_app.model.provider && _app.model.provider.netStream)
                        _app.model.provider.netStream.inBufferSeek = _app.model.humanToBoolean(pValue);
                    break;
                default:
                    _app.model.broadcastErrorEventExternally(ExternalErrorEventName.PROPERTY_NOT_FOUND, pPropertyName);
                    break;
            }
        }

        private function onAutoplayCalled(pAutoplay:* = false):void{
          _app.model.autoplay = _app.model.humanToBoolean(pAutoplay);
        }

        private function isExternalMSObjectURL(pSrc:*):Boolean{
          return pSrc.indexOf('blob:vjs-media-source/') === 0;
        }

        private function openExternalMSObject(pSrc:*):void{
          var cleanSrc:String
          if (/^blob:vjs-media-source\/\d+$/.test(pSrc)) {
            cleanSrc = pSrc;
          } else {
            cleanSrc = _app.model.cleanEIString(pSrc);
          }
          ExternalInterface.call('videojs.MediaSource.open', cleanSrc, ExternalInterface.objectID);
        }

        private function onSrcCalled(pSrc:* = ""):void{
          // check if an external media source object will provide the video data
          if (isExternalMSObjectURL(pSrc)) {
            // null is passed to the netstream which enables appendBytes mode
            _app.model.src = null;
            // open the media source object for creating a source buffer
            // and provide a reference to this swf for passing data from the soure buffer
            openExternalMSObject(pSrc);

            // ExternalInterface.call('videojs.MediaSource.sourceBufferUrls["' + pSrc + '"]', ExternalInterface.objectID);
          } else {
            _app.model.src = String(pSrc);
          }
        }

        private function onLoadCalled():void{
            _app.model.load();
        }

        private function onPlayCalled():void{
            _app.model.play();
            if (_stallTimer) {
                startStallTimer();
            }
        }

        private function onPauseCalled():void{
            _app.model.pause();
            if (_stallTimer)
                _stallTimer.stop();
        }

        private function onResumeCalled():void{
            _app.model.resume();
            if (_stallTimer) {
                startStallTimer();
            }
        }

        private function onStopCalled():void{
            _app.model.stop();
            if (_stallTimer) {
                _stallTimer.stop();
            }
        }

        private function onSyncCalled():void{
            var muted = _app.model.muted;
            _app.model.destroy();
            if (_stallTimer) {
                _stallTimer.stop();
            }

            removeChild(_app);
            _app = new VideoJSApp();
            addChild(_app);
            _app.model.stageRect = new Rectangle(0, 0, stage.stageWidth, stage.stageHeight);
            //setTimeout(finish, 50);
            finish();
            _app.model.muted = muted;

            if (_stallTimer) {
                startStallTimer();
            }
        }

        //private var _img:ByteArray;
        private function onSnapshotCalled(path:String = ""):String{
            //Security.loadPolicyFile("xmlsocket://localhost:843");
            //Security.loadPolicyFile("http://localhost:8081/crossdomain.xml");

            var jpgEncoder:JPGEncoder;
            jpgEncoder = new JPGEncoder(90);
            var video:Video = _app.view.video;
            var rect:Rectangle = video.getRect(video);
            //_app.model.broadcastEventExternally("onSnapshotCalled-video", video.width, video.height);
            //_app.model.broadcastEventExternally("onSnapshotCalled-videoRect", rect.width, rect.height);
            //_app.model.broadcastEventExternally('onSnapshotCalled-model.stageRect', _app.model.stageRect.width, _app.model.stageRect.height);
            //_app.model.broadcastEventExternally('onSnapshotCalled-stageRect', stage.getRect(stage).width, stage.getRect(stage).height);
            var bitmapData:BitmapData = new BitmapData(video.videoWidth, video.videoHeight);
            try {
                var m:Matrix = new Matrix();
                m.scale(bitmapData.width/rect.width, bitmapData.height/rect.height);
                bitmapData.draw(video, m);
            }
            catch(e:SecurityError){
                _app.model.broadcastEventExternally("snapshot-bitmapData.draw-SecurityError", e.message);
                throw e;
            }
            catch(e:ArgumentError){
                _app.model.broadcastEventExternally("snapshot-bitmapData.draw-ArgumentError", e.message);
                throw e;
            }
            var img:ByteArray = jpgEncoder.encode(bitmapData);
            if (path == "") {
                _app.model.broadcastEventExternally('snapshot');
                return Base64.encode(img);
            }

            if (/^https?:\/\//i.test(path)) {
                //var v:URLVariables = new URLVariables();
                //for (var i:int = 0; i<fields.length; i++) {
                //    var p:Array = fields[i];
                //    v[p[0]] = p[1];
                //}

                var sendHeader:URLRequestHeader = new URLRequestHeader("Content-type", "application/octet-stream");
                var sendReq:URLRequest = new URLRequest(path);

                sendReq.requestHeaders.push(sendHeader);
                sendReq.method = URLRequestMethod.POST;
                sendReq.data = img;

                var sendLoader:URLLoader;
                sendLoader = new URLLoader();
                sendLoader.addEventListener(Event.COMPLETE, completeHandler);
                sendLoader.load(sendReq);
            }
            else {
                var file:FileReference = new FileReference();
                file.addEventListener(IOErrorEvent.IO_ERROR, ioErrorHandler);
                file.addEventListener(Event.COMPLETE, completeHandler);
                try {
                    file.save(img, path);
                }
                catch(e:Error){
                    //_img = img;
                    //_app.model.broadcastEventExternally("snapshot", "Auto save failed. Click video to save locally");
                    //ExternalInterface.call('alert', 'Auto save failed. Click video to retry');
                }
            }

            return "";
        }

        private function ioErrorHandler(event:IOErrorEvent):void{
            _app.model.broadcastEventExternally('snapshotComplete', event);
        }

        private function completeHandler(event:Event):void{
            _app.model.broadcastEventExternally('snapshotComplete', event);
        }

        private function onUncaughtError(e:Event):void{
            e.preventDefault();
        }

        private var _clickAction:String = "";

        private function onSetClickCalled(action:String = ""):void{
            stage.removeEventListener(MouseEvent.CLICK, onStageClick);
            stage.addEventListener(MouseEvent.CLICK, onStageClick);
            _clickAction = action;
        }

        private function onStageClick(e:MouseEvent):void{
            if(_clickAction.indexOf("stat") > -1) {
                // Set the bufferTimeMax property to enable live buffered stream catch-up
                // Live content When streaming live content, set the bufferTime property to 0.
                _app.model.broadcastEventExternally('time', _app.model.provider.netStream.time);
                _app.model.broadcastEventExternally('bufferTime', _app.model.provider.netStream.bufferTime);
                _app.model.broadcastEventExternally('bufferTimeMax', _app.model.provider.netStream.bufferTimeMax);
                _app.model.broadcastEventExternally('bufferLength', _app.model.provider.netStream.bufferLength);
                _app.model.broadcastEventExternally('liveDelay', _app.model.provider.netStream.liveDelay);
                var lag:int = _app.model.provider.netStream.bufferLength - _app.model.provider.netStream.bufferTime;
                _app.model.broadcastEventExternally('lag', lag);
                //_app.model.broadcastEventExternally('client', _app.model.provider.netStream.client);
                //_app.model.broadcastEventExternally('client is netstream', _app.model.provider.netStream.client == _app.model.provider.netStream);
                var video:Video = _app.view.video;
                //_app.model.broadcastEventExternally('stage', stage.width, stage.height);
                //_app.model.broadcastEventExternally('app', _app.width, _app.height);
                //_app.model.broadcastEventExternally('view', _app.view.width, _app.view.height);
                //_app.model.broadcastEventExternally('video', video.width, video.height);
                //_app.model.broadcastEventExternally('actual', video.videoWidth, video.videoHeight);
            }
            if(_clickAction.indexOf("snapshot") > -1) {
                onSnapshotCalled("dummy");
            }
        }

        private var _stallTimer:Timer = null;
        private var _stallListener:String = "";
        private var _stallTmo:int = 30000;
        private var _lastVideoTime:Number = 0; // number of seconds
        private var _lastRecordTime:Date = new Date();

        private function onDetectStallCalled(listener:String = "", tmo:int = 30):void{
            if (tmo < 10)
                tmo = 10;
            _stallTmo = tmo;
            _stallListener = listener;

            tmo = _stallTmo * 1000 / 3;
            if (_app.model.provider && _app.model.provider.netStream) {
                var bufmax:int = _app.model.provider.netStream.bufferTimeMax * 1000;
                if(bufmax > 0) {
                    bufmax = bufmax >= 6000 ? bufmax / 2 : bufmax;
                    bufmax = bufmax < 3000 ? 3000 : bufmax;
                    tmo = tmo > bufmax ? bufmax : tmo;
                }
            }
            if (!_stallTimer) {
                _stallTimer = new Timer(tmo);
                _stallTimer.addEventListener(TimerEvent.TIMER, onStallTimer);
            }

            if(_stallTimer.delay != tmo)
                _stallTimer.delay = tmo;
            if (listener == "" && _stallTimer.running) {
                _stallTimer.stop();
            }
            else if (listener != "" && !_stallTimer.running) {
                startStallTimer();
            }
        }

        private function startStallTimer():void {
            updateStallRecord();
            _stallTimer.start();
        }

        private function updateStallRecord():void {
            if(_app) {
                _lastVideoTime = _app.model.time;
            }
            _lastRecordTime = new Date();
            //_app.model.broadcastEventExternally('updateStallRecord', _lastVideoTime, _lastRecordTime.toTimeString());
        }

        private function onStallTimer(evt:Event):void {
            var now:Date = new Date();
            if (_app.model.provider && _app.model.provider.netStream) {
                var ns:NetStream = _app.model.provider.netStream;
                if (ns.bufferTimeMax > 0 && ns.bufferLength > ns.bufferTimeMax) {
                    ExternalInterface.call(_stallListener, ExternalInterface.objectID, 'lag');
                    //_app.model.broadcastEventExternally('lag detected', ns.bufferLength, ns.bufferTimeMax);
                }
            }
            if (_app.model.time == _lastVideoTime &&
                now.getTime() - _lastRecordTime.getTime() > _stallTmo * 1000) {
                if(ExternalInterface.available) {
                    ExternalInterface.call(_stallListener, ExternalInterface.objectID, 'stall');
                }
                //_app.model.broadcastEventExternally('Stall detected', _stallListener, _lastVideoTime, _lastRecordTime.toTimeString());
                updateStallRecord();
            }
            if (_app.model.time != _lastVideoTime) {
                updateStallRecord();
            }
        }

        // step forward/backward number of frames
        // valid only when NetStream.inBufferSeek is true and server supports smart seeking.
        private function onStepCalled(frames:int = 10):void{
            if(_app.model.provider && _app.model.provider.netStream)
                _app.model.provider.netStream.step(frames);
        }

        // unit of offset is seconds.
        private function onSeekRelativeCalled(offset:int = 1):void{
            if (_app.model.provider && _app.model.provider.netStream) {
                var time:int = _app.model.provider.netStream.time;
                _app.model.provider.netStream.seek(time + offset);
            }
        }
    }
}
