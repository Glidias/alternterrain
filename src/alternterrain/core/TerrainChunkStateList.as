package alternterrain.core 
{
	import flash.display3D.Context3D;
	/**
	 * ...
	 * @author Glenn Ko
	 */
	public class TerrainChunkStateList 
	{
		
		
			public var head : TerrainChunkState;
			public var tail : TerrainChunkState;

			public function append( entity : TerrainChunkState ) : void  // enqueue
			{
				entity.parent = this;
				if( head )
				{
					tail.next = entity;
					entity.prev = tail;
					entity.next = null;
					tail = entity;
				}
				else
				{	
					head = tail = entity;
					entity.next = entity.prev = null;
				}
			}
			
			public function allocate(amt:int, numVertices:int, data32PerVertex:int, context:Context3D):void {
				
				if (amt == 0) return;
				amt--;
				var headInstance:TerrainChunkState = new TerrainChunkState();
				headInstance.vertexBuffer = context.createVertexBuffer(numVertices, data32PerVertex);
				headInstance.parent = this;
				var lastValidInstance:TerrainChunkState = headInstance;
				var lastInstance:TerrainChunkState;
				while (--amt > -1) {
					lastInstance = new TerrainChunkState();
					lastInstance.vertexBuffer = context.createVertexBuffer(numVertices, data32PerVertex);
					lastInstance.parent = this;
					lastInstance.prev  = lastValidInstance;
					lastValidInstance.next = lastInstance;
					lastValidInstance = lastInstance;
				}
				if (head!= null) {  // prepend
					if (lastInstance) {
						lastInstance.next = head;
						head.prev = lastInstance;
					}
					else {
						headInstance.next = head;
						head.prev = headInstance;
					}
				}
				else {
					head = headInstance;
					tail = lastInstance != null ? lastInstance : head;
				}
			}
			
			public function getAvailable():TerrainChunkState { // dequeue from head (FIFO queue)
				var entity:TerrainChunkState = head;
				if (entity == null) return null;
				head = head.next;
				if ( tail == entity) tail = null;
				if (entity.next) entity.next.prev =  null;
				return entity;
			}

			public function remove( entity : TerrainChunkState ) : void
			{
				if ( head == entity)
				{
				head = head.next;
				}
				if ( tail == entity)
				{
				tail = tail.prev;
				}

				if (entity.prev)
				{
				entity.prev.next = entity.next;
				}

				if (entity.next)
				{
				entity.next.prev = entity.prev;
				}
				entity.parent = null;
				entity.next = null;
				entity.prev = null;
				// N.B. Don't set node.next and node.prev to null because that will break the list iteration if node is the current node in the iteration.
			}

			public function removeAll() : void
			{
				while( head )
				{
					var entity : TerrainChunkState = head;
					head = head.next;
					entity.prev = null;
					entity.next = null;
					entity.parent = null;
				}
				tail = null;
			}
		}
		
	

}