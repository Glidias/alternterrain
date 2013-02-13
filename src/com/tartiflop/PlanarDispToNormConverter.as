package com.tartiflop
{
	
	import flash.display.Bitmap;
	import flash.display.BitmapData;
	import flash.geom.Vector3D;
	
	/**
	 * Converts displacement map data into normal map data.
	 * Assumes that the displacement map data is
	 * greyscale. Assumes also that the bitmap data is for a single plane.
	 *
	 * Normal map is calculated from the surface gradients using first (centered) and
	 * second order (forward and backward) finite differences.
	 *
	 * Direction of the displacement can be chosen to produce normal maps for xy, yz and zx planes.
	 */
	public class PlanarDispToNormConverter extends DispToNormConverter
	{
		
		/**
		 * Converts the displacement map to a normal map.
		 */
		public override function convertToNormalMap():Bitmap
		{
			
			if (heightMap == null && displcamentBitmapData == null)
			{
				return new Bitmap();
			}
			
			var width:Number = heightMap != null ? heightMap.RowWidth - 1 : displcamentBitmapData.width;
			var height:Number = heightMap != null ? heightMap.RowWidth - 1 : displcamentBitmapData.height;
			
			var normalBitmapData:BitmapData = new BitmapData(width, height, false, 0x000000);
			
			var nz:Number = 1. / amplitude;
			
			// calculate the normals over the central region (first order centered finite difference scheme).
			for (var i:Number = 1; i < width - 1; i++)
			{
				for (var j:Number = 1; j < height - 1; j++)
				{
					var nx:Number = -0.5 * (getDisplacement(displcamentBitmapData, i + 1, j) - getDisplacement(displcamentBitmapData, i - 1, j));
					var ny:Number = -0.5 * (getDisplacement(displcamentBitmapData, i, j + 1) - getDisplacement(displcamentBitmapData, i, j - 1));
					
					setNormal(normalBitmapData, i, j, new Vector3D(nx, ny, nz));
				}
			}
			
			// calculate the normals over the top and bottom edges (second order forward and backward finite difference schemes and first order centered)
			for (i = 1; i < width - 1; i++)
			{
				nx = -0.5 * (getDisplacement(displcamentBitmapData, i + 1, 0) - getDisplacement(displcamentBitmapData, i - 1, 0));
				ny = -0.333333 * (-3 * getDisplacement(displcamentBitmapData, i, 0) + 4 * getDisplacement(displcamentBitmapData, i, 1) - getDisplacement(displcamentBitmapData, i, 2));
				
				setNormal(normalBitmapData, i, 0, new Vector3D(nx, ny, nz));
				
				nx = -0.5 * (getDisplacement(displcamentBitmapData, i + 1, height - 1) - getDisplacement(displcamentBitmapData, i - 1, height - 1));
				ny = 0.333333 * (-3 * getDisplacement(displcamentBitmapData, i, height - 1) + 4 * getDisplacement(displcamentBitmapData, i, height - 2) - getDisplacement(displcamentBitmapData, i, height - 3));
				
				setNormal(normalBitmapData, i, height - 1, new Vector3D(nx, ny, nz));
			}
			
			// calculate the normals over the left and right edges (second order forward and backward finite difference schemes and first order centered)
			for (j = 1; j < height - 1; j++)
			{
				
				nx = -0.333333 * (-3 * getDisplacement(displcamentBitmapData, 0, j) + 4 * getDisplacement(displcamentBitmapData, 1, j) - getDisplacement(displcamentBitmapData, 2, 1));
				ny = -0.5 * (getDisplacement(displcamentBitmapData, 0, j + 1) - getDisplacement(displcamentBitmapData, 0, j - 1));
				setNormal(normalBitmapData, 0, j, new Vector3D(nx, ny, nz));
				
				nx = 0.333333 * (-3 * getDisplacement(displcamentBitmapData, width - 1, j) + 4 * getDisplacement(displcamentBitmapData, width - 2, j) - getDisplacement(displcamentBitmapData, width - 3, 1));
				ny = -0.5 * (getDisplacement(displcamentBitmapData, width - 1, j + 1) - getDisplacement(displcamentBitmapData, width - 1, j - 1));
				setNormal(normalBitmapData, width - 1, j, new Vector3D(nx, ny, nz));
			}
			
			// calculate the normals at the orners (second order forward and backward finite difference schemes)
			nx = -0.333333 * (-3 * getDisplacement(displcamentBitmapData, 0, 0) + 4 * getDisplacement(displcamentBitmapData, 1, 0) - getDisplacement(displcamentBitmapData, 2, 0));
			ny = -0.333333 * (-3 * getDisplacement(displcamentBitmapData, 0, 0) + 4 * getDisplacement(displcamentBitmapData, 0, 1) - getDisplacement(displcamentBitmapData, 0, 2));
			setNormal(normalBitmapData, 0, 0, new Vector3D(nx, ny, nz));
			
			nx = -0.333333 * (-3 * getDisplacement(displcamentBitmapData, 0, height - 1) + 4 * getDisplacement(displcamentBitmapData, 1, height - 1) - getDisplacement(displcamentBitmapData, 2, height - 1));
			ny = 0.333333 * (-3 * getDisplacement(displcamentBitmapData, 0, height - 1) + 4 * getDisplacement(displcamentBitmapData, 0, height - 2) - getDisplacement(displcamentBitmapData, 0, height - 3));
			setNormal(normalBitmapData, 0, height - 1, new Vector3D(nx, ny, nz));
			
			nx = 0.333333 * (-3 * getDisplacement(displcamentBitmapData, width - 1, 0) + 4 * getDisplacement(displcamentBitmapData, width - 2, 0) - getDisplacement(displcamentBitmapData, width - 3, 0));
			ny = -0.333333 * (-3 * getDisplacement(displcamentBitmapData, width - 1, 0) + 4 * getDisplacement(displcamentBitmapData, width - 1, 1) - getDisplacement(displcamentBitmapData, width - 1, 2));
			setNormal(normalBitmapData, width - 1, 0, new Vector3D(nx, ny, nz));
			
			nx = 0.333333 * (-3 * getDisplacement(displcamentBitmapData, width - 1, height - 1) + 4 * getDisplacement(displcamentBitmapData, width - 2, height - 1) - getDisplacement(displcamentBitmapData, width - 3, height - 1));
			ny = 0.333333 * (-3 * getDisplacement(displcamentBitmapData, width - 1, height - 1) + 4 * getDisplacement(displcamentBitmapData, width - 1, height - 2) - getDisplacement(displcamentBitmapData, width - 1, height - 3));
			setNormal(normalBitmapData, width - 1, height - 1, new Vector3D(nx, ny, nz));
			
			// Create the normal map
			normalMap = new Bitmap(normalBitmapData);
			return normalMap;
		}
	
	}
}
