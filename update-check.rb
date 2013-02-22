#!/usr/bin/env ruby

require 'rubygems'
require 'nokogiri'
require 'json'
require 'open-uri'

current = Gem::Version.new(JSON.parse(open('https://raw.github.com/segmentio/analytics.js/master/package.json').read)["version"])

maven = Gem::Version.new(Nokogiri::XML(File.open(File.expand_path('../pom.xml', __FILE__))).remove_namespaces!.xpath("/project/version").first.content().sub /-SNAPSHOT/,"")

puts "["+File.dirname(__FILE__)+"]   Next redist: " + maven.to_s
puts "["+File.dirname(__FILE__)+"] Last upstream: " + current.to_s

if current >= maven
	puts "["+File.dirname(__FILE__)+"] A release can be made!!!"
	exit 1 
end
puts "["+File.dirname(__FILE__)+"] Everything up to date."