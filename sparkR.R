# if not on EC2 and using on single node:
# master <- system("cat /root/spark-ec2/cluster-url", intern = TRUE)
# sc <- sparkR.init(master = 'local')
# sc <- sparkR.init(master = 'local[2]')
# sc <- sparkR.init(master = master)

# library(SparkR)

# remember SparkR needs to have been started specifying MASTER to point to the Spark URI

library(help = SparkR) # this will show the SparkR functions available and then you can get the R help info for individual functions as usual in R


##############################
# reading airline data in
##############################

master <- system("cat /root/ephemeral-hdfs/conf/masters", intern = TRUE)
lines <- textFile(sc, paste0("hdfs://", master, ":9000/data/airline"))

count(lines)

take(lines, 1)
# that gives Java error:
#14/11/13 02:32:01 WARN TaskSetManager: Lost task 0.2 in stage 5.0 (TID 52, ip-10-225-185-25.us-west-2.compute.internal): java.lang.OutOfMemoryError: Java heap space
# ....
#14/11/13 02:32:02 ERROR TaskSchedulerImpl: Lost executor 7 on ip-10-225-185-25.us-west-2.compute.internal: remote Akka client disassociated


# no partition() in SparkR yet; here's a workaround

createKeyValue <- function(line) {
  vals <- strsplit(line, ",")[[1]]
  return(vals[1], line)
}

createKeyValue <- function(line) {
  vals <- strsplit(line, ",")[[1]]
  return(paste(vals[c(1,2,3,9,10)], collapse='-'), line)
}

linesWithKey <- map(lines, createKeyValue)
count(linesWithKey)
# fails with 
#14/11/13 03:31:16 WARN TaskSetManager: Lost task 0.0 in stage 0.0 (TID 1, ip-10-249-57-210.us-west-2.compute.internal): java.lang.NullPointerException: 
#        edu.berkeley.cs.amplab.sparkr.RRDD.compute(RRDD.scala:128)
#        org.apache.spark.rdd.RDD.computeOrReadCheckpoint(RDD.scala:262)
#        org.apache.spark.rdd.RDD.iterator(RDD.scala:229)
#        org.apache.spark.scheduler.ResultTask.runTask(ResultTask.scala:62)
#        org.apache.spark.scheduler.Task.run(Task.scala:54)
#        org.apache.spark.executor.Executor$TaskRunner.run(Executor.scala:177)
#        java.util.concurrent.ThreadPoolExecutor.runWorker(ThreadPoolExecutor.java:1145)
#        java.util.concurrent.ThreadPoolExecutor$Worker.run(ThreadPoolExecutor.java:615)
#        java.lang.Thread.run(Thread.java:745)

# linesPartitioned <- partitionBy(linesWithKey, numPartitions = 192)

#myRdd <- map(myTextFileRdd, function(x) { list(x, x) })
#partitioned <- partitionBy(myRdd, numPartitions = 10L)



##############################
# calculation of Pi example
##############################


num_slices <- 100
rdd <- parallelize(sc, 1:num_slices, num_slices)

sample <- function(p) {
  set.seed(p)
  sps <- value(samples_per_sliceBr)
  x <- runif(sps); y <- runif(sps)
  return(sum(x^2 + y^2 < 1))
}

samples_per_slice <- 100000
samples_per_sliceBr <- broadcast(sc, samples_per_slice)

count <-  reduce(lapply(rdd, sample), '+')
print(paste0("Pi is roughly ", (4.0 * count / (num_slices*samples_per_slice))))

