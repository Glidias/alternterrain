package examples
{
    import com.greensock.loading.core.LoaderCore;
    import com.greensock.loading.ImageLoader;
    import com.greensock.loading.LoaderMax;
    import flash.display.Bitmap;
    import flash.display.BitmapData;
    import flash.display.DisplayObject;
    import flash.display.Graphics;
    import flash.display.Sprite;
    import flash.display.StageAlign;
    import flash.display.StageScaleMode;
    import flash.events.Event;
    import flash.geom.Point;
    import flash.geom.Rectangle;
    import flash.text.TextField;
    
    /**
     * Planning out terrain paging scheme across nested hierarchical grids. 
     * 
     * Currently, this is a debug mode sprite in 2D for testing..
     * 
     * @author Glenn Ko
     */
    public class TerrainQueryBox extends Sprite
    {
        public const BASE_PATCH:int = 4;  // increase this for more page loads from within the center
        public const QUERY_SIZE:int = 256;
        
        private var boundingSpace:Rectangle = new Rectangle(0, 0, 2048, 1024);
        private var boundingTiles:Rectangle = new Rectangle(boundingSpace.x/32, boundingSpace.y/32, boundingSpace.width / 32, boundingSpace.height / 32);
        private var offset6:Vector.<int>= new Vector.<int>(6*4, true);
        
        private var _lmx:int = -int.MAX_VALUE;
        private var _lmy:int = -int.MAX_VALUE;
        
        private var testLoadingLayer:Sprite = new Sprite();
        private var graphicsLayer:Sprite = new Sprite();
        override public function get graphics():Graphics {
            return graphicsLayer.graphics;
        }
        
        
        static private const ORIGIN:Point = new Point();
        
        private var levelPxOffsets:Vector.<int> = new Vector.<int>();
        
        
        private var gridLookup:BitmapData;
        
        private var stateLookup:BitmapData;
        private var lastStatelookup:BitmapData;
        private var loaderStates:Vector.<LoaderState> = new Vector.<LoaderState>();
        private var loaderOffsets:Vector.<int> = new Vector.<int>();
        private var loaderMax:LoaderMax = new LoaderMax({onProgress:progressHandler});
        
        
        private var previewChangeState:BitmapData;
        
        
        public function TerrainQueryBox() 
        {
            LoaderMax.defaultAuditSize = false;

            if (stage.stageWidth < 500) {
                scaleX = .5;
                scaleY = .5;
            }
            
            
            gridLookup = new BitmapData(boundingTiles.width, boundingTiles.height, false, 0);
            stateLookup = new BitmapData(boundingTiles.width*2, boundingTiles.height, false, 0);
            lastStatelookup = new BitmapData(stateLookup.width, stateLookup.height, false, 0);
            previewChangeState = new BitmapData(stateLookup.width, stateLookup.height, true, 0);
            ///*
            offset6[0] = 0;  offset6[1] = 1;  // nw  (0)
            offset6[2] = 1;  offset6[3] = 1;
            offset6[4] = 1;  offset6[5] = 0;
            
            offset6[6] = -1;  offset6[7] = 0;  // ne  (0)
            offset6[8] = -1;  offset6[9] = 1;
            offset6[10] = 0;  offset6[11] = 1;
            
            offset6[12] =0;  offset6[13] = -1;  //   sw (|=2,)  10
            offset6[14] = 1;  offset6[15] = -1;
            offset6[16] = 1;  offset6[17] = 0;
            
            offset6[18] = -1;  offset6[19] = 0;   // se (|=2,|=1) 11
            offset6[20] = -1;  offset6[21] = -1;
            offset6[22] = 0;  offset6[23] = -1;
            //*/
            
            // bounding box query on level 1 grid - 32,  1
            // bounding box query on level 2 grid - 64  , 2
            // bounding box query on level 3 grid - 128, 4,
            // bounding box query on level 4 grid - 256, 8
            
            var qSize:uint = 32;
            levelPxOffsets.push(0);
            var count:int = 0;
            var count2:int = 0;
            var level:int  = 0;
            loaderOffsets.push(0);
            boundWidth = int(boundingSpace.width) / 32;
            boundHeight = int(boundingSpace.height) / 32;
            while (qSize < QUERY_SIZE ) {
                
                qSize *= 2;
                count += (boundWidth >> level);
                
                count2 += (boundWidth >> level) * (boundHeight >> level);
                levelPxOffsets.push(count );
                loaderOffsets.push(count2);
                level++;
            }
            
            loaderStates.length = count2 + boundWidth*boundHeight;
            loaderStates.fixed = true;
            loaderOffsets.fixed = true;
            
            
             stage.align = StageAlign.TOP_LEFT;
             stage.scaleMode = StageScaleMode.NO_SCALE;
             
             addEventListener(Event.ENTER_FRAME, onEnterFrame);
             
             
             scrollRect = new Rectangle(0, 0, 1680, 1024);
             
            
             addChild(testLoadingLayer);
             addChild( graphicsLayer);
             
             addChild( new Bitmap(stateLookup));
              addChild( new Bitmap(previewChangeState));
              
            //loaderMax.skipFailed= true;
            loaderMax.skipPaused = true;
            
            addChild(_debugField);
            _debugField.autoSize = "left";
            _debugField.background = true;
            _debugField.backgroundColor  = 0xFFFFFF;
        
            
        }
        
        private static const START_ZOOM:int = 7;
        private static const START_X:int = 50;
        private static const START_Y:int = 7;
        
        
        private var _progressCount:int = 0;
        private function progressHandler(e:Event):void {
        //    _debugField.text =String( loaderMax.numChildren + ', '+_progressCount++ );
        }

        // if already downloading, get by grid id location
        // if not already downlaoding
        
        private function onEnterFrame(e:Event):void 
        {
            var mx:int = mouseX;
            var my:int = mouseY;
			if (mx < 0) mx = 0;
			if (my < 0) my = 0;
            var mix:int = Math.round(mx/32);
            var miy:int = Math.round(my / 32);
            if (mix >= boundWidth) mix = boundWidth - 1;    // clamp round up cases
            if (miy >= boundHeight) miy = boundHeight - 1;
            
            if (_lmx === mix && _lmy === miy) {
                return;
            }
            
            _lmx = mix;
            _lmy = miy;
            
            
            graphics.clear(); 
            gridLookup.fillRect(gridLookup.rect, 0xFF0000);
            lastStatelookup.copyPixels(stateLookup, stateLookup.rect, ORIGIN);
            previewChangeState.fillRect(previewChangeState.rect, 0);
            stateLookup.fillRect(stateLookup.rect, 0);
            
            var rect:Rectangle;
            
            
            rect = new Rectangle(mix * 32 - 32 * 4 * BASE_PATCH, miy * 32 - 32 * 4* BASE_PATCH, 32 * 8* BASE_PATCH, 32 * 8* BASE_PATCH);
            graphics.lineStyle(0, 0xFF0000, 1);
            
            graphics.drawRect(rect.x, rect.y, rect.width, rect.height);
            
            graphics.lineStyle(0, 0, 1);
            
            var qSize:int;
            
            qSize = 32;
            

            rect.width = 32*4;
            rect.height = 32 * 4;
            rect.x = mix * 32 - 32 * 2
            rect.y = miy * 32 - 32 * 2
            var level:int = 0;
            drawOntoGrid(rect, qSize, level);
        
            while (qSize < QUERY_SIZE ) {
                rect.x -= rect.width*.5; rect.y -= rect.height*.5; rect.width *= 2, rect.height *= 2;
                drawOntoGrid(rect, qSize*=2, ++level);
            }
            level++;
            // determine any change of state from last lookup
            while (--level > -1) {
                checkGrid(level);
            }
            
            // prioritize current quad and 3 nearest quads to load first

                                
            // Prioritize loading of 4 nearest squares
            mx /= 32;
            my /= 32;
			if (mx >= boundWidth) mx = boundWidth - 1;    // clamp round up cases
            if (my >= boundHeight) my = boundHeight - 1;
            var xRound:int = mx < mix ? 1 : -1;  
            var yRound:int = my < miy ? 1 : -1;      
            loaderStates[miy * boundWidth + mix].loader.prioritize();  // current  square i'm on
            var x:int;
            var y:int;  // get 3 rounded squares
            x = mx+xRound; y = my + yRound; // round both xy
            if (x>=0 && x< boundWidth && y >=0 && y< boundHeight) loaderStates[y * boundWidth +x].loader.prioritize(); 
            x = mx+xRound; y = my; // round x only
            if (x>=0 && x< boundWidth) loaderStates[y * boundWidth +x].loader.prioritize(); 
            x = mx; y = my + yRound; // round y only
            if (y >=0 && y< boundHeight) loaderStates[y * boundWidth +x].loader.prioritize();  
        
            loaderMax.resume();    
        }
        
        

        
        private function checkGrid(level:int):void 
        {
            var xOffset:int = levelPxOffsets[level];
            var yLen:int = boundHeight >> level;
            var xLen:int = boundWidth >> level;
            for (var y:int = 0; y < yLen; y++) {
                for (var x:int = 0; x < xLen; x++) {
                    var xer:int = xOffset + x;
                    var last:Boolean = lastStatelookup.getPixel(xer, y) !=0; 
                    var now:Boolean = stateLookup.getPixel(xer, y) != 0; 
                    if (last != now) {
                        resolveState(now, x,y, level);  // should resolve state index
                    }
                }
            }
        }
        
            //  http://mt0.google.com/vt/x=50&y=7&z=7    
            private static const DUMMY_START_X:int = 50;
            private static const DUMMY_START_Y:int = 7;
            private static const DUMMY_START_ZOOM:int = 7;
            
            
    private function getTileURLGoogle(x:int, y:int, zoom:int):String {
        return "http://mt0.google.com/vt/x="+x+"&y="+y+"&z="+zoom;
    }
        
        private function resolveState(doLoad:Boolean, x:int, y:int, level:int):void 
        {
            var child:DisplayObject;
            var rowsAcross:int = (boundWidth >> level);
            var offset:int = loaderOffsets[level];
            
            
            
            offset += y * rowsAcross + x;
            var gridSize:int = (32 << level);
            var loaderState:LoaderState = loaderStates[offset];
            if (loaderState == null) {
                loaderStates[offset] = loaderState= new LoaderState();
            }
            if (doLoad) {
                if (loaderState.state === LoaderState.STATE_DOWNLOADED) {
                    throw new Error("Should not happen!");
                    return;
                }
                var spr:Sprite;
                if (loaderState.state === LoaderState.STATE_EMPTY) {
                    var targZoom:int = loaderOffsets.length - level - 1;
                    child = testLoadingLayer.addChild(spr = new Sprite());
                    child.x = gridSize * x;
                    child.y = gridSize * y;
                    
                    var targScale:Number = gridSize / 256;  // divide by google map size 256
                    child.scaleX = targScale;
                    child.scaleY = targScale;
                    
                    loaderState.load( getTileURLGoogle((DUMMY_START_X << targZoom) + x, (DUMMY_START_Y << targZoom) + y, DUMMY_START_ZOOM + targZoom),  child);
                    loaderMax.prepend(loaderState.loader);
                    
                    //loaderState.loader.pause();  // enable this to test nearest-4-square priority load trails
                }  
                else if (loaderState.state < LoaderState.STATE_DOWNLOADING) {  
                    
                    loaderState.resume();
                    loaderState.prioritize();
                }
                else {
                    // prioritize
                    loaderState.prioritize();
                }
                
                
            }
            else {
                if (loaderState.state >= LoaderState.STATE_DOWNLOADING) {
                ///*
                var ref:LoaderCore = loaderState.loader;
                    loaderState.dispose();
                    //loaderMax.resume();
                    loaderMax.remove(ref);
                    //loaderStates[offset]  = null;
                    //loaderMax.resume();
                    
                    
                    //*/
                    //loaderState.remove();
                
                }
            }
            
            //loaderOffsets[level] + y *
            previewChangeState.setPixel32( levelPxOffsets[level] + x, y, 0xFF0000FF);
            //throw new Error("DIFFERENT:" + level + ","+[x+levelPxOffsets[level],y]);
            
            //if (!doLoad) throw new Error("TO UNLOAD!" + level + ","+[x+levelPxOffsets[level],y]);
            
        }
        
        private var rectFiller:Rectangle = new Rectangle();
        private var boundWidth:int;
        private var boundHeight:int;
        private var _debugField:TextField = new TextField();
        
        private function drawOntoGrid(sampleRegion:Rectangle, gridSize:int, level:int):void {
    
            var xLimit:int = Math.ceil( (sampleRegion.x+sampleRegion.width)  / gridSize );
            var yLimit:int = Math.ceil( (sampleRegion.y + sampleRegion.height)  / gridSize );
            var parentGridSize:int = gridSize * 2;
            if (xLimit > boundingTiles.x + boundingTiles.width) xLimit = boundingTiles.x + boundingTiles.width ;
            if (yLimit > boundingTiles.y + boundingTiles.height) yLimit = boundingTiles.y + boundingTiles.height ;
            var yStart:int = sampleRegion.y / gridSize;
            var xStart:int = sampleRegion.x / gridSize;
            if (xStart < boundingTiles.x) xStart = boundingTiles.x;
            if (yStart < boundingTiles.y) yStart = boundingTiles.y;
            
            rectFiller.width = gridSize / 32;
            rectFiller.height = gridSize / 32;
            
                var levelPxOffset:int = levelPxOffsets[level];
                
        
            var randColor:uint = 0xFF + (level + 1);// * (65535/8);
            
            var gotParent:Boolean = parentGridSize <= QUERY_SIZE;
            
            for (var yi:int =  yStart; yi < yLimit; yi++) {
                    for (var xi:int = xStart; xi < xLimit; xi ++) {
                        var xis:int;
                         var yis:int;
                        rectFiller.x = xis =( xi - boundingTiles.x) * rectFiller.width;
                        rectFiller.y = yis = (yi - boundingTiles.y) * rectFiller.height;
                    
    
                        if ( (gridLookup.getPixel(xis, yis) & 0xFFFF00) != 0xFF0000) {
                            // this is already filled up by something
                            //BitmapData().compare()
                            continue;
                        }
                
                        if (gridSize == 32 ) graphics.lineStyle(2, 0xFF)
                        else graphics.lineStyle(0, 0, 1);
                        graphics.beginFill(0xFF0000, .2);
                        graphics.drawRect(xi * gridSize, yi * gridSize, gridSize, gridSize);
                         gridLookup.fillRect(rectFiller, randColor);
                            stateLookup.setPixel(xi+levelPxOffset, yi, 0xFF0000);
                        
                        if (gotParent) {
                            if (gridSize == 32) graphics.lineStyle(1, 0xFF0000, 1)
                            else graphics.lineStyle(0, 0, 1)
                            
                            var result:int = 0;
                            // based on current region, which quadrant and I'm in?? draw rect on 3 other quadrants.
                            var xii:int = xi*gridSize ;
                            var yii:int = yi*gridSize;
                        
                            
                            
                            result|= ((xi*gridSize) % parentGridSize)  != 0 ? 1 : 0;
                            result |= ((yi * gridSize) % parentGridSize) != 0 ? 2 : 0;
                    
                        
                            
                            //if (gridSize == 32 ) {
                                //graphics.lineStyle(0, 0xFF, 1);
                                
                                result *= 6;
                                
                                rectFiller.x = (xis) + offset6[result]*rectFiller.width;
                                rectFiller.y = (yis) + offset6[result + 1] * rectFiller.height;
                                if (gridLookup.getPixel(rectFiller.x, rectFiller.y) === 0xFF0000) {
                                    gridLookup.fillRect(rectFiller, randColor);
                                    graphics.beginFill(0xFF0000, .2);
                                    graphics.drawRect(xii+ offset6[result] * gridSize,
                                    yii+(offset6[result + 1]) * gridSize,
                                    gridSize, gridSize);
                                    stateLookup.setPixel(xi+ levelPxOffset+offset6[result], yi+ offset6[result+1], 0xFF0000);
                                }
                
                                rectFiller.x = (xis) + offset6[result+2]*rectFiller.width;
                                rectFiller.y = (yis) + offset6[result+3]*rectFiller.height;
                                if (gridLookup.getPixel(rectFiller.x, rectFiller.y) === 0xFF0000) {
                                    gridLookup.fillRect(rectFiller, randColor);
                                    graphics.beginFill(0xFF0000, .2);
                                    graphics.drawRect(xii+ offset6[result + 2] * gridSize,
                                    yii+(offset6[result + 3]) * gridSize,
                                    gridSize, gridSize);
                                    stateLookup.setPixel(xi+ levelPxOffset+offset6[result+2], yi+ offset6[result+3], 0xFF0000);
                                }
                                
                                rectFiller.x = (xis) + offset6[result+4]*rectFiller.width;
                                rectFiller.y = (yis) + offset6[result + 5] * rectFiller.height;
                                if (gridLookup.getPixel(rectFiller.x, rectFiller.y) === 0xFF0000) {
                                    gridLookup.fillRect(rectFiller, randColor);
                                    graphics.beginFill(0xFF0000, .2);
                                    graphics.drawRect(xii+ offset6[result + 4] * gridSize,
                                    yii+offset6[result + 5] * gridSize,
                                    gridSize, gridSize);
                                    stateLookup.setPixel(xi+ levelPxOffset+offset6[result+4], yi+ offset6[result+5], 0xFF0000);
                                    
                                }
                                
                            //}
                            
                        
                        
                        }
                }
            }
            
            
            
            
            
        
            
        }
        
    }

}
import com.greensock.loading.ImageLoader;
import com.greensock.loading.LoaderStatus;
import flash.display.Shape;
import flash.display.Sprite;
import flash.events.Event;

        
class LoaderState {
    
    public static const STATE_EMPTY:int = 0;
    public static const STATE_PAUSED_PENDING_REMOVAL:int = 1;
    public static const STATE_DOWNLOADED_PENDING_REMOVAL:int = 2;
    public static const STATE_DOWNLOADING:int = 3; 
    public static const STATE_DOWNLOADED:int = 4;
    
    private var _loader:ImageLoader;
    private var _container:Sprite;
    
    private var _state:int = 0;
    
    
    public function get loaderState():int {
        if (_loader == null) return STATE_EMPTY;
        
        var status:int =  _loader.status;    
        if (status === LoaderStatus.COMPLETED) {
            return STATE_DOWNLOADED;
        }
        else if (status === LoaderStatus.READY || status === LoaderStatus.LOADING) {
            return STATE_DOWNLOADING;
        }
        else if (status === LoaderStatus.PAUSED) {
            return STATE_PAUSED_PENDING_REMOVAL;
        }
        
        return STATE_DOWNLOADED_PENDING_REMOVAL;
    }
    
    public function get state():int 
    {
        return _state;
    }
    
    public function set state(value:int):void 
    {
        _state = value;
        
    }
    
    public function get loader():ImageLoader 
    {
        return _loader;
    }
    
    public function get container():Sprite 
    {
        return _container;
    }
    
    
    public function getRawContent():* {
        return _loader.rawContent;
    }

    //private var _preloaderBar:Shape = new Shape();
    
    public function load(url:String, container:*):void {

        _state = STATE_DOWNLOADING;
        _container = container;
        _loader = new ImageLoader(url, { container:container, onComplete:notifyComplete } );
        _container.visible = true;
        
        //_preloaderBar.graphics.beginFill(0x00FF00, 0);
        //    _preloaderBar.graphics.drawRect(, 1);
        
        //container.addChild(_preloaderBar);
        //    _loader.load();

    }
    private function notifyComplete(e:Event):void {
        _state = STATE_DOWNLOADED;
    }
    
    public function resume():void {
        _container.visible = true;
        if (_state === STATE_PAUSED_PENDING_REMOVAL) _loader.resume();
    }
    
    
    public function remove():void {
        if (_loader.status === STATE_DOWNLOADED) {
            _state = STATE_DOWNLOADED_PENDING_REMOVAL;
        }
        else {
            _loader.pause();
            _state = STATE_PAUSED_PENDING_REMOVAL;
        }
        _container.visible = false;
    }
 
    
    public function dispose():void {
        if (_container.parent) _container.parent.removeChild(_container);
        _container = null;
        _state = 0;
        // _loader.dispose(true);
        //loader.unload();
        //if (_state === STATE_DOWNLOADED)
        _loader.dispose(true);
        //else 
        //loader.unload();
        _loader = null;
    }
    
    public function prioritize():void 
    {
        _loader.prioritize();
        _container.visible = true;
    }
    
}