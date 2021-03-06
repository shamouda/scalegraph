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

package org.scalegraph.util;

import x10.compiler.Inline;
import x10.compiler.Ifdef;
import x10.compiler.Ifndef;
import x10.compiler.Native;
import x10.compiler.NativeRep;

/** High performance array. The followings are the advantages of MemoryChunk compared with x10.lang.Array.<br>
 * <p><dl><dt>Indexing with Long</dt> <dd>The maximum length of x10.lang.Array is 2^31 since it uses Int for indexing.
 * In constract, the maximum length of MemoryChunk, which uses Long for indexing, is 2^63.</dd>
 * <dt>High performance serialization and deserialization</dt> <dd>Serialization and deserialization is 
 * implemented as a memcpy operation. In the case of primitive types, there are no performance difference
 * between x10.lang.Array and MemoryChunk. But for other types, the serialization/deserialization speed of
 * MemoryChunk is faster than x10.lang.Array for about 70%.</dd>
 * <dt>Interior pointer</dt> <dd>MemoryChunk can refer interior of another MemoryChunk. This may reduce memory allocation/deallocation costs signifacantly.</dd>
 * <dt>Reducing GC cost (C++ backend only)</dt> <dd>MemoryChunk allocates memory declaring the memory has no reference so that GC can skip reading the elements of MemoryChunk.</dd>
 * <dt>Direct access with pointer (C++ backend only)</dt> <dd>The generated code for accessing an element of MemoryChunk does not have any function call.
 * Accessing the elements of MemoryChunk is 40% faster than accessing the elements of x10.lang.Array.</dd></p>
 * <p>Limitations: Current memory chunk only support non-reference data. The supports for the class or any data structures which include class members are imcomplete.
 *  DO NOT USE MEMORYCHUNK TO STORE ANY DATA STRUCTURES THAT INCLUDE REFERENCES. </p>
 */
public struct MemoryChunk[T] implements Iterable[T] {
	val data :MemoryChunkData[T];
	
	/** The purpose of this class is to distribute continuous memory region into several memory chunks.
	 */
	public static class Distributor[T] {
		private val outer :MemoryChunk[T];
		private var offset :Long = 0;
		
		/** Initializes new distributor with zero offset.
	 	*/
		public def this(outer :MemoryChunk[T]) {
			this.outer = outer;
		}
		
		/** Returns the memory chunk from the current offset with the specified size and progress the current position by size.
		 * @param size The size of returning MemoryChunk.
		 */
		public def next(size :Long) {
			val mc = outer.subpart(offset, size);
			offset += size;
			return mc;
		}
		
		/** Returns the memory chunk from the current offset with the specified size and progress the current position by size.
		 * @param size The size of returning MemoryChunk.
		 */
		public def next(size :Int) {
			val mc = outer.subpart(offset, size);
			offset += size;
			return mc;
		}
		
		/** Returns the size of remaining memory region.
		 */
		public def remain() = outer.size() - offset;
		
		/** Checks whether whole memory is allocted and there is no over allocation.
		 */
		public def checkFinish() {
			if(offset != outer.size()) // TODO:
				throw new ArrayIndexOutOfBoundsException("Out of bounds. Please, check the offset and the size.");
		}
	}

	private def this(size :Long, alignment :Int, zeroed :Boolean, filename :MemoryPointer[Byte], num :Int) {
		if(size < 0L) // TODO:
			throw new ArrayIndexOutOfBoundsException("Size must be nonnegative interger, size: "+size);
		data = MemoryChunkData.make[T](size, alignment, zeroed, filename, num);
	}

	private def this(size :Long, init :(Long) => T, filename :MemoryPointer[Byte], num :Int) {
		if(size < 0L) // TODO:
			throw new ArrayIndexOutOfBoundsException("Size must be nonnegative interger, size: "+size);
		data = MemoryChunkData.make_nocons[T](size, 0n, false, filename, num);
		for(i in 0L..(size-1L)) {
			data(i) = init(i);
		}
	}
	
	private def this(rail :Rail[T], offset :Long, size :Long) {
		if(offset < 0 || offset + size > rail.size)
			throw new ArrayIndexOutOfBoundsException("Out of bounds. Please, check the offset and the size.");
		this.data = MemoryChunkData.make[T](rail, offset, size);
	}
	
	def this(data :MemoryChunkData[T]) {
		this.data = data;
	}
	
	private def this(data :MemoryChunkData[T], size :Long, init :(Long) => T, filename :MemoryPointer[Byte], num :Int) {
		for(i in 0L..(size-1L)) {
			data(i) = init(i);
		}
		this.data = data;
	}
	
	/** Creates an empty memory chunk.
	 */
	public def this() {
		data = MemoryChunkData.make[T](0L, 0n, false);
	}
	
	public static def make[T]() = new MemoryChunk[T]();
	
	/** Creates a memory chunk with the specified number of elements. This method is equivalent to this(size, 0, false).
	 * @param size The number of elements
	 */
	//@Native("c++", "org::scalegraph::util::MemoryChunk<#T >::_make(#size, 0, false, (x10_byte*)(void*)__FILE__, __LINE__)")
	//public static native def make[T](size :Long) :MemoryChunk[T];

	@Native("c++", "org::scalegraph::util::MemoryChunk<#T >::_make(org::scalegraph::util::MakeStruct<#T >::make(#size, 0, false, (char*)(void*)__FILE__, __LINE__))")
	public static native def make[T](size :Long) :MemoryChunk[T];

	
	/** Creates memory chunk with the specified size and alignment.
	 * @param size The number of elements
	 * @param alignment The alignment for the backing memory
	 */
	//@Native("c++", "org::scalegraph::util::MemoryChunk<#T >::_make(#size, #alignment, false, (x10_byte*)(void*)__FILE__, __LINE__)")
	//public static native def make[T](size :Long, alignment :Int) :MemoryChunk[T];
	@Native("c++", "org::scalegraph::util::MemoryChunk<#T >::_make(org::scalegraph::util::MakeStruct<#T >::make(#size, #alignment, false, (char*)(void*)__FILE__, __LINE__))")
	public static native def make[T](size :Long, alignment :Int) :MemoryChunk[T];

	/** Creates memory chunk with the specified size and alignment.
	 * @param size The number of elements
	 * @param alignment The alignment for the backing memory
	 * @param zeroed Whether the allocated memory is filled with zero or not.
	 */
	//@Native("c++", "org::scalegraph::util::MemoryChunk<#T >::_make(#size, #alignment, #zeroed, (x10_byte*)(void*)__FILE__, __LINE__)")
	//public static native def make[T](size :Long, alignment :Int, zeroed :Boolean) :MemoryChunk[T];
	@Native("c++", "org::scalegraph::util::MemoryChunk<#T >::_make(org::scalegraph::util::MakeStruct<#T >::make(#size, #alignment, #zeroed, (char*)(void*)__FILE__, __LINE__))")
	public static native def make[T](size :Long, alignment :Int, zeroed :Boolean) :MemoryChunk[T];

	@Native("c++", "org::scalegraph::util::MemoryChunk<#T >::_make(#size, #init, (x10_byte*)(void*)__FILE__, __LINE__)")
	public static native def make[T](size :Long, init :(Long) => T) :MemoryChunk[T];
	//@Native("c++", "org::scalegraph::util::MemoryChunk<#T >::_make(org::scalegraph::util::MakeStruct<#T >::make_nocons(#size, 0, false, (char*)(void*)__FILE__, __LINE__),#size, #init, (x10_byte*)(void*)__FILE__, __LINE__)")
	//public static native def make[T](size :Long, init :(Long) => T) :MemoryChunk[T];
	
	/** Creates memory chunk which refers subsection of the specified Rail.
	 * @param rail Rail whose subsection is used
	 * @param offset The offset from which the subsection starts
	 * @param size The number of elements of the subsection
	 */
	public static def make[T](rail :Rail[T], offset :Long, size :Long) = new MemoryChunk[T](rail, offset, size);
	
	/** Creates memory chunk which refers subsection of the specified Rail.
	 * @param rail Rail whose subsection is used
	 * @param offset The offset from which the subsection starts
	 * @param size The number of elements of the subsection
	 */
	public static def make[T](rail :Rail[T], offset :Int, size :Int) = new MemoryChunk[T](rail, offset, size);
	
	/** Creates memory chunk which refers subsection of the specified Rail. This method is equivalent to this(rail, offset, (rail.size - offset)).
	 * @param rail Rail whose subsection is used
	 * @param offset The offset from which the subsection starts
	 */
	public static def make[T](rail :Rail[T], offset :Long) = new MemoryChunk[T](rail, offset, (rail.size - offset) as Long);
	
	/** Creates memory chunk which refers the subsection of the specified Rail. This method is equivalent to this(rail, offset, (rail.size - offset)).
	 * @param rail Rail whose subsection is used
	 * @param offset The offset from which the subsection starts
	 */
	public static def make[T](rail :Rail[T], offset :Int) = new MemoryChunk[T](rail, offset as Long, (rail.size - offset) as Long);
	
	/** Creates memory chunk which refers the subsection of the specified Rail. This method is equivalent to this(rail, 0, rail.size).
	 * @param rail Rail whose subsection is used
	 */
	public static def make[T](rail :Rail[T]) = new MemoryChunk[T](rail, 0L, rail.size as Long);
	
	/** Free memory. Once you free MemoryChunk,
	 * you can not use any MemoryChunk which point to the released memory.
	 * 
	 */
	public def del() {
		data.del();
	}
	
	public def toString() :String {
		val sb = new x10.util.StringBuilder();
		sb.add("[");
		val sz = Math.min(size(), 10L);
		for (var i:Int = 0n; i < sz; ++i) {
			if (i > 0) sb.add(",");
			sb.add("" + data(i));
		}
		if (sz < size()) sb.add("...(omitted " + (size() - sz) + " elements)");
		sb.add("]");
		return sb.toString();
	}
	
	// for java
	def raw() = data;
	
	/** Returens the internal pointer object.
	 */
	public def pointer() :MemoryChunkData.Pointer[T] {
		@Ifndef("NO_BOUNDS_CHECKS") {
			if(!data.isValid())
				throw new ArrayIndexOutOfBoundsException("This MemoryChunk is released.");
		}
		return data.pointer();
	}

	/** Returens the number of elements.
	 */
	public def size() :Long = data.size;
	
	/** Returns initialized distributor object.
	 */
	public def distributor() = new Distributor(this);
	
	/** Returns the range.
	 */
	public @Inline def range() = 0L..(data.size-1L);
	
	private static class MCIterator[T] implements Iterator[T] {
		val data :MemoryChunkData[T];
		var cur :Long;
		
		public def this(data :MemoryChunkData[T]) {
			this.data = data;
		//	this.cur = 0L;
		}
		
		public def hasNext() :Boolean = (cur < data.size);
		public def next() :T = data(cur++);
	}

	/** Returns the iterator over values.
	 */
	public @Inline def iterator() = new MCIterator[T](data);
	
	/** Creates new array and copy the elements to it and returns it.
	 */
	public def toRail() = new Rail[T](data.size, (i:Long)=>data(i));

	/** Allocates new memory and copy the elements to it and returns it.
	 */
	public def clone() {
		val ret = MemoryChunk.make[T](size());
		copy(this, 0L, ret, 0L, size());
		return ret;
	}
	
	/** Returns the new memory chunk that refers the subpart of base memory chunk.
	 * @param offset The offset which the subsection start from
	 * @param size The size of the subsection
	 */
	public def subpart(offset :Long, size :Long) {
		@Ifndef("NO_BOUNDS_CHECKS") {
			if(!data.isValid())
				throw new ArrayIndexOutOfBoundsException("This MemoryChunk is released.");
			if(offset < 0 || size < 0 || offset + size > data.size)
				throw new ArrayIndexOutOfBoundsException("specified range is not contained in MemoryChunk");
		}
		return MemoryChunk[T](data.subpart(offset, size));
	}
	
	/** Returns the value of the indexed place.
	 * @param index The index where you want to set the value to.
	 */
	public @Inline operator this(index:int):T {
		@Ifndef("NO_BOUNDS_CHECKS") {
			if(!data.isValid())
				throw new ArrayIndexOutOfBoundsException("This MemoryChunk is released.");
			if(index < 0 || index >= data.size)
				throw new ArrayIndexOutOfBoundsException("index (" + index + ") not contained in MemoryChunk");
		}
		return data(index);
	}

	/** Returns the indexed value.
	 * @param index The index where you want to set the value to.
	 */
	public @Inline operator this(index:Long):T {
		@Ifndef("NO_BOUNDS_CHECKS") {
			if(!data.isValid())
				throw new ArrayIndexOutOfBoundsException("This MemoryChunk is released.");
			if(index < 0 || index >= data.size)
				throw new ArrayIndexOutOfBoundsException("index (" + index + ") not contained in MemoryChunk");
		}
		return data(index);
	}

	/** Sets new value to indexed place
	 * @param index The index where you want to set the value to.
	 */
	public @Inline operator this(index:int)=(value:T):T{self==value} {
		@Ifndef("NO_BOUNDS_CHECKS") {
			if(!data.isValid())
				throw new ArrayIndexOutOfBoundsException("This MemoryChunk is released.");
			if(index < 0 || index >= data.size)
				throw new ArrayIndexOutOfBoundsException("index (" + index + ") not contained in MemoryChunk");
		}
		data(index) = value;
		return value;
	}

	/** Sets new value to indexed place
	 * @param index The index where you want to set the value to.
	 */
	public @Inline operator this(index:Long)=(value:T):T{self==value} {
		@Ifndef("NO_BOUNDS_CHECKS") {
			if(!data.isValid())
				throw new ArrayIndexOutOfBoundsException("This MemoryChunk is released.");
			if(index < 0 || index >= data.size)
				throw new ArrayIndexOutOfBoundsException("index (" + index + ") not contained in MemoryChunk");
		}
		data(index) = value;
		return value;
	}
	
	public @Inline def setUnchecked(index :Int, value :T) { data(index) = value; }
	public @Inline def setUnchecked(index :Long, value :T) { data(index) = value; }

	public @Inline def getUnchecked(index :Int) = data(index);
	public @Inline def getUnchecked(index :Long) = data(index);

	/** Sets new value to indexed place
	 * @param index The index where you want to set the value to.
	 */
	public @Inline def atomicAdd(index:Long, value:T):T {
		@Ifndef("NO_BOUNDS_CHECKS") {
			if(!data.isValid())
				throw new ArrayIndexOutOfBoundsException("This MemoryChunk is released.");
			if(index < 0 || index >= data.size)
				throw new ArrayIndexOutOfBoundsException("index (" + index + ") not contained in MemoryChunk");
		}
		return data.atomicAdd(index, value);
	}

	/** Sets new value to indexed place
	 * @param index The index where you want to set the value to.
	 */
	public @Inline def atomicOr(index:Long, value:T):T {
		@Ifndef("NO_BOUNDS_CHECKS") {
			if(!data.isValid())
				throw new ArrayIndexOutOfBoundsException("This MemoryChunk is released.");
			if(index < 0 || index >= data.size)
				throw new ArrayIndexOutOfBoundsException("index (" + index + ") not contained in MemoryChunk");
		}
		return data.atomicOr(index, value);
	}

	/** Sets new value to indexed place
	 * @param index The index where you want to set the value to.
	 */
	public @Inline def atomicAnd(index:Long, value:T):T {
		@Ifndef("NO_BOUNDS_CHECKS") {
			if(!data.isValid())
				throw new ArrayIndexOutOfBoundsException("This MemoryChunk is released.");
			if(index < 0 || index >= data.size)
				throw new ArrayIndexOutOfBoundsException("index (" + index + ") not contained in MemoryChunk");
		}
		return data.atomicAnd(index, value);
	}

	/** Atomic XOR. This operation is equivalent to the following code.
	 * 	atomic {
	 * 		if(
	 * 	}
	 * @param index The index where you want to set the value to.
	 * @param value 
	 */
	public @Inline def atomicXor(index:Long, value:T):T {
		@Ifndef("NO_BOUNDS_CHECKS") {
			if(!data.isValid())
				throw new ArrayIndexOutOfBoundsException("This MemoryChunk is released.");
			if(index < 0 || index >= data.size)
				throw new ArrayIndexOutOfBoundsException("index (" + index + ") not contained in MemoryChunk");
		}
		return data.atomicXor(index, value);
	}

	/** CAS (Compare And Swap). This operation is equivalent to the following code.
	 * 	atomic { 
	 * 		if(mc(index) == expect) {
	 *			mc(index) = value;
	 *			return true;
	 *		}
	 *		else {
	 *			return false;
	 *		}
	 *	}
	 * @param index The index where you want to set the value to.
	 * @param expect 
	 * @param value
	 */
	public @Inline def atomicCAS(index:Long, expect:T, value:T):Boolean {
		@Ifndef("NO_BOUNDS_CHECKS") {
			if(!data.isValid())
				throw new ArrayIndexOutOfBoundsException("This MemoryChunk is released.");
			if(index < 0 || index >= data.size)
				throw new ArrayIndexOutOfBoundsException("index (" + index + ") not contained in MemoryChunk");
		}
		return data.atomicCAS(index, expect, value);
	}
	
	/** Copies the elements of the MemoryChunks
	 * @param src The source data
	 * @param srcIndex The offset from which the source data is copied
	 * @param dst The destination memory
	 * @param dstIndex The offset from which the source data is copied
	 * @param numElems The number of elements to copy
	 */
	public static def copy[T](src:MemoryChunk[T], srcIndex:Long,
			dst:MemoryChunk[T], dstIndex:Long, numElems:Long):void {
		@Ifndef("NO_BOUNDS_CHECKS") {
			if(!src.data.isValid() || !dst.data.isValid())
				throw new ArrayIndexOutOfBoundsException("This MemoryChunk is released.");
			if(numElems < 0 || srcIndex < 0 || dstIndex < 0)
				throw new IllegalArgumentException();
			if(src.size() < srcIndex + numElems || dst.size() < dstIndex + numElems)
				throw new ArrayIndexOutOfBoundsException("copy: out of range");
		}
		MemoryChunkData.copy(src.data, srcIndex, dst.data, dstIndex, numElems);
	}
	
	/** Copies the elements of the MemoryChunks
	 * @param src The source data
	 * @param dst The destination memory
	 */
	public static def copy[T](src:MemoryChunk[T], dst:MemoryChunk[T]):void {
		@Ifndef("NO_BOUNDS_CHECKS") {
			if(!src.data.isValid() || !dst.data.isValid())
				throw new ArrayIndexOutOfBoundsException("This MemoryChunk is released.");
			if(src.size() != dst.size())
				throw new ArrayIndexOutOfBoundsException("copy: out of range");
		}
		MemoryChunkData.copy(src.data, 0l, dst.data, 0l, src.size());
	}

	public static def asyncCopy[T](src :MemoryChunk[T], dst :GlobalMemoryChunk[T], dstIndex :Long) {
		MemoryChunkData.asyncCopy(src.data, dst, dstIndex);
	}
	
	public static def asyncCopy[T](src :GlobalMemoryChunk[T], srcIndex :Long, dst :MemoryChunk[T]) {
		MemoryChunkData.asyncCopy(src, srcIndex, dst.data);
	}
	
	/** Creates and returns an empty memory chunk.
	 */
	public static def getNull[T]() = MemoryChunk.make[T](0);
	
	@Native("c++", "org::scalegraph::util::get_gc_heap_size()")
	public static native def getGCMemSize() :Long;
	
	@Native("c++", "org::scalegraph::util::ExpMemState.totalSize")
	public static native def getExpMemSize() :Long;
	
	public static def getMemSize() = getGCMemSize() + getExpMemSize();
}
