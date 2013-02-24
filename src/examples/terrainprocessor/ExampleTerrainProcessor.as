package examples.terrainprocessor 
{
	import alternterrain.core.HeightMapInfo;
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
		
	//	private var filterFault:TerrainProcesses = new TerrainProcesses();  // can't seam this!
		
		private var filterSmooth:TerrainProcesses = new TerrainProcesses();
		
		//private var filterPerlinNoise:TerrainProcesses = new TerrainProcesses();   // // FLash's perlinNoise noise that  can be seamless with shift x/y offsets
		
		private var _processes:Vector.<TerrainProcesses> = new <TerrainProcesses>[filterCircles, filterNoise, filterSmooth];
		
		private var seed:int = 93992;  // set this to a random number.
		
		public function ExampleTerrainProcessor() 
		{
			filterCircles.terrainRandomSeed = seed;
			filterCircles.terrainCircleSize = 64*64;
			filterCircles.maxDisp = 500;
			filterCircles.minDisp = -4500;
			
			filterNoise.terrainRandomSeed = seed;
			filterNoise.maxDisp = 512;
			filterNoise.minDisp = -512;
		}
		
		/* INTERFACE terraingen.expander.IHeightTerrainProcessable */
		
		public function process3By3Sample(hm:HeightMapInfo, phase:int):void 
		{
			// TODO: sample centered region  of heightmap only!
			filterCircles.terrainIterateCircles(32);
		}
		
		public function process1By1Sample(hm:HeightMapInfo, phase:int):void 
		{
			// TODO: need to set offset of noise to match heightmap info!
			filterNoise.terrainApplyNoise(20, 4, 2.8, .65);
			
			filterSmooth.terrainSmooth(.15);
		}
		
		/* INTERFACE terraingen.expander.IHeightTerrainProcessable */
		
		public function getProcesses():Vector.<TerrainProcesses> 
		{
			return _processes;
		}
		
		/* INTERFACE terraingen.expander.IHeightTerrainProcessable */
		
		public function getSamplePhases():Vector.<Boolean> 
		{
			return null;
		}
		
		public function get sampleSize():int {
			return 128;
		}
		
	}

}