/* 
 *  This file is part of the ScaleGraph project (http://scalegraph.org).
 * 
 *  This file is licensed to You under the Eclipse Public License (EPL);
 *  You may not use this file except in compliance with the License.
 *  You may obtain a copy of the License at
 *      http://www.opensource.org/licenses/eclipse-1.0.php
 * 
 *  (C) Copyright ScaleGraph Team 2011-2012.
 */
package org.scalegraph.graph;

import org.scalegraph.util.DistMemoryChunk;

public struct EdgeList[T] {
	public val src :DistMemoryChunk[T];
	public val dst :DistMemoryChunk[T];
	
	public def this(src :DistMemoryChunk[T], dst :DistMemoryChunk[T]) {
		this.src = src;
		this.dst = dst;
	}
	
	public def del() {
		src.del();
		dst.del();
	}

}
