package org.scalegraph.concurrent;

import x10.compiler.Inline;
import x10.util.IndexedMemoryChunk;
import x10.util.ArrayList;
import x10.util.Timer;
import org.scalegraph.util.LongIndexedMemoryChunk;
import org.scalegraph.util.MathAppend;
import org.scalegraph.util.MemoryChunk;

/** Thread Parallel Library.
 */
public class Parallel {
	static val threashold1 = 16;
    static val threashold2 = 16;
	static val debug = false;
	private static @Inline def debugln (str:String) : void {
		if (debug) {
			Console.OUT.println("" + Timer.milliTime() + ":Hash: " + here + "(" + Runtime.workerId() + ")" + str);
			Console.OUT.flush();
		}
	}
    private static def merge[T](a:IndexedMemoryChunk[T], b:IndexedMemoryChunk[T], cmp:(T,T)=>Int) {
        val arr = IndexedMemoryChunk.allocateUninitialized[T](a.length() + b.length());
        val aSize = a.length();
        val bSize = b.length();
    	var x: T = a(0);
    	var y: T = b(0);
    	var i: Long = 0;
    	var j: Long = 0;
    	var k: Long = 0;

    	while (true) {
    		if (cmp(x, y) <= 0) {
    			arr(k) = x;
    			++i; ++k;
    			if (i >= aSize) break;
    			x = a(i);
    		} else {
    			arr(k) = y;
    			++j; ++k;
    			if (j >= bSize) break;
    			y = b(j);
    		}
    	}
    }
    private static def exch[T](a:IndexedMemoryChunk[T], i:Long, j:Long):void {
        val temp = a(i);
        a(i) = a(j);
        a(j) = temp;
    }

    private static @Inline def exch[T](a:MemoryChunk[T], i:Long, j:Long):void {
    	val temp = a(i);
    	a(i) = a(j);
    	a(j) = temp;
    }

    private static @Inline def exch[T, U](k:MemoryChunk[T], v:MemoryChunk[U], i:Long, j:Long):void {
    	val t1 = k(i);
    	k(i) = k(j);
    	k(j) = t1;
    	val t2 = v(i);
    	v(i) = v(j);
    	v(j) = t2;
    }

    public static def sort[T](a:MemoryChunk[T], cmp:(T, T)=>Long) {
        finish _sort[T](a, MathAppend.ceilLog2(Runtime.NTHREADS as Long) * 4, 0L, a.size(), cmp);
    }

    public static def sort[T](a:MemoryChunk[T], proc : Int, cmp:(T, T)=>Long) {
        finish _sort[T](a, proc, 0L, a.size(), cmp);
    }

    public static def sort[T, U](k:MemoryChunk[T], v:MemoryChunk[U], cmp:(T, T)=>Long) {
        finish _sort[T, U](k, v, MathAppend.ceilLog2(Runtime.NTHREADS as Long) * 4, 0L, k.size(), cmp);
    }

    public static def sort[T, U](k:MemoryChunk[T], v:MemoryChunk[U], proc : Int, cmp:(T, T)=>Long) {
        finish _sort[T, U](k, v, proc, 0L, k.size(), cmp);
    }

    public static def _sort[T](a:MemoryChunk[T], proc:Int, lo:Long, hi:Long, cmp:(T, T)=>Long) {
        debugln("_sort");
        if (lo >= hi - 1) {
            return;
        }
        val nSample = 21;
        val sample:ArrayList[T] = new ArrayList[T](Math.min(nSample as Long, hi - lo) as Int);
        for (var i:Int = 0; i < nSample; i++) {
            sample(i) = a(lo + ((hi - lo) / nSample) * i);
        }
        sample.sort((lhs:T, rhs:T)=>{
                if (cmp(lhs, rhs) > 0L) {return 1;}
                else if (cmp(lhs, rhs) == 0L) {return 0;}
                else {return -1;}});
        if (proc > 0) {
            //val pivot = median[T](a(lo), a((lo + hi) / 2), a(hi - 1), cmp);
            val pivot = sample(nSample / 2);
            val cut = unguardedPartition[T](a, lo, hi, pivot, cmp);
            async _sort[T](a, proc - 1, lo, cut, cmp);
            _sort[T](a, proc - 1, cut, hi, cmp);
        } else {
            introSort[T](a, lo, hi, cmp);
        }
    }

    public static def _sort[T, U](k:MemoryChunk[T], v:MemoryChunk[U], proc:Int, lo:Long, hi:Long, cmp:(T, T)=>Long) {
        if (lo >= hi - 1) {
            return;
        }
        if (proc > 0) {
            val pivot = median[T](k(lo), k((lo + hi) / 2), k(hi - 1), cmp);
            val cut = unguardedPartition[T, U](k, v, lo, hi, pivot, cmp);
            async _sort[T, U](k, v, proc - 1, lo, cut, cmp);
            _sort[T, U](k, v, proc - 1, cut, hi, cmp);
        } else {
            introSort[T, U](k, v, lo, hi, cmp);
        }
    }


    public static def introSort[T](a:MemoryChunk[T], lo:Long, hi:Long, cmp:(T,T)=>Long) {
    	if (lo != hi) {
    		introSortLoop[T](a, lo, hi, cmp, MathAppend.ceilLog2(hi - lo) * 2);
            finalInsertionSort[T](a, lo, hi, cmp);
        }
    }

    public static def introSort[T, U](k:MemoryChunk[T], v:MemoryChunk[U], lo:Long, hi:Long, cmp:(T,T)=>Long) {
    	if (lo != hi) {
    		introSortLoop[T, U](k, v, lo, hi, cmp, MathAppend.ceilLog2(hi - lo) * 2);
            finalInsertionSort[T, U](k, v, lo, hi, cmp);
        }
    }

    private static def unguardedPartition[T](a:MemoryChunk[T], lo:Long, hi:Long, pivot:T, cmp:(T,T)=>Long) {
    	var first:Long = lo;
    	var last:Long = hi;
    	while (true) {
    		while (cmp(a(first), pivot) < 0L) ++first;
    		--last;
    		while (cmp(pivot, a(last)) < 0L) --last;
    		if (!(first < last)) {
    			return first;
    		}
    		exch(a, first, last);
    		++first;
    	}
    }

    private static def unguardedPartition[T, U](k:MemoryChunk[T], v:MemoryChunk[U], lo:Long, hi:Long, pivot:T, cmp:(T,T)=>Long) {
    	var first:Long = lo;
    	var last:Long = hi;
    	while (true) {
    		while (cmp(k(first), pivot) < 0L) ++first;
    		--last;
    		while (cmp(pivot, k(last)) < 0L) --last;
    		if (!(first < last)) {
    			return first;
    		}
    		exch(k, v, first, last);
    		++first;
    	}
    }

    private static def finalInsertionSort[T](a:MemoryChunk[T], lo:Long, hi:Long, cmp:(T,T)=>Long) {
    	if (hi - lo > threashold1) {
    		insertionSort[T](a, lo, lo + threashold1, cmp);
    		unguardedInsertionSort[T](a, lo + threashold1, hi, cmp);
    	} else {
    		insertionSort[T](a, lo, hi, cmp);
    	}
    }

    private static def finalInsertionSort[T, U](k:MemoryChunk[T], v:MemoryChunk[U], lo:Long, hi:Long, cmp:(T,T)=>Long) {
    	if (hi - lo > threashold2) {
    		insertionSort[T, U](k, v, lo, lo + threashold2, cmp);
    		unguardedInsertionSort[T, U](k, v, lo + threashold2, hi, cmp);
    	} else {
    		insertionSort[T, U](k, v, lo, hi, cmp);
    	}
    }

    private static def unguardedInsertionSort[T](a:MemoryChunk[T], lo:Long, hi:Long, cmp:(T,T)=>Long) {
        for (var i:Long = lo; i < hi; i++) {
            unguardedLinearInsert[T](a, i, a(i), cmp);
        }
    }

    private static def unguardedInsertionSort[T, U](k:MemoryChunk[T], v:MemoryChunk[U], lo:Long, hi:Long, cmp:(T,T)=>Long) {
        for (var i:Long = lo; i < hi; i++) {
            unguardedLinearInsert[T, U](k, v, i, k(i), v(i), cmp);
        }
    }

    public static def insertionSort[T](a:MemoryChunk[T], lo:Long, hi:Long, cmp:(T,T)=>Long) {
    	if (lo == hi) {return;}

    	for (var i:Long = lo + 1; i < hi; i++) {
    		val v = a(i);
    		if (cmp(v, a(lo)) < 0L) {
    			var j:Long = i;
    			while (j > lo) {--j; a(j + 1) = a(j);}
    			a(lo) = v;
    		} else {
    			unguardedLinearInsert(a, i, v, cmp);
    		}
    	}
    }

    private static def insertionSort[T, U](k:MemoryChunk[T], v:MemoryChunk[U], lo:Long, hi:Long, cmp:(T,T)=>Long) {
    	if (lo == hi) {return;}

    	for (var i:Long = lo + 1; i < hi; i++) {
    		val kv = k(i);
            val vv = v(i);
    		if (cmp(kv, k(lo)) < 0L) {
    			var j:Long = i;
    			while (j > lo) {--j; k(j + 1) = k(j); v(j + 1) = v(j);}
    			k(lo) = kv;
                v(lo) = vv;
    		} else {
    			unguardedLinearInsert[T, U](k, v, i, kv, vv, cmp);
    		}
    	}
    }

    private static def unguardedLinearInsert[T](a:MemoryChunk[T], last:Long, v:T, cmp:(T,T)=>Long) {
    	var last_:Long = last;
    	var next:Long = last_;
    	--next;
    	while (cmp(v, a(next)) < 0L) {
    		a(last_) = a(next);
    		last_ = next;
    		--next;
    	}
    	a(last_) = v;
    }

    private static def unguardedLinearInsert[T, U](k:MemoryChunk[T], v:MemoryChunk[U], last:Long, kv:T, vv:U, cmp:(T,T)=>Long) {
    	var last_:Long = last;
    	var next:Long = last_;
    	--next;
    	while (cmp(kv, k(next)) < 0L) {
    		k(last_) = k(next);
            v(last_) = v(next);
    		last_ = next;
    		--next;
    	}
    	k(last_) = kv;
        v(last_) = vv;
    }


    private static def median[T](a:T, b:T, c:T, cmp:(T,T)=>Long) {
    	if (cmp(a, b) < 0L) {
    		if (cmp(b, c) < 0L) {
    			return b; // a <  b < c
    		} else if (cmp(a, c) < 0L) {
    			return c; // a < c <= b
    		} else {
    			return a; // c <= a < b
    		}
    	} else if (cmp(a, c) < 0L) {
    		return a; // b <= a < c
    	} else if (cmp(b, c) < 0L) {
    		return c; // b < c <= a
    	} else {
    		return b; // c <= b <= a
    	}
    }

    private static def makeHeap[T](a:MemoryChunk[T], lo:Long, hi:Long, cmp:(T,T)=>Long) {
        if (hi - lo < 2) {
            return;
        }
        val len = hi - lo;
        var parent:Long = (len - 2L) / 2L;

        while (true) {
            adjustHeap(a, lo, parent, len, a(lo + parent), cmp);
            if (parent == 0L) {
                return;
            }
            parent--;
        }
    }

    private static def makeHeap[T, U](k:MemoryChunk[T], v:MemoryChunk[U], lo:Long, hi:Long, cmp:(T,T)=>Long) {
        if (hi - lo < 2) {
            return;
        }
        val len = hi - lo;
        var parent:Long = (len - 2L) / 2L;

        while (true) {
            adjustHeap(k, v, lo, parent, len, k(lo + parent), v(lo + parent), cmp);
            if (parent == 0L) {
                return;
            }
            parent--;
        }
    }

    private static def print_chunk[T](a:MemoryChunk[T]) {
        Console.OUT.println("chunk");
        for (i in a.range()) {
            Console.OUT.printf("%s ", a(i).toString());
        }
        Console.OUT.println("");
    }

    public static def partial_sort[T](a:MemoryChunk[T], lo:Long, hi:Long, cmp:(T,T)=>Long) {
        debugln("partial_sort called");
        var hi_:Long = hi;
        makeHeap(a, lo, hi, cmp);
    	while (hi_ - lo > 1) {
    		pop_heap[T](a, lo, hi_, cmp);
    		hi_--;
    	}
    }

    public static def partial_sort[T, U](k:MemoryChunk[T], v:MemoryChunk[U], lo:Long, hi:Long, cmp:(T,T)=>Long) {
        debugln("partial_sort called");
        var hi_:Long = hi;
        makeHeap(k, v, lo, hi, cmp);
    	while (hi_ - lo > 1) {
    		pop_heap[T, U](k, v, lo, hi_, cmp);
    		hi_--;
    	}
    }

    private static def pop_heap[T](a:MemoryChunk[T], lo:Long, hi:Long, cmp:(T,T)=>Long) {
        val value = a(hi - 1);
        a(hi - 1) = a(lo);
    	adjustHeap[T](a, lo, 0L, hi - lo - 1, value, cmp);
    }

    private static def pop_heap[T, U](k:MemoryChunk[T], v:MemoryChunk[U], lo:Long, hi:Long, cmp:(T,T)=>Long) {
        val valueK = k(hi - 1);
        val valueV = v(hi - 1);
        k(hi - 1) = k(lo);
        v(hi - 1) = v(lo);
    	adjustHeap[T, U](k, v, lo, 0L, hi - lo - 1, valueK, valueV, cmp);
    }

    private static def push_heap[T](a:MemoryChunk[T], lo:Long, hi:Long , cmp:(T,T)=>Long) {
    	push_heap[T](a, lo, hi - lo - 1, 0, a(hi - 1), cmp);
    }

    private static def push_heap[T, U](k:MemoryChunk[T], v:MemoryChunk[U], lo:Long, hi:Long , cmp:(T,T)=>Long) {
    	push_heap[T, U](k, v, lo, hi - lo - 1, 0, k(hi - 1), v(hi - 1), cmp);
    }

    private static def push_heap[T](a:MemoryChunk[T], lo:Long, holeIndex:Long, topIndex:Long, value:T, cmp:(T,T)=>Long) {
    	var parent:Long = (holeIndex - 1) / 2;
    	var _holeIndex:Long = holeIndex;
    	while (_holeIndex > topIndex && cmp(a(lo + parent), value) < 0) {
    		a(lo + _holeIndex) = a(lo + parent);
    		_holeIndex = parent;
    		parent = (_holeIndex - 1) / 2;
    	}
    	a(lo + _holeIndex) = value;
    }

    private static def push_heap[T, U](k:MemoryChunk[T], v:MemoryChunk[U], lo:Long, holeIndex:Long, topIndex:Long, valueK:T, valueV:U, cmp:(T,T)=>Long) {
    	var parent:Long = (holeIndex - 1) / 2;
    	var _holeIndex:Long = holeIndex;
    	while (_holeIndex > topIndex && cmp(k(lo + parent), valueK) < 0) {
    		k(lo + _holeIndex) = k(lo + parent);
            v(lo + _holeIndex) = v(lo + parent);
    		_holeIndex = parent;
    		parent = (_holeIndex - 1) / 2;
    	}
    	k(lo + _holeIndex) = valueK;
        v(lo + _holeIndex) = valueV;
    }

    private static def adjustHeap[T](a:MemoryChunk[T], lo:Long, holeIndex:Long ,len:Long, value:T, cmp:(T,T)=>Long) {
    	var _holeIndex:Long = holeIndex;
    	val topIndex = holeIndex;
    	var secondChild:Long = 2L * holeIndex + 2L;

    	while (secondChild < len) {
    		if (cmp(a(lo + secondChild), a(lo + secondChild - 1)) < 0) {
    			secondChild--;
    		}

    		a(lo + _holeIndex) = a(lo + secondChild);
    		_holeIndex = secondChild;
    		secondChild = 2 * (secondChild + 1);
    	}
    	if (secondChild == len) {
    		a(lo + _holeIndex) = a(lo + secondChild - 1);
    		_holeIndex = secondChild - 1;
    	}
    	push_heap[T](a, lo, _holeIndex, topIndex, value, cmp);
    }

    private static def adjustHeap[T, U](k:MemoryChunk[T], v:MemoryChunk[U], lo:Long, holeIndex:Long, len:Long, valueK:T, valueU:U, cmp:(T,T)=>Long) {
    	var _holeIndex:Long = holeIndex;
    	val topIndex = holeIndex;
    	var secondChild:Long = 2L * holeIndex + 2L;

    	while (secondChild < len) {
    		if (cmp(k(lo + secondChild), k(lo + secondChild - 1)) < 0) {
    			secondChild--;
    		}
    		k(lo + _holeIndex) = k(lo + secondChild);
            v(lo + _holeIndex) = v(lo + secondChild);
    		_holeIndex = secondChild;
    		secondChild = 2 * (secondChild + 1);
    	}
    	if (secondChild == len) {
    		k(lo + _holeIndex) = k(lo + secondChild - 1);
            v(lo + _holeIndex) = v(lo + secondChild - 1);
    		_holeIndex = secondChild - 1;
    	}
    	push_heap[T, U](k, v, lo, _holeIndex, topIndex, valueK, valueU, cmp);
    }

    private static def introSortLoop[T](a:MemoryChunk[T], lo:Long, hi:Long, cmp:(T,T)=>Long, depth_limit:Int) {
    	var depth_limit_:Int = depth_limit;
    	var hi_:Long = hi;
    	while (hi_ - lo > threashold1) {
    		if (depth_limit_ == 0) {
    			partial_sort[T](a, lo, hi_, cmp);
    			return;
            }
    		--depth_limit_;
    		val cut = unguardedPartition(a, lo, hi_, median[T](a(lo), a((lo + hi_) / 2), a(hi_ - 1), cmp), cmp);
    		introSortLoop[T](a, cut, hi_, cmp, depth_limit_);
    		hi_ = cut;
    	}
    }

    private static def introSortLoop[T, U](k:MemoryChunk[T], v:MemoryChunk[U], lo:Long, hi:Long, cmp:(T,T)=>Long, depth_limit:Int) {
    	var depth_limit_:Int = depth_limit;
    	var hi_:Long = hi;
    	while (hi_ - lo > threashold2) {
    		if (depth_limit_ == 0) {
    			partial_sort[T, U](k, v, lo, hi_, cmp);
    			return;
            }
    		--depth_limit_;
    		val cut = unguardedPartition(k, v, lo, hi_, median[T](k(lo), k((lo + hi_) / 2), k(hi_ - 1), cmp), cmp);
    		introSortLoop[T, U](k, v, cut, hi_, cmp, depth_limit_);
    		hi_ = cut;
    	}
    }

	/**
     * Searches the given indices  for the least indices that makes the given function true.using the binary search
     * algorithm.  The function must be monotonic (e.g. if an index makes the function true, all the following indices do).
     * If there exist one or more indices, return the index of the least one of them in the array.
     * Otherwise, return -1.
     * @param a the array to be searched
     * @param func the comparison function to use
      */
	public static @Inline def binarySearch(range :IntRange, func: (Int)=>Boolean) {
		val min = range.min;
		val max = range.max;
		val middle = min + (max - min) / 2;
		if (min > max)
			return -1;
		else if (func(min))
			return min;
		else if (func(middle))
			return binarySearch((min + 1)..middle, func);
		else
			return binarySearch((middle + 1)..max, func);
	}

	public static @Inline def binarySearch(range :LongRange, func: (Long)=>Boolean) {
		val min = range.min;
		val max = range.max;
		val middle = min + (max - min) / 2;
		if (min > max)
			return -1;
		else if (func(min))
			return min;
		else if (func(middle))
			return binarySearch((min + 1)..middle, func);
		else
			return binarySearch((middle + 1)..max, func);
	}

	/**
     * Searches the given indices  for the least indices that makes the given function true.
     * If there exist one or more indices, return the least index of them.
     * Otherwise, return -1.
     * @param a the array to be searched
     * @param func the comparison function to use
      */
	public static @Inline def search(range :IntRange, func: (Int)=>Boolean) =
		reduce(range, (i:Int, r:Int)=>Math.min(func(i) ? i : Int.MAX_VALUE, r), (x:Int, y:Int)=>x.compareTo(y));


	// must be optimized
	public static @Inline def appendMap[T](range :IntRange, func :(Int)=>Array[T](1)) {
		val acc = new ArrayList[T]();
		for (i in range) {
			val arr = func(i);
			if (arr.size > 0) {
				Parallel.iter(arr.region.min(0)..arr.region.max(0), (j:Int)=>{
					acc.add(arr(j));
				});
			}
		}
		return acc.toArray();
	}

	public static @Inline def partition[T](array :Array[T](1), func :(T)=>Int, kinds :Int) = partition(array, (Int, x:T)=>func(x), kinds);

	/**
     * Divides the given array into its classification.
     * Let <code>r</code> be the result of this method, For each <code>n</code>-th element <code>x</code> in the given array,
     * let <code>y</code> be a integer such that <code>y = func(n, x)</code>,
     * <code>r(y)<code> contains <code>x</code>.<p>
     *
     * The range of <code>func</code> must be in [0, <code>kinds</code>-1]
     *
     * @param array the array to be paritioned
     * @param func the function to classify
     * @param kinds the size of the classification
      */
	public static @Inline def partition[T](array :Array[T](1), func :(Int,T)=>Int, kinds :Int) : Array[Array[T](1)](1) {
		debugln("partition: " + ", size: " + array.size +  " kinds:" + kinds);
		val acc = new Array[Array[ArrayList[T]](1)](Runtime.MAX_THREADS,
				(Int)=>new Array[ArrayList[T]](kinds,
						(Int)=>new ArrayList[T]()));
		debugln("before acc");
		Parallel.iter(new IntRange(array.region.min(0), array.region.max(0)), (Int, range:IntRange)=> {
			val wid = Runtime.workerId();
			for (i in range) {
				val x = array(i);
				acc(wid)(func(i,x)).add(x);
			}
		});
		debugln("acc: " + acc);
		val resultSizes = new Array[Int](kinds, 0);
		val resultOffsets = new Array[Array[Int](1)](kinds, new Array[Int](Runtime.MAX_THREADS + 1));
		debugln("before scan");
		for (k in 0..(kinds-1)) {
			val arr = new Array[Int](Runtime.MAX_THREADS, (i:Int)=>acc(i)(k).size());
			debugln("k: " + k + " arr: " + arr);
			resultOffsets(k)(0) = 0;
			resultSizes(k) = Parallel.scan(1..(Runtime.MAX_THREADS), resultOffsets(k), 0, (i:Int, a:Int)=> acc(i - 1)(k).size() + a, (x:Int, y:Int)=>x+y);
			val truescan = new Array[Int](Runtime.MAX_THREADS + 1);
			Parallel.scan(1..(Runtime.MAX_THREADS), truescan, 0, (i:Int, a:Int)=> arr(i - 1) + a, (x:Int, y:Int)=>x+y);
			debugln("k: " + k +  "truescan: " + truescan);
			debugln("k: " + k +  "resultOffsets: " + resultOffsets(k));
			resultOffsets(k) = truescan;
		}
		debugln("after scan");
		for (k in 0..(kinds-1)) {
				debugln("k: " + k +  ", resultOffsets: " + resultOffsets(k));
		}
		val result = new Array[Array[T](1)](kinds, (i:Int)=>new Array[T](IndexedMemoryChunk.allocateUninitialized[T](resultSizes(i))));
		debugln("before copy");
		debugln("sizes" + resultSizes);
		debugln("sizes" + new Array[Int](kinds, (i:Int)=>resultOffsets(i)(Runtime.MAX_THREADS - 1)));
		finish for (k in 0..(kinds-1)) {
			Parallel.iter(0..(Runtime.MAX_THREADS-1), (wid:Int)=>{
				val size = acc(wid)(k).size();
				if (size > 0) {
					debugln("k: " + k + ", wid: " + wid);
					debugln("k: " + k + ", wid: " + wid + ", offsets: " + resultOffsets(k)(wid) + ", size: " + acc(wid)(k).size());
					Array.copy(acc(wid)(k).toArray(), 0, result(k), resultOffsets(k)(wid), acc(wid)(k).size());
				}
			});
		}
		debugln("after copy");
		return result;
	}

	public static @Inline def map[T](region :Region{self.rank==1}, func :(Int)=>T) = map(new IntRange(region.min(0), region.max(0)), func);

	public static @Inline def map[T](range :IntRange, func :(Int)=>T) {
		val size = range.max - range.min + 1;
		val store = IndexedMemoryChunk.allocateUninitialized[T](size);
		val acc = new Array[T](Region.make(range.min, range.max), store);
		iter(range, (i:Int)=> {
			acc(i) = func(i);
		});
		return acc;
	}

	public static @Inline def iter(range :IntRange, func :(Int)=>void) {
		val size = range.max - range.min + 1;
		if(size == 0) return ;
		val nthreads = Math.min(Runtime.NTHREADS, size);
		val chunk_size = Math.max((size + nthreads - 1) / nthreads, 1);
		finish for(i in 0..(nthreads-1)) {
			val i_start = range.min + i*chunk_size;
			val i_range = i_start..Math.min(range.max, i_start+chunk_size-1);
			async for(ii in i_range) func(ii);
		}
	}

	public static @Inline def iter(range :LongRange, func :(Long)=>void) {
		val size = range.max - range.min + 1;
		if(size == 0L) return ;
		val nthreads = Math.min(Runtime.NTHREADS as Long, size);
		val chunk_size = Math.max((size + nthreads - 1) / nthreads, 1L);
		finish for(i in 0..(nthreads-1)) {
			val i_start = range.min + i*chunk_size;
			val i_range = i_start..Math.min(range.max, i_start+chunk_size-1);
			async for(ii in i_range) func(ii);
		}
	}

	public static @Inline def iter(range :IntRange, func :(Int, IntRange)=>void) {
		val size = range.max - range.min + 1;
		if(size == 0) return ;
		val nthreads = Math.min(Runtime.NTHREADS, size);
		val chunk_size = Math.max((size + nthreads - 1) / nthreads, 1);
		finish for(i in 0..(nthreads-1)) {
			val idx = i;
			val i_start = range.min + i*chunk_size;
			val i_range = i_start..Math.min(range.max, i_start+chunk_size-1);
			async func(idx, i_range);
		}
	}

	public static @Inline def iter(range :LongRange, func :(Long, LongRange)=>void) {
		val size = range.max - range.min + 1;
		if(size == 0L) return ;
		val nthreads = Math.min(Runtime.NTHREADS as Long, size);
		val chunk_size = Math.max((size + nthreads - 1) / nthreads, 1L);
		finish for(i in 0..(nthreads-1)) {
			val idx = i;
			val i_start = range.min + i*chunk_size;
			val i_range = i_start..Math.min(range.max, i_start+chunk_size-1);
			async func(idx, i_range);
		}
	}

	public static @Inline def reduce[U](range :IntRange, func :(Int,U)=>U, op :(U,U)=>U) {U haszero} :U {
		val size = range.max - range.min + 1;
		val nthreads = Math.min(Runtime.NTHREADS, size);
		val chunk_size = Math.max((size + nthreads - 1) / nthreads, 1);
		val intermid = new Array[U](nthreads);
		finish for(i in 0..(nthreads-1)) {
			val idx = i;
			val i_start = range.min + i*chunk_size;
			val i_range = i_start..Math.min(range.max, i_start+chunk_size-1);
			async {
				var r :U = Zero.get[U]();
				for(ii in i_range) r = func(ii, r);
				intermid(idx) = r;
			}
		}
		var r :U = Zero.get[U]();
		for(i in 0..(nthreads-1)) r = op(r,intermid(i));
		return r;
	}

	public static @Inline def reduce[U](range :LongRange, func :(Long,U)=>U, op :(U,U)=>U) {U haszero} :U {
		val size = range.max - range.min + 1;
		val nthreads = Math.min(Runtime.NTHREADS as Long, size);
		val chunk_size = Math.max((size + nthreads - 1) / nthreads, 1L);
		val intermid = new MemoryChunk[U](nthreads);
		finish for(i in 0..(nthreads-1)) {
			val idx = i;
			val i_start = range.min + i*chunk_size;
			val i_range = i_start..Math.min(range.max, i_start+chunk_size-1);
			async {
				var r :U = Zero.get[U]();
				for(ii in i_range) r = func(ii, r);
				intermid(idx) = r;
			}
		}
		var r :U = Zero.get[U]();
		for(i in 0..(nthreads-1)) r = op(r,intermid(i));
		return r;
	}

	public static @Inline def scan[U](range :IntRange, dst :Array[U](1), init :U, func :(Int,U)=>U, op :(U,U)=>U) {U haszero} :U {
		val size = range.max - range.min + 1;
		val nthreads = Math.min(Runtime.NTHREADS, size);
		val chunk_size = Math.max((size + nthreads - 1) / nthreads, 1);
		dst(range.min - 1) = init;
		if(nthreads >= 2){
			finish {
				for(i in 0..(nthreads-1)) {
					val i_start = range.min + i*chunk_size;
					val i_end = i_start + chunk_size - 1;
					if(i_end <= range.max) {
						async {
							var r :U = Zero.get[U]();
							for(ii in i_start..i_end) r = func(ii, r);
							dst(i_end) = r;
						}
					}
				}
			}
			for(i in 0..(nthreads-1)) {
				val i_prev = range.min + i*chunk_size - 1;
				val i_cur = i_prev + chunk_size;
				if(i_cur <= range.max) {
					dst(i_cur) = op(dst(i_cur), dst(i_prev));
				}
			}
			finish {
				for(i in 0..(nthreads-1)) {
					val i_start = range.min + i*chunk_size;
					val i_end = Math.min(range.max + 1, i_start+chunk_size-1);
					async {
						for(ii in i_start..(i_end-1)) dst(ii) = func(ii, dst(ii-1));
					}
				}
			}
		}
		else {
			for(i in range) dst(i) = func(i, dst(i-1));
		}
		return dst(range.max);
	}

	public static @Inline def scan[U](range :LongRange, dst :MemoryChunk[U], init :U, func :(Long,U)=>U, op :(U,U)=>U) {U haszero} :U {
		val size = range.max - range.min + 1;
		val nthreads = Math.min(Runtime.NTHREADS as Long, size);
		val chunk_size = Math.max((size + nthreads - 1) / nthreads, 1L);
		dst(range.min - 1) = init;
		if(nthreads >= 2){
			finish {
				for(i in 0..(nthreads-1)) {
					val i_start = range.min + i*chunk_size;
					val i_end = i_start + chunk_size - 1;
					if(i_end <= range.max) {
						async {
							var r :U = Zero.get[U]();
							for(ii in i_start..i_end) r = func(ii, r);
							dst(i_end) = r;
						}
					}
				}
			}
			for(i in 0..(nthreads-1)) {
				val i_prev = range.min + i*chunk_size - 1;
				val i_cur = i_prev + chunk_size;
				if(i_cur <= range.max) {
					dst(i_cur) = op(dst(i_cur), dst(i_prev));
				}
			}
			finish {
				for(i in 0..(nthreads-1)) {
					val i_start = range.min + i*chunk_size;
					val i_end = Math.min(range.max + 1, i_start+chunk_size-1);
					async {
						for(ii in i_start..(i_end-1)) dst(ii) = func(ii, dst(ii-1));
					}
				}
			}
		}
		else {
			for(i in range) dst(i) = func(i, dst(i-1));
		}
		return dst(range.max);
	}

	public static @Inline def prefixSum[U](range :IntRange, arr :Array[U](1)) {U haszero, U <: Arithmetic[U]}
		= scan(range, arr, Zero.get[U](), (i :Int, v :U) => v + arr(i), (v1 :U, v2 :U) => v1 + v2);

}