import sys
import numpy.random as rand
from operator import add
from pyspark import SparkContext
if __name__ == "__main__":
    if len(sys.argv) != 3:
        print >> sys.stderr, "Usage: spark-submit piCalc.py <total_samples> <slices>"
        exit(-1)
    sc = SparkContext() 
    total_samples = int(sys.argv[1]) if len(sys.argv) > 1 else 1000000
    num_slices = int(sys.argv[2]) if len(sys.argv) > 2 else 2
    samples_per_slice = round(total_samples / num_slices)

    def sample(p):
        rand.seed(p)
        x, y = rand.random(samples_per_slice), rand.random(samples_per_slice)
        return sum(x*x + y*y < 1)

    count = sc.parallelize(xrange(0, num_slices), num_slices).map(sample).reduce(add)
    print "Pi is roughly %f" % (4.0 * count / (num_slices*samples_per_slice))

