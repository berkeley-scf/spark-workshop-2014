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

# no partition() in SparkR yet; here's a workaround

createKey <- function(line) {
  vals <- strsplit(line, ",")
  return(paste(vals[1],vals[3], collapse='-'), line)
}

linesWithKey <- map(lines, createKey)
linesPartitioned <- partitionBy(linesWithKey, numPartitions = 192)

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

