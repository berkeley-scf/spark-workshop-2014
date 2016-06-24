# on EC2

# new as of 12/19/14
echo '#!/bin/bash' > /usr/bin/realpath
echo 'readlink -e $1' >> /usr/bin/realpath
chmod guo+x /usr/bin/realpath

# no longer needed according to Shivaram
#cd /root
#wget http://cran.cnr.berkeley.edu/src/contrib/rJava_0.9-6.tar.gz
#/root/spark-ec2/copy-dir rJava_0.9-6.tar.gz
#R CMD javareconf
#tar xvzf rJava_0.9-6.tar.gz; R CMD INSTALL rJava
#/root/spark-ec2/copy-dir /usr/bin/realpath
#/root/spark/sbin/slaves.sh R CMD javareconf
#/root/spark/sbin/slaves.sh R CMD INSTALL ~/rJava_0.9-6.tar.gz

cd /root
git clone https://github.com/amplab-extras/SparkR-pkg.git
cd SparkR-pkg
SPARK_VERSION=${SPARK_VERSION} ./install-dev.sh
/root/spark-ec2/copy-dir /root/SparkR-pkg

echo "1" > /tmp/file.csv
echo "1" >> /tmp/file.csv
echo "1" >> /tmp/file.csv
echo "1" >> /tmp/file.csv
echo "1" >> /tmp/file.csv
export PATH=$PATH:/root/ephemeral-hdfs/bin/
hadoop fs -mkdir /data/test
hadoop fs -copyFromLocal /tmp/file.csv /data/test

mkdir /mnt/airline
cd /mnt/airline
wget http://www.stat.berkeley.edu/share/paciorek/1987-2008.csvs.tgz
tar -xvzf 1987-2008.csvs.tgz
export PATH=$PATH:/root/ephemeral-hdfs/bin/
hadoop fs -mkdir /data/airline
hadoop fs -copyFromLocal /mnt/airline/*bz2 /data/airline
hadoop fs -ls /data/airline


# always start sparkR like this:
cd /root/SparkR-pkg
MASTER=`cat /root/spark-ec2/cluster-url` SPARK_MEM=6g ./sparkR
cd /root/spark/bin
MASTER=`cat /root/spark-ec2/cluster-url` SPARK_MEM=6g ./sparkR
# setting MASTER allows SparkR to run on the cluster
# setting SPARK_MEM allows slaves to use more of the physical memory

# check spark UI to make sure there are multiple executors (one for each slave plus master); if not, try starting and stopping pyspark

# to change number of executors per node:
#You can change this by setting `SPARK_WORKER_CORES` in /root/spark/conf/spark-env.sh but this will need to be copied to all the machines and a Spark restart (i.e. /root/spark-ec2/copy-dir /root/spark/conf; /root/spark/sbin/stop-all.sh; /root/spark/sbin/start-all.sh)

###########################################################################
# IGNORE ANYTHING BELOW HERE
###########################################################################
# this would work on a single node but doesn't install SparkR on the slaves
yum install R
yum install -y curl curl-devel  # needed by devtools
ln -s /usr/bin/readlink /usr/bin/realpath  # needed by R CMD javareconf
export JAVA_HOME=/usr/lib/jvm/java-1.7.0
R CMD javareconf # needed for rJava to install
Rscript -e "install.packages(c('rJava', 'devtools'), repos = 'http://cran.cnr.berkeley.edu')"
Rscript -e "library(devtools); install_github('amplab-extras/SparkR-pkg', subdir='pkg')"

# or see instructions here: https://github.com/amplab-extras/SparkR-pkg/wiki/SparkR-on-EC2

# link to fast BLAS?

# start R
R
