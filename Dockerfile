FROM docker.io/jenkins/jenkins:2.426.1-jdk17
ENV JENKINS_USER admin
ENV JENKINS_PASS Powerjenkins@2024

USER root
COPY plugins.txt /usr/share
COPY default-user.groovy  /usr/share/jenkins/ref/init.groovy.d/default-user.groovy
COPY plugins.tar.gz /usr/share
RUN ls -l /usr/share
RUN tar zvfx /usr/share/plugins.tar.gz -C /var/jenkins_home
RUN rm -f /usr/share/plugins.tar.gz

COPY  updates /var/jenkins_home

USER jenkins
