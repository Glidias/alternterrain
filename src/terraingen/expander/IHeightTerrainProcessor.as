package terraingen.expander 
{
	import alternterrain.core.HeightMapInfo;
	import alternterrainxtras.util.ITerrainProcess;
	/**
	 * A bridge interface class to link to ProceduralExpansion utility.
	 * @author Glenn Ko
	 */
	public interface IHeightTerrainProcessor 
	{
		// identifies any terrain processes for batch setting of heightmap data. If left null or empty, you must manually set these up during the processing of each sample itself. 
		function getProcesses():Vector.<ITerrainProcess>;  
		
		function get sampleSize():int;  // the sample size (no. of tiles) long/wide for applying a terrain process.
			
		// Hooks for adjusting height values in HeightMapInfo samples
		function process3By3Sample(hm:HeightMapInfo, phase:int):void;  // to process 3x3 blast samples (allowing you to identify center-focused sample and it's 8 neighboring samples).  This is used for "neighbor-sensitive" terrain processes.
		function process1By1Sample(hm:HeightMapInfo, phase:int):void;  // to process 1x1 individual sample 
		
		function getSamplePhases():Vector.<Boolean>;  // an	array of boolean values in order indicating the type of processes (true for 3x3, false for 1x1) for each sample. If left null, defaults to [true,false] , which means process3x3(hm,0) will occur first, than process1x1(hm,0).
													   // for example, if using custom sample phases of [true,false,true], you'll get process3x3(hm,0), process1x1(hm,0), process3x3(hm,1)
													   
													   
		function postProcess3By3Sample(hm:HeightMapInfo):void;  // This function is always called for post-processing pass (such as smoothing across the entire board) , once all above per-sample processes (often those which adjusts heights) are done. The post-processing is a 3x3 sample.
									
	}

}