if(!exists('sc')) { # not started via sparkR script
# if not on EC2 and using on single node, start R without the SparkR script and do
# library(SparkR, lib.loc = '/path/to/R/library/containing/sparkR')
# sc <- sparkR.init(master = 'local')
# sc <- sparkR.init(master = 'local[2]')  # to use 2 cores
# if on EC2 and want to start R without the SparkR script:
  library(SparkR, lib.loc = '/root/SparkR-pkg/lib')
  master <- system("cat /root/spark-ec2/cluster-url", intern = TRUE)
  sc <- sparkR.init(master = master, sparkEnvir=list(spark.executor.memory="6g"))
} # if using sparkR script to start,  remember SparkR needs to have been started specifying MASTER to point to the Spark URI

library(help = SparkR) # this will show the SparkR functions available and then you can get the R help info for individual functions as usual in R

num_cores <- 24

# 1. The cache on textFile works a little differently in SparkR vs. PySpark. In SparkR we cache JavaRDD encoded as strings, while Python encodes it in Python. The reason this is important is that Strings in Java take 2 bytes per character vs 1 byte in most other languages. So one workaround in your case is to cache an R encoded RDD by explicitly calling `lapply`. i.e. You can do "lines <- cache(lapply(textFile(sc, <filepath>), identity))" -- This halves the cached dataset size from what I observed (i.e. each partition is down from 1G to 500 MB)

# 2. I also found that in this case calling `strsplit` is slow and you probably don't want to do that every time. So another optimization could be to do `strsplit` before cache.

##############################
# reading airline data in
##############################

hdfs_master <- system("cat /root/ephemeral-hdfs/conf/masters", intern = TRUE)
lines <- textFile(sc, paste0("hdfs://", hdfs_master, ":9000/data/airline"))
count(lines)

hdfs_master <- system("cat /root/ephemeral-hdfs/conf/masters", intern = TRUE)
lines <- cache(lapply(textFile(sc, paste0("hdfs://", hdfs_master, ":9000/data/airline")), identity))
# fails with R computation failed with
# Error in unserialize(readBin(con, raw(), as.integer(dataLen), endian = "big")) : 
#  embedded nul in string: '1987,10,8,4\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\

hdfs_master <- system("cat /root/ephemeral-hdfs/conf/masters", intern = TRUE)
lines <- cache(textFile(sc, paste0("hdfs://", hdfs_master, ":9000/data/airline")))
# Warning message:
# In normalizePath(path) : path[1]="hdfs://ec2-54-186-104-157.us-west-2.compute.amazonaws.com:9000/data/airline": No such file or directory
count(lines)
# time in R: 194 sec.   ; time in Python: 92 sec.  (123534991)
# time in R if do cache(textFile(sc ,....)) and then count lines: 224 sec.

take(lines, 1)  # time in R: 14 sec. (uncached), 7 sec. (cached) ; time in Python: .16 sec


#Warning message:
#In normalizePath(path) :
#  path[1]="s3n://<AWS_ACCESS_KEY_ID>:<AWS_SECRET_ACCESS_KEY>@datasets.elasticmapreduce/ngrams/books/20090715/eng-us-all/1gram": No such file or directory
 lines = textFile(sc, "s3n://<AWS_ACCESS_KEY_ID>:<AWS_SECRET_ACCESS_KEY>@datasets.elasticmapreduce/ngrams/books/20090715/eng-us-all/1gram")
count(lines) # slow, but works, despite the warning

# no repartition() in SparkR yet; here's a workaround

linesPartitioned <- cache(partitionBy(lines, numPartitions = as.integer(num_cores*8)))
numPartitions(linesPartitioned)
sub1 <- collectPartition(linesPartitioned, 0L)
sub2 <- collectPartition(linesPartitioned, 1L)

# in R: 1238 sec. (January)
# in python: repartition to 192 takes 220 sec.

# weird that ?partitionBy doesn't have form (K,V) in example
# same thing with ?reduceByKey

linesPartitioned <- cache(partitionBy(lines, numPartitions = as.integer(num_cores*8)))  # now takes 1007  sec.
take(linesPartitioned, 1)  # 4.2 sec
# fails with same erorr as using identity() with cache() when first read data in
linesPartitioned <- cache(lapply(partitionBy(lines, numPartitions = as.integer(num_cores*8)), identity))
# same error
linesPartitioned <- partitionBy(lapply(lines, identity), numPartitions = as.integer(num_cores*8))

# filtering
sfo_lines = filterRDD(lines, function(line) strsplit(line, ",")[[1]][17] == "SFO")
system.time(out <- count(sfo_lines))
sfo_lines = cache(filterRDD(linesPartitioned, function(line) strsplit(line, ",")[[1]][17] == "SFO"))
count(sfo_lines)

# 701 sec. in R with lines (not cached)
#  sec. in R with lines (cached)
# 439 sec. in R with linesPartitioned
# 64 sec. in python
# 2733910 is result

R_sfo_lines = collect(sfo_lines)
length(R_sfo_lines)
R_sfo_lines[[1]]

# 37 sec.
# 11 sec. in python

# no saveAsTextFile yet
# saveAsTextFile(sfo_lines, '/data/airline-sfo')

# stratifying

createKeyValue <- function(line) {
    vals = strsplit(line, ",")[[1]]
    return(list(paste(vals[17], vals[18], sep = '+'), 1))
  }

# this works fine after filtering lines to 'CAK' only
routeCount <- collect(reduceByKey(map(lines, createKeyValue), "+", 1L))
routeCount <- collect(reduceByKey(map(linesPartitioned, createKeyValue), "+", 1L))

# 922 sec.
# takes 82 sec in python on full dataset

routeCount2 <- countByKey(map(lines, createKeyValue))

# takes 910 sec. in R
# takes 72 sec in python

# some issues with tasks dying: (still happening April 2015)
> system.time(routeCount2 <- countByKey(map(lines, createKeyValue)))
15/01/07 03:22:29 WARN TaskSetManager: Lost task 17.0 in stage 9.0 (TID 806, ip-172-31-9-96.us-west-2.compute.internal): java.lang.NullPointerException: 
        edu.berkeley.cs.amplab.sparkr.BaseRRDD.compute(RRDD.scala:41)
        org.apache.spark.rdd.RDD.computeOrReadCheckpoint(RDD.scala:262)
        org.apache.spark.rdd.RDD.iterator(RDD.scala:229)
        edu.berkeley.cs.amplab.sparkr.BaseRRDD.compute(RRDD.scala:30)
        org.apache.spark.rdd.RDD.computeOrReadCheckpoint(RDD.scala:262)
        org.apache.spark.rdd.RDD.iterator(RDD.scala:229)
        org.apache.spark.scheduler.ShuffleMapTask.runTask(ShuffleMapTask.scala:68)
        org.apache.spark.scheduler.ShuffleMapTask.runTask(ShuffleMapTask.scala:41)
        org.apache.spark.scheduler.Task.run(Task.scala:54)
        org.apache.spark.executor.Executor$TaskRunner.run(Executor.scala:177)
        java.util.concurrent.ThreadPoolExecutor.runWorker(ThreadPoolExecutor.java:1145)
        java.util.concurrent.ThreadPoolExecutor$Worker.run(ThreadPoolExecutor.java:615)
        java.lang.Thread.run(Thread.java:744)
15/01/07 03:22:51 WARN TaskSetManager: Lost task 18.0 in stage 9.0 (TID 808, ip-172-31-9-91.us-west-2.compute.internal): java.lang.NullPointerException: 
        edu.berkeley.cs.amplab.sparkr.BaseRRDD.compute(RRDD.scala:41)
        org.apache.spark.rdd.RDD.computeOrReadCheckpoint(RDD.scala:262)
        org.apache.spark.rdd.RDD.iterator(RDD.scala:229)
        edu.berkeley.cs.amplab.sparkr.BaseRRDD.compute(RRDD.scala:30)
        org.apache.spark.rdd.RDD.computeOrReadCheckpoint(RDD.scala:262)
        org.apache.spark.rdd.RDD.iterator(RDD.scala:229)
        org.apache.spark.scheduler.ShuffleMapTask.runTask(ShuffleMapTask.scala:68)
        org.apache.spark.scheduler.ShuffleMapTask.runTask(ShuffleMapTask.scala:41)
        org.apache.spark.scheduler.Task.run(Task.scala:54)


##############################
# calculation of Pi example
##############################

samples_per_slice <- 1000000
num_cores = 24
num_slices = num_cores * 20
rdd <- parallelize(sc, 1:num_slices, num_slices)

sample <- function(p) {
  set.seed(p)
  x <- runif(samples_per_slice); y <- runif(samples_per_slice)
  return(sum(x^2 + y^2 < 1))
}


system.time(count <-  reduce(lapply(rdd, sample), '+'))
# 56 sec, 3.1417 w/ 24 cores; 3.141608 with 6...
# in python, 88 sec,  3.141639
print(paste0("Pi is roughly ", (4.0 * count / (num_slices*samples_per_slice))))

