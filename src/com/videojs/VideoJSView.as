package com.videojs{

    import com.videojs.events.VideoJSEvent;
    import com.videojs.events.VideoPlaybackEvent;
    import com.videojs.structs.ExternalErrorEventName;

    import flash.display.Bitmap;
    import flash.display.Loader;
    import flash.display.Sprite;
    import flash.events.Event;
    import flash.events.IOErrorEvent;
    import flash.events.SecurityErrorEvent;
    import flash.external.ExternalInterface;
    import flash.geom.Matrix;
    import flash.geom.Rectangle;
    import flash.media.Video;
    import flash.net.URLRequest;
    import flash.system.LoaderContext;

    public class VideoJSView extends Sprite{

        private var _uiVideo:Video;
        private var _uiBackground:Sprite;
        private var _rotation:int = 0;
        public const baseVideoWidth:int = 100;
        public const baseVideoHeight:int = 100;

        private var _model:VideoJSModel;

        public function VideoJSView(){

            _model = VideoJSModel.getInstance();
            _model.addEventListener(VideoJSEvent.BACKGROUND_COLOR_SET, onBackgroundColorSet);
            _model.addEventListener(VideoJSEvent.STAGE_RESIZE, onStageResize);
            _model.addEventListener(VideoPlaybackEvent.ON_META_DATA, onMetaData);
            _model.addEventListener(VideoPlaybackEvent.ON_VIDEO_DIMENSION_UPDATE, onDimensionUpdate);

            _uiBackground = new Sprite();
            _uiBackground.graphics.beginFill(_model.backgroundColor, 1);
            _uiBackground.graphics.drawRect(0, 0, _model.stageRect.width, _model.stageRect.height);
            _uiBackground.graphics.endFill();
            _uiBackground.alpha = _model.backgroundAlpha;
            addChild(_uiBackground);

            _uiVideo = new Video(baseVideoWidth, baseVideoHeight);
            _uiVideo.width = _model.stageRect.width;
            _uiVideo.height = _model.stageRect.height;
            _uiVideo.smoothing = true;
            addChild(_uiVideo);

            _model.videoReference = _uiVideo;
        }


        public function sizeVideoObject():void{
            var __targetWidth:int, __targetHeight:int;

            var __availableWidth:int = _model.stageRect.width;
            var __availableHeight:int = _model.stageRect.height;

            var __nativeWidth:int = 100;

            if(_model.metadata.width != undefined){
                __nativeWidth = Number(_model.metadata.width);
            }

            if(_uiVideo.videoWidth != 0){
                __nativeWidth = _uiVideo.videoWidth;
            }

            var __nativeHeight:int = 100;

            if(_model.metadata.width != undefined){
                __nativeHeight = Number(_model.metadata.height);
            }

            if(_uiVideo.videoWidth != 0){
                __nativeHeight = _uiVideo.videoHeight;
            }

            _rotation = (_rotation % 360 + 360) % 360;
            var __vertical:Boolean = _rotation == 90 || _rotation == 270;
            var __rnw:int = __vertical ? __nativeHeight : __nativeWidth;
            var __rnh:int = __vertical ? __nativeWidth : __nativeHeight;

            // first, size the whole thing down based on the available width
            __targetWidth = __availableWidth;
            __targetHeight = __targetWidth * (__rnh / __rnw);

            if(__targetHeight > __availableHeight){
                __targetWidth = __targetWidth * (__availableHeight / __targetHeight);
                __targetHeight = __availableHeight;
            }

            var dx:int = Math.round((__availableWidth - __targetWidth) / 2);
            var dy:int = Math.round((__availableHeight - __targetHeight) / 2);
            if(_rotation == 90){
                dx = __availableWidth - dx;
            }
            else if(_rotation == 180){
                dx = __availableWidth - dx;
                dy = __availableHeight - dy;
            }
            else if(_rotation == 270){
                dy = __availableHeight - dy;
            }

            var sx:Number = __targetWidth / (__vertical ? baseVideoHeight : baseVideoWidth);
            var sy:Number = __targetHeight / (__vertical ? baseVideoWidth : baseVideoHeight);

            var m:Matrix = new Matrix();
            m.createBox(sx, sy, _rotation/180 * Math.PI, dx, dy);
            _uiVideo.transform.matrix = m;

            //_model.broadcastEventExternally('sizeVideoObject', _rotation, __availableWidth, __availableHeight, __rnw, __rnh, __targetWidth, __targetHeight, _uiVideo.x, _uiVideo.y, _uiVideo.width, _uiVideo.height, _uiVideo.scaleX, _uiVideo.scaleY);
        }

        private function onBackgroundColorSet(e:VideoPlaybackEvent):void{
            _uiBackground.graphics.clear();
            _uiBackground.graphics.beginFill(_model.backgroundColor, 1);
            _uiBackground.graphics.drawRect(0, 0, _model.stageRect.width, _model.stageRect.height);
            _uiBackground.graphics.endFill();
        }

        private function onStageResize(e:VideoJSEvent):void{

            _uiBackground.graphics.clear();
            _uiBackground.graphics.beginFill(_model.backgroundColor, 1);
            _uiBackground.graphics.drawRect(0, 0, _model.stageRect.width, _model.stageRect.height);
            _uiBackground.graphics.endFill();
            sizeVideoObject();
        }

        private function onMetaData(e:VideoPlaybackEvent):void{
            //_model.broadcastEventExternally('onMetaData');
            sizeVideoObject();
        }

        private function onDimensionUpdate(e:VideoPlaybackEvent):void{
            //_model.broadcastEventExternally('onDimensionUpdate');
            sizeVideoObject();
        }

        public function rotate(rotation:int):void{
            _rotation = rotation;
            sizeVideoObject();
        }

        public function get video():Video{
            return _uiVideo;
        }
    }
}
