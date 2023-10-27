# Dockerfile layer 2 for NEI2ISRM
# this appends to layer 1 (base) for quick code update
# maintained by Yuhan Wang (yuhan_wang@berkeley.edu)
# credit to Tin Ho (tin@lbl.gov) for his dockerfile template and instructions


FROM ghcr.io/yhanw0719/docker-base:v1.0.0

MAINTAINER Yuhan Wang
ARG DEBIAN_FRONTEND=noninteractive
ARG TERM=dumb
ARG TZ=PST8PDT
ARG NO_COLOR=1


RUN echo  ''  ;\
    touch _TOP_DIR_OF_CONTAINER_  ;\
    echo "layer 2 code addition " | tee -a _TOP_DIR_OF_CONTAINER_  ;\
    export TERM=dumb      ;\
    export NO_COLOR=TRUE  ;\
    cd /    ;\
    echo ""


#### project-specific customization
RUN echo ''  ;\
    echo '==================================================================' ;\
    echo '' ;\
    export TERM=dumb  ;\
    cd /     ;\
    mkdir -p /opt/gitrepo/NEI2ISRM ;\
    pwd      ;\
    Rscript --quiet --no-readline --slave -e 'install.packages("optparse",     repos = "http://cran.us.r-project.org")'    ;\
    echo ""

# add some marker of how Docker was build.
COPY . /opt/gitrepo/NEI2ISRM

RUN  cd / \
  && touch _TOP_DIR_OF_CONTAINER_  \
  && echo  "--------" >> _TOP_DIR_OF_CONTAINER_   \
  && TZ=PST8PDT date  >> _TOP_DIR_OF_CONTAINER_  


ENV TZ America/Los_Angeles

# below is from bash -x /usr/bin/R
ENV LD_LIBRARY_PATH=/usr/lib/R/lib:/usr/lib/x86_64-linux-gnu:/usr/lib/jvm/default-java/lib/server
ENV R_LD_LIBRARY_PATH=/usr/lib/R/lib:/usr/lib/x86_64-linux-gnu:/usr/lib/jvm/default-java/lib/server
ENV R_binary=/usr/lib/R/bin/exec/
ENV R_LIBS=/usr/local/lib/R/site-library:/usr/lib/R/site-library:/usr/lib/R/library


#ENTRYPOINT [ "/bin/bash" ]
#ENTRYPOINT [ "/usr/bin/R" ]
ENTRYPOINT [ "Rscript", "/opt/gitrepo/NEI2ISRM/main.R" ]
