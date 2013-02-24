package alternterrainxtras.util 
{
	import alternterrainxtras.msa.Perlin;
	import alternterrainxtras.msa.Smoothing;
	import flash.display.BitmapData;
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
		public var terrainRandomSeed:int = 0;
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
		
		public function terrainGrayscaleHeightMap(heightmap:BitmapData):void {
			var range:Number = maxDisp - minDisp;
			var multiplier:Number = 1 / 255;
			for (var y:int = 0; y < terrainGridLength; y++) {
				for (var x:int = 0; x < terrainGridWidth; x++) {
					terrainHeights[y*terrainGridWidth + x] += minDisp + (heightmap.getPixel(x, y) & 0xFF)*multiplier * range;
				}
			}
		}
		
		public function terrainApplyNoise(scale:Number, octaves:int=4, lacunarity:Number=128, H:Number = 128 ):void {
			Perlin.setParams( { octaves:octaves, H:H, lacunarity:lacunarity } );
			var phase:int = terrainRandomSeed;
			var range:Number = maxDisp - minDisp;
			var mx:int = terrainGridWidth * .5;
			var my:int =  terrainGridLength * .5;
			var xMult:Number =  1 / scale;
			var yMult:Number =  1 / scale;
			
			for (var y:int = 0; y < terrainGridLength; y++) {
				for (var x:int = 0; x < terrainGridWidth; x++) {
					terrainHeights[y * terrainGridWidth + x] += minDisp +  Perlin.fractalNoise((x - mx)*xMult, (y - my)*yMult , phase) * range;  //Perlin.fractalNoise((x - mx), (y - my) , phase)
					
				}
			}
		}
		
		public function terrainIterateCircles( numIterations:int):void {

			var dispAux:Number;
			var i:int,j:int,k:int,halfX:int,halfZ:int,dispSign:int;
			var x:Number,z:Number,r:Number,pd:Number;

			halfX = terrainGridWidth / 2;
			halfZ = terrainGridLength / 2;
			for (k = 0; k < numIterations;k++) {

				z = Math.random() * (terrainGridWidth);
				x = Math.random() *( terrainGridLength);
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
		
		
		private function deposit(x:int, z:int):void {

			var j:int,k:int,kk:int,jj:int,flag:int;

			flag = 0;
			for (k=-1;k<2;k++)
				for(j=-1;j<2;j++)
					if (k!=0 && j!=0 && x+k>-1 && x+k<terrainGridWidth && z+j>-1 && z+j<terrainGridLength) 
						if (terrainHeights[(x+k) * terrainGridLength + (z+j)] < terrainHeights[x * terrainGridLength + z]) {
							flag = 1;
							kk = k;
							jj = j;
						}

			if (!flag)
				terrainHeights[x * terrainGridLength + z] += maxDisp;
			else
				deposit(x+kk,z+jj);
		}


		public function terrainIterateParticleDeposition( numIt:int):void {
	
			var x:int,z:int,i:int,dir:int;


			x = rand() % terrainGridWidth;
			z = rand() % terrainGridLength;

			for (i=0; i < numIt; i++) {

				iterationsDone++;
				dir = rand() % 4;

				if (dir == 2) {
					x++;
					if (x >= terrainGridWidth)
						x = 0;
				}
				else if (dir == 3){
					x--;
					if (x == -1)
						x = terrainGridWidth-1;
				}
				
				else if (dir == 1) {
					z++;
					if (z >= terrainGridLength)
						z = 0;
				}
				else if (dir == 0){
					z--;
					if (z == -1)
						z = terrainGridLength - 1;
				}

				if (terrainParticleMode == ROLL)
					deposit(x,z);
				else
					terrainHeights[x * terrainGridLength + z] += maxDisp;
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
		
		/**
		 * 
		 * @param	k	Smoothness ratio betwene 0-1. A value of 1 would flatten terrain. Smaller numbers indiciate smoothing amount.
		 */
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
				for(j=terrainGridWidth-2;j>-1;j--)
					terrainHeights[i*terrainGridWidth + j] =
						terrainHeights[i*terrainGridWidth + j] * (1-k) + 
						terrainHeights[i * terrainGridWidth + j + 1] * k;
						
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