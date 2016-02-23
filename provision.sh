#!/usr/bin/env bash
#
# neeasade
# provision a streama instance.

# depends
yum -y install java-1.8.0-openjdk-devel wget mariadb mariadb-server expect git

echo "export JAVA_HOME=/usr/lib/jvm/java-1.8.0-openjdk" >> ~/.bashrc
. ~/.bashrc

# latest tomcat7
cd /tmp
wget http://www.webhostingjams.com/mirror/apache/tomcat/tomcat-7/v7.0.63/bin/apache-tomcat-7.0.63.tar.gz -O tomcat7.tar.gz
mkdir /opt/tomcat
tar -xzvf tomcat7.tar.gz -C /opt/tomcat --strip-components=1 && rm -rf tomcat7.tar.gz

# tomcat user
useradd -r -s /sbin/nologin tomcat
chown -R tomcat:root /opt/tomcat

# open up port 8080
firewall-cmd --zone=public --add-port=8080/tcp --permanent
firewall-cmd --reload

# systemd service for deploy on boot:
cat >/etc/systemd/system/tomcat.service <<EOL
# Systemd unit file for tomcat
[Unit]
Description=Apache Tomcat Web Application Container
After=syslog.target network.target

[Service]
Type=forking

Environment=JAVA_HOME=/usr/lib/jvm/java-1.8.0-openjdk
Environment=CATALINA_PID=/opt/tomcat/temp/tomcat.pid
Environment=CATALINA_HOME=/opt/tomcat
Environment=CATALINA_BASE=/opt/tomcat
Environment='CATALINA_OPTS=-Xms512M -Xmx1024M -server -XX:+UseParallelGC'
Environment='JAVA_OPTS=-Djava.awt.headless=true -Djava.security.egd=file:/dev/./urandom'

ExecStart=/opt/tomcat/bin/startup.sh
ExecStop=/bin/kill -15 $MAINPID

User=tomcat
Group=tomcat

[Install]
WantedBy=multi-user.target
EOL

# reload systemd config
systemctl daemon-reload

# start tomcat, mariadb
systemctl enable tomcat --now
systemctl enable mariadb.service --now

# automate the install with root and no pass.
SECURE_MYSQL=$(expect -c "
set timeout 10
spawn mysql_secure_installation
expect \"Enter current password for root (enter for none):\"
send \"\r\"
expect \"Set root password?\"
send \"n\r\"
expect \"Remove anonymous users?\"
send \"y\r\"
expect \"Disallow root login remotely?\"
send \"y\r\"
expect \"Remove test database and access to it?\"
send \"y\r\"
expect \"Reload privilege tables now?\"
send \"y\r\"
expect eof
")

# create the database as the root user we've just made
mysql -u root -e "create database streama;"

# Create upload directory:
chown -R tomcat:root /data/streama

# compile streama.war and groovy config file thing:
git clone https://github.com/dularion/streama.git ~/streama && cd ~/streama

# replace the groovy mysql conf with root
sed -i.bak 's/username = "sa"/username = "root"' grails-app/conf/DataSource.groovy
./grailsw war streama.war -Dgrails.env=production
systemctl stop tomcat && rm -rf /opt/tomcat/webapps/stream.war
cp streama.war -t /opt/tomcat/webapps

# restart tomcat
systemctl start tomcat
