package examples.terrainprocessor 
{
	import alternterrain.core.HeightMapInfo;
	import alternterrainxtras.util.ITerrainProcess;
	import alternterrainxtras.util.TerrainProcesses;
	import flash.display.Sprite;
	import terraingen.expander.IHeightTerrainProcessor;
	/**
	 * An example terrain process bridge class that can be copied and modified to compile as a document class .swf and loaded externally.
	 * 
	 * @author Glenn Ko
	 */
	public class ExampleTerrainProcessor extends Sprite implements IHeightTerrainProcessor
	{
		private var filterCircles:TerrainProcesses = new TerrainProcesses(); // will spill out of current heightmap location for splashed circle
		
		private var filterNoise:TerrainProcesses = new TerrainProcesses();  // frequency noise that can be seamless with shift x/y offsets
		
		private var filterFault:TerrainProcesses = new TerrainProcesses();  // can't seam this!
		
		private var filterSmooth:TerrainProcesses = new TerrainProcesses();
		
		//private var filterPerlinNoise:TerrainProcesses = new TerrainProcesses();   // // FLash's perlinNoise noise that  can be seamless with shift x/y offsets
		
		
		private var _processes:Vector.<ITerrainProcess> = new <ITerrainProcess>[filterCircles, filterNoise, filterSmooth, filterFault];
		
		
		
		private var seed:int = 93992;  // set this to a random number.
		
		public function ExampleTerrainProcessor() 
		{
			filterCircles.terrainRandomSeed = seed;
			filterCircles.terrainCircleSize = 64*64;
			filterCircles.maxDisp = 900;
			filterCircles.minDisp = -900;
			
			filterNoise.terrainRandomSeed = seed;
			filterNoise.maxDisp = 600;
			filterNoise.minDisp = -600;
			
			filterFault.maxDisp = 120;
			filterFault.minDisp = -120;
			filterFault.terrainWaveSize = 4;
			filterFault.terrainRandomSeed =  seed;
			filterFault.terrainFunction = TerrainProcesses.SIN;
		}
		
		/* INTERFACE terraingen.expander.IHeightTerrainProcessable */
		
		public function process3By3Sample(hm:HeightMapInfo, phase:int):void 
		{
			var w:int = hm.XSize  / 3;
			//filterSmooth.adjustHeights(300, w, w, w, w);	
			filterCircles.terrainIterateCircles(32, w, w, w, w);
		//	filterFault.terrainIterateFault(32);
			
		}
		
		public function process1By1Sample(hm:HeightMapInfo, phase:int):void 
		{
			// TODO: need to set offset of noise to match heightmap info!
			// 20, 4, 2.8, .65  // not so rough
			// 20, 4, 3.4, .85  // quite rough
			filterNoise.terrainApplyNoise(20, 4, 2.8, .65);  
	
		}
		
		// Usually, your smoothing operations go here
		public function postProcess3By3Sample(hm:HeightMapInfo):void {
			var w:int = hm.XSize  / 3; // get center sample size from  3x3 heightmap info
			var s:int = 4;  // smooth across a certain number of tiles between edges. (recommended >=4 ie. as much as possible to avoid seams )
			filterSmooth.terrainSmooth(.15, w-s,w-s,w+s*2,w+s*2);
		}
		
		/* INTERFACE terraingen.expander.IHeightTerrainProcessable */
		
		public function getProcesses():Vector.<ITerrainProcess> 
		{
			return _processes;
		}
		
		/* INTERFACE terraingen.expander.IHeightTerrainProcessable */
		
		public function getSamplePhases():Vector.<Boolean> 
		{
			return new <Boolean>[true, false];
		}
		
		public function get sampleSize():int {
			return 128;
		}
		
	}

}