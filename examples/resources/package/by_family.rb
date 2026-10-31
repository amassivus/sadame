# Package names are the distribution's own; pick one with plain Ruby.
web_server = platform.family == "debian" ? "apache2" : "httpd"
package web_server
