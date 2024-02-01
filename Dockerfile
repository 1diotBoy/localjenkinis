FROM jenkins/jenkins:2.426.1-jdk17
ENV JENKINS_USER jenkinsadmin
ENV JENKINS_PASS Powerjenkins@2024

USER root

COPY plugins.txt /usr/share
COPY default-user.groovy  /usr/share/jenkins/ref/init.groovy.d/default-user.groovy

RUN apt-get update && apt-get install -y lsb-release
RUN curl -fsSLo /usr/share/keyrings/docker-archive-keyring.asc \
  https://download.docker.com/linux/debian/gpg
RUN echo "deb [arch=$(dpkg --print-architecture) \
  signed-by=/usr/share/keyrings/docker-archive-keyring.asc] \
  https://download.docker.com/linux/debian \
  $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list
RUN apt-get update && apt-get install -y zip unzip && apt-get clean

USER jenkins
RUN jenkins-plugin-cli -f /usr/share/plugins.txt
