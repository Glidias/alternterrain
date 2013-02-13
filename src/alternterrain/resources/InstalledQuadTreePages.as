package alternterrain.resources 
{
	import alternterrain.core.HeightMapInfo;
	import alternterrain.core.QuadTreePage;
	import flash.utils.IDataInput;
	import flash.utils.IDataOutput;
	import flash.utils.IExternalizable;

	/**
	 * This is the class to hold the .tres format for syncronous loading/initilization of multiple quad-tree pages.
	 * @author Glenn Ko
	 */
	public class InstalledQuadTreePages implements IExternalizable
	{
		public var pageGrid:Vector.<QuadTreePage>;
		public var totalPagesAcross:int;
		public var heightMap:HeightMapInfo;  // todo: multiple heightmaps...for now, we only support 1 shared heightmap reference
		
		public function InstalledQuadTreePages() 
		{
			
		}
		
		/* INTERFACE flash.utils.IExternalizable */
		
		public function writeExternal(output:IDataOutput):void 
		{
			output.writeShort(totalPagesAcross);
			var i:int = totalPagesAcross * totalPagesAcross;
			heightMap.writeExternal(output);
			while (--i > -1) {
				var q:QuadTreePage = pageGrid[i];
				q.writeExternal(output);
			}
		}
		
		public function readExternal(input:IDataInput):void 
		{
			totalPagesAcross = input.readShort();
			var i:int = totalPagesAcross * totalPagesAcross;
			pageGrid = new Vector.<QuadTreePage>(i, true);
			heightMap = new HeightMapInfo();
			heightMap.readExternal(input);
			while (--i > -1) {
				var q:QuadTreePage = new QuadTreePage();
				pageGrid[i] = q ;
				q.readExternal(input);
				q.heightMap = heightMap;  // todo: remove ability for quadTreePage to be directly read
			}
		}
		
	}

}