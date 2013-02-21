package alternterrainxtras.util 
{
	/**
	 * 
	 * Useful for modifying terrain heights, adding additional detail, noise, smoothing, etc. Based on code found in terrain.cpp.
	 * @author Glenn Ko
	 */
	public class TerrainProcesses 
	{
		
		public var terrainHeights:Vector.<int>;
		public var terrainGridLength:int;
		public var terrainGridWidth:int;
		
		public  var iterationsDone :int= 0;
		public var maxDisp:Number = 1.0;
		public var minDisp:Number = 0.1;
		public var disp:Number;
		public var itMinDisp:int=100;
		public var terrainWaveSize:Number= 3.0;
		public var terrainFunction:int = MPD;
		public var terrainParticleMode:int = ROLL;
		
		public var terrainCircleSize:Number  = 100.0;
		public var  terrainRandomSeed:int = 0;
		public var roughness:Number = 1.0;
		public var steps:int = 1;
		
		public function setupSquareHeights(heights:Vector.<int>):void {
			terrainHeights = heights;
			var val:int = Math.sqrt(heights.length);
			terrainGridLength = val;
			terrainGridWidth = val;
			iterationsDone = 0;
		}
		
		public function setupHeights(heights:Vector.<int>, width:int, length:int):void {
			terrainHeights = heights;
			terrainGridLength = length;
			terrainGridWidth = width;
			iterationsDone = 0;
		}
		public function setupEmptyTerrain(x:int, y:int):void {

			//var i:int;
			terrainGridWidth = x;
			terrainGridLength = y;
			terrainHeights = new Vector.<int>(x * y, true);
			//for (i=0;i<terrainGridWidth*terrainGridLength; i++)
			//	terrainHeights[i] = 0.0;
			iterationsDone = 0;
		}
		
		/*
		 * Is Atregen too monolithic? There could actually be individual seperate programs modules to:
	     *
		 * 1) Convert image file formats or .data of elevation255 data to hm.   (elev255_to_hm.swf)  - Atregen does this, even though it doesn't save out hm files but saves out final tre file.
		 * 2) Convert model files (3ds/dae/etc.) to hm   						(model3d_to_hm.swf) - Atregen is intended to do this as well
		 * 3) Load elevation255. (HM sample size, hm output size). Split it and expand if necessary. Apply filters for added detail. Smooth edges between hm sampled zones if neceessary. Save out a hm or multiple .hm files.   (hm_to_final_hm_s.swf) - Atregen does NOT do this and has no real need to do this as not all use-cases require such splitting except for super-large islands.
		 * 4) Convert .hm to normal maps per page.    (hm_to_normal.swf)  - Ategen does this. 
		 * 5) Convert .hm to height maps per page     (hm_to_height.swf)  - Atregen does this.
		 * 6) Split feeded in assets such as tile maps, light maps, etc. if required to page size.  (split_tilemap.swf, split_lightmap.swf) etc. - Atregen does this
		 * 7) Convert .hm to a .tre file or multiple .tres file, depending.   (hm_to_tre.swf), (hm_to_tres.swf) / This is what Atregen  does mainly
		 * 
		 * The advantage of seperate programs is that certain processes can be executed on demand when the user "visits" a location in a large world.
		 * In that way, there's no need handle pre-parse large worlds which might be a long process for Atregen. Memory footprint per application is also potentially smaller.
		 * 
		Filters:
		- circle fault 
		- line fault
		- noise
		- smooth
		* 
		* Can atregen handle up to a 8192x8192 heightmap without crashing?
		* 
		*/
		
		public static const STEP:int =	1;
		public static const SIN:int =	2;
		public static const COS	:int =	3;
		public static const CIRCLE:int =  4;
		public static const MPD:int =		5;
		public static const RandomDirection:int = 6;

		public static const ROLL:int =	0;
		public static const STICK:int =	1;
		
		

		
		public function TerrainProcesses() 
		{
			
		}
		
		
		private function rand():int {
			return int(Math.random() * 32767);
		}
		
		public function terrainIterateCircles( numIterations:int):void {

			var dispAux:Number;
			var i:int,j:int,k:int,halfX:int,halfZ:int,dispSign:int;
			var x:Number,z:Number,r:Number,pd:Number;

			halfX = terrainGridWidth / 2;
			halfZ = terrainGridLength / 2;
			for (k = 0; k < numIterations;k++) {

				z = Math.random() * terrainGridWidth;
				x = Math.random() * terrainGridLength;
				iterationsDone++;
				if (iterationsDone < itMinDisp)
					disp = maxDisp + (iterationsDone/(itMinDisp+0.0))* (minDisp - maxDisp);
				else
					disp = minDisp;
				r = Math.random();
				if (r > 0.5)
					dispSign = 1;
				else
					dispSign = -1;
				for (i = 0;i < terrainGridLength; i++)
					for(j = 0; j < terrainGridWidth; j++) {
							pd = Math.sqrt(((i-x)*(i-x) + (j-z)*(j-z)) / terrainCircleSize)*2;
							if (pd > 1) dispAux = 0.0;
							else if (pd < -1) dispAux = 0.0;
							else
								dispAux =  disp/2*dispSign + Math.cos(pd*3.14)*disp/2 * dispSign;
						
						terrainHeights[i*terrainGridWidth + j] += dispAux;
					}
			}
	

		}
		
		private function terrainHeight( x:int,z:int):int {
			if (x > terrainGridWidth-1)
				x -= (terrainGridWidth-1);
			else if (x < 0)
				x += terrainGridWidth-1;
			if (z > terrainGridLength-1)
				z -= (terrainGridLength-1);
			else if (z < 0)	
				z += terrainGridLength-1;
			assert(x>=0 && x < terrainGridWidth);
			assert(z>=0 && z < terrainGridLength);
			return(terrainHeights[x * terrainGridWidth + z]);
		}
		
		private function assert(cond:Boolean):void 
		{
			if (!cond) throw new Error("Assertion failed!");
		}
		
		private function  terrainRandom( dispH:Number):Number {

			var r:Number;

			r = ( Math.random() ) * dispH - (dispH * 0.5);
			return(r);
		}

		private function terrainMPDDiamondStep( i:int,j:int,step:int,dispH:Number):void {

				terrainHeights[(i+step/2)*terrainGridWidth + j+step/2] = 
								(terrainHeight(i,j) + 
								terrainHeight(i+step,j) + 
								terrainHeight(i+step,j+step) + 
								terrainHeight(i,j+step)) / 4;
				terrainHeights[(i+step/2)*terrainGridWidth + j+step/2] += terrainRandom(dispH);
		}
		
		private function terrainMPDSquareStep( x1:int, z1:int,  step:int,  dispH:Number):void {

			var i:int,j:int;
			var x:int,z:int;

			x = x1 + step/2;
			z = z1 + step/2;

			i = x + step/2;
			j = z;
			if (i == terrainGridLength-1)
				terrainHeights[i*terrainGridWidth + j] = 
								(terrainHeight(i,j+step/2) + 
								terrainHeight(i,j-step/2) + 
								terrainHeight(i-step/2,j)) / 3;
			else
				terrainHeights[i*terrainGridWidth + j] = 
								(terrainHeight(i,j+step/2) + 
								terrainHeight(i,j-step/2) + 
								terrainHeight(i-step/2,j) + 
								terrainHeight(i+step/2,j)) / 4;
			terrainHeights[i*terrainGridWidth + j] += terrainRandom(dispH);

			j = z + step/2;
			i = x;
			if (j == terrainGridWidth-1)
				terrainHeights[i*terrainGridWidth + j] = 
								(terrainHeight(i,j-step/2) + 
								terrainHeight(i-step/2,j) + 
								terrainHeight(i+step/2,j)) / 3;
			else
				terrainHeights[i*terrainGridWidth + j] = 
								(terrainHeight(i,j+step/2) + 
								terrainHeight(i,j-step/2) + 
								terrainHeight(i-step/2,j) + 
								terrainHeight(i+step/2,j)) / 4;
			terrainHeights[i*terrainGridWidth + j] += terrainRandom(dispH);
			
			i = x - step/2;
			j = z;
			if (i == 0){
				terrainHeights[i*terrainGridWidth + j] = 
								(terrainHeight(i,j+step/2) + 
								terrainHeight(i,j-step/2) + 
								terrainHeight(i+step/2,j)) / 3;
				terrainHeights[i*terrainGridWidth + j] += terrainRandom(dispH);
			}

			j = z - step/2;
			i = x;
			if (j == 0){
				terrainHeights[i*terrainGridWidth + j] = 
								(terrainHeight(i,j+step/2) + 
								terrainHeight(i-step/2,j) + 
								terrainHeight(i+step/2,j)) / 3;
				terrainHeights[i*terrainGridWidth + j] += terrainRandom(dispH);
			}
		}

		public function terrainIterateMidPointDisplacement(steps:int,maxDispH:Number,r:Number):void {

			var i:int,j:int,step:int;
			var m:Number = maxDispH;

			terrainGridWidth = int(Math.pow(2,steps)) + 1;
			terrainGridLength = terrainGridWidth;
			for (i=0;i<terrainGridWidth*terrainGridLength; i++)
				terrainHeights[i] = 0.0;
			iterationsDone = 0;
			

			for (step = terrainGridWidth-1; step > 1; step /= 2 ) {

				for (i = 0;i<terrainGridLength-2;i+=step)
					for(j=0;j<terrainGridWidth-2;j+=step) {
						terrainMPDDiamondStep(i,j,step,m);
						
					}

				for (i = 0;i<terrainGridLength-2;i+=step)
					for(j=0;j<terrainGridWidth-2;j+=step) {
						terrainMPDSquareStep(i,j,step,m);
						
					}
				m *= Math.pow(2,-r);
			}

		}


		public function terrainIterateFault( numIterations:int):void {

			var dispAux:Number;
			var pd:Number;
			var i:int,j:int,k:int,halfX:int,halfZ:int;
			var a:Number,b:Number,c:Number,w:Number,d:Number;

			halfX = terrainGridWidth / 2;
			halfZ = terrainGridLength / 2;
			for (k = 0; k < numIterations;k++) {
				d = Math.sqrt(halfX * halfX + halfZ * halfZ);
				w = rand();
				a = Math.cos(w);
				b = Math.sin(w);
				c = Math.random() * 2*d  - d; 
				
				iterationsDone++;
				if (iterationsDone < itMinDisp)
					disp = maxDisp + (iterationsDone/(itMinDisp+0.0))* (minDisp - maxDisp);
				else
					disp = minDisp;
				for (i = 0;i < terrainGridLength; i++)
					for(j = 0; j < terrainGridWidth; j++) {
						switch(terrainFunction){
						case STEP:
							if ((i-halfZ) * a + (j-halfX) * b + c > 0)
								dispAux = disp;
							else
								dispAux = -disp;
							break;
						case SIN:
							pd = ((i-halfZ) * a + (j-halfX) * b + c)/terrainWaveSize;
							if (pd > 1.57) pd = 1.57;
							else if (pd < 0) pd = 0;
							dispAux = -disp/2 + Math.sin(pd)*disp;
							break;
						case COS:
							pd = ((i-halfZ) * a + (j-halfX) * b + c)/terrainWaveSize;
							if (pd > 3.14) pd = 3.14;
							else if (pd < -3.14) pd = -3.14;
							dispAux =  disp-(terrainWaveSize/(terrainGridWidth+0.0)) + Math.cos(pd)*disp;
							break;
						}
						terrainHeights[i*terrainGridWidth + j] += dispAux;
					}
			}
		}
		
		public function terrainSmooth(k:Number):void {

			var i:int;
			var j:int;

			for(i=0;i<terrainGridLength;i++)
				for(j=1;j<terrainGridWidth;j++)
					terrainHeights[i*terrainGridWidth + j] =
						terrainHeights[i*terrainGridWidth + j] * (1-k) + 
						terrainHeights[i*terrainGridWidth + j-1] * k;
			for(i=1;i<terrainGridLength;i++)
				for(j=0;j<terrainGridWidth;j++)
					terrainHeights[i*terrainGridWidth + j] =
						terrainHeights[i*terrainGridWidth + j] * (1-k) + 
						terrainHeights[(i-1)*terrainGridWidth + j] * k;
			
			for(i=0; i<terrainGridLength; i++)
				for(j=terrainGridWidth-1;j>-1;j--)
					terrainHeights[i*terrainGridWidth + j] =
						terrainHeights[i*terrainGridWidth + j] * (1-k) + 
						terrainHeights[i*terrainGridWidth + j+1] * k;
			for(i=terrainGridLength-2;i<-1;i--)
				for(j=0;j<terrainGridWidth;j++)
					terrainHeights[i*terrainGridWidth + j] =
						terrainHeights[i*terrainGridWidth + j] * (1-k) + 
						terrainHeights[(i+1)*terrainGridWidth + j] * k;

			//if (terrainNormals != NULL)
				//terrainComputeNormals();
		}
		
	}

}