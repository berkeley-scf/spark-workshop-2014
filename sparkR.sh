# on EC2

cd /root
wget http://cran.cnr.berkeley.edu/src/contrib/rJava_0.9-6.tar.gz
/root/spark-ec2/copy-dir rJava_0.9-6.tar.gz
R CMD javareconf
tar xvzf rJava_0.9-6.tar.gz && R CMD INSTALL rJava
/root/spark/sbin/slaves.sh R CMD javareconf
/root/spark/sbin/slaves.sh R CMD INSTALL ~/rJava_0.9-6.tar.gz

cd /root
git clone https://github.com/amplab-extras/SparkR-pkg.git
cd SparkR-pkg
./install-dev.sh
/root/spark-ec2/copy-dir /root/SparkR-pkg

# always start sparkR like this:
cd /root/SparkR-pkg
MASTER=`cat /root/spark-ec2/cluster-url` ./sparkR

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