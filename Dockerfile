# Use the official Tomcat base image
FROM tomcat:9-jdk11-openjdk-slim

# Clear the default web applications installed on Tomcat
RUN rm -rf /usr/local/tomcat/webapps/*

# Copy the WAR file into the Tomcat webapps directory
COPY target/online*.war /usr/local/tomcat/webapps/

# Expose port 8080 for web access
EXPOSE 8080

# Start Tomcat server
CMD ["catalina.sh", "run"]
