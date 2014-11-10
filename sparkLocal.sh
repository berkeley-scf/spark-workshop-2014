# brief demo code for running Spark locally on your own machine 

# download hadoop1.x pre-built or another of the pre-built Spark packages
# unzip the tarball and navigate into the Spark directory

# the following works in multi-core fashion (4 cores in this case) to do non-HDFS stuff 
MASTER=local[4] ./bin/spark-submit /path/to/piCalc.py 100000000 10

# but to use Spark with HDFS, you need Hadoop installed separately with HDFS set up on your machine, so non-trivial