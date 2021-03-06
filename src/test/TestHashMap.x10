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

package test;

import x10.compiler.Inline;
//import x10.util.IndexedMemoryChunk;
import x10.util.ArrayList;
import x10.util.Timer;
import x10.util.Random;

import org.scalegraph.test.STest;
import org.scalegraph.util.MathAppend;
import org.scalegraph.util.MemoryChunk;
import org.scalegraph.util.StopWatch;
import org.scalegraph.util.Parallel;
import org.scalegraph.util.HashMap;

final class TestHashMap extends STest {
	public static def main(args: Rail[String]) {
		new TestHashMap().execute(args);
	}
	
    var n : Int;
    var ne : Int;

    static nTest = 1;

    val test = false;

    def benchParPut() {
        Console.OUT.printf("%d, %d\n", n, ne);
        Console.OUT.println("test1 start");
        var sum : Double = 0.;
        val t = new HashMap[Int, Int](n);
        val ks = MemoryChunk.make[Int](ne);
        val vs = MemoryChunk.make[Int](ne);
        for (i in (0..(ne - 1))) {
            ks(i as Long) = i as Int;
            vs(i as Long) = i as Int;
        }
        for (1..nTest) {
            System.gc();
            val startTime = Timer.nanoTime();
            t.put(ks, vs);
            val time = (Timer.nanoTime() - startTime) / (1000. * 1000. * 1000.);
            Console.OUT.printf("time1 = %f\n", time);
            sum += time;
            t.clear();
        }
        Console.OUT.printf("ave time1 = %.16f\n", sum / nTest);
        return;
    }

    def benchSeqPut() {
        Console.OUT.println("test2 start");

        var sum : Double = 0.;
        val t = new HashMap[Int, Int](n);
        for (1..nTest) {
            System.gc();

            val startTime = Timer.nanoTime();
            for (i in (0..(ne - 1))) {
                t.put(i as Int, i as Int);
            }
            val time = (Timer.nanoTime() - startTime) / (1000. * 1000. * 1000.);
            //Console.OUT.printf("time2 = %f\n", time);
            sum += time;
            t.clear();
        }
        Console.OUT.printf("ave time2 = %.16f\n", sum / nTest);
        return;
    }

    def benchGet() {
        val t = new HashMap[Int, Int](n);
        val ks = MemoryChunk.make[Int](ne);
        val vs = MemoryChunk.make[Int](ne);

        for (i in ks.range()) {
            ks(i) = i as Int;
            vs(i) = ks(i);
        }
        t.put(ks, vs);

        val getVs = (()=>{
            val start = Timer.nanoTime();
            val getVs = t.get(ks, -1n);
            Console.OUT.printf("parallel get time = %g\n", (Timer.nanoTime() - start) / (1000. * 1000. * 1000.));
            return getVs;
        })();

        {
            val start = Timer.nanoTime();
            for (i in ks.range()) {
                t.get(ks(i), -1n);
            }
            Console.OUT.printf("sequencial get time = %g\n", (Timer.nanoTime() - start) / (1000. * 1000. * 1000.));
        }

        if (test) {
            for (i in getVs.range()) {
                assert(getVs(i) == vs(i));
            }
        }
    }

    def runNewKeys() {
        val t = new HashMap[Int, Int](100n);
        val ks = MemoryChunk.make[Int](10);
        val vs = MemoryChunk.make[Int](10);

        for (i in ks.range()) {
            ks(i) = i as Int;
            vs(i) = ks(i);
        }
        t.put(ks, vs);

        val keys = MemoryChunk.make[Int](10);
        keys(0) = 10n;
        keys(1) = 10n;
        keys(2) = 10n;
        keys(3) = 3n;
        keys(4) = 4n;
        keys(5) = 5n;
        keys(6) = 16n;
        keys(7) = 17n;
        keys(8) = 18n;
        keys(9) = 19n;

        val newKeys = (()=>{
            val newKeys = t.newKeys(keys, -1n);
            return newKeys;
        })();
        for (i in newKeys.range()) {
            Console.OUT.printf("newKeys(%d) = %d\n", i as Int, newKeys(i));
        }
        assert(newKeys.size() == 5L);
        return;
    }

    def benchNewKeys() {
        val t = new HashMap[Int, Int](n);
        val ks = MemoryChunk.make[Int](ne);
        val vs = MemoryChunk.make[Int](ne);

        for (i in ks.range()) {
            ks(i) = i as Int;
            vs(i) = ks(i);
        }
        // put (i -> i) (0<= i < ne)
        t.put(ks, vs);

        // i (ne / 2 <= i < ne + ne / 2)
        for (i in ks.range()) {
            ks(i) = i as Int + ne / 2n;
        }

        val newKeys = t.newKeys(ks, -1n);
        assert(newKeys.size() ==  ne / 2 as Long);
        Parallel.sort(newKeys);
        // newKeys = ne, ne + 1, ..., ne - 1 + ne / 2
        // check newKeys(0) = ne, ,newKeys(i + 1) = newKeys(i) + 1 (i > 0)
        assert(newKeys(0) == ne);
        for (i in newKeys.range()) {
            if (i > 0L) {
                assert (newKeys(i) == newKeys(i - 1n) + 1n);
            }
        }
    }

    def run3() {
        Console.OUT.println("test3 start");
        val t = new HashMap[Int, Int](100n);
        val n1 = 50;
        val n2 = 50;

        val ks1 = MemoryChunk.make[Int](n1);
        val vs1 = MemoryChunk.make[Int](n1);

        val ks2 = MemoryChunk.make[Int](n2);
        val vs2 = MemoryChunk.make[Int](n2);

        for (i in (0..(n1 - 1))) {
            ks1(i as Long) = i as Int;
            vs1(i as Long) = i as Int;
        }
        t.put(ks1, vs1);

        for (i in (0..(n2 - 1))) {
            ks2(i as Long) = (i + n1) as Int;
            vs2(i as Long) = (i + n1) as Int;
        }
        t.put(ks2, vs2);

        for (i in (0..(n1 + n2 - 1))) {
            val key = i as Int;
            assert(t.get(key) != null && t.get(key).value == key);
        }
        Console.OUT.println("test3 end");
    }

    def run4() {
        val t = new HashMap[Int, Int](10n);
        val n1 = 5;
        val ks1 = MemoryChunk.make[Int](n1);
        val vs1 = MemoryChunk.make[Int](n1);

        for (i in (0..(n1 - 1))) {
            ks1(i as Long) = i as Int;
            vs1(i as Long) = i as Int;
        }
        t.put(ks1, vs1);
        Console.OUT.println("start rehash");
        t.rehash();
    }

    def run5() {
        val n = 100000;
        val e = 40000;
        val t = new HashMap[Long, Long](n as Int);
        val ks = MemoryChunk.make[Long](e);
        val vs  = MemoryChunk.make[Long](e);
        val r = new Random(1L);
        val sw = new StopWatch();
        for (i in 0..(e - 1)) {
            val l = r.nextLong();
            ks(i) = l;
            vs(i) = l;
        }
 //       sw.start();
        t.put(ks, vs);
//        sw.stop();
 //       sw.print("run5");

        for (i in 0..(e - 1)) {
            ks(i) = r.nextLong();
            vs(i) = ks(i);
        }

        t.put(ks, vs);

        for (i in (0..(e - 1))) {
            val key = ks(i);
            val value = t.get(key);
            assert(value != null && value.value == vs(i));
        }
    }

    public def run(args: Rail[String]): Boolean {
    	n = (args.size > 0) ? Int.parse(args(0)) : -1n;
    	ne = (args.size > 0) ? Int.parse(args(1)) : -1n;
        
        benchSeqPut();
        benchParPut();
        benchGet();

        run3();
        run4();
        run5();
        runNewKeys();
        benchNewKeys();
        
        return true;
    }
}
