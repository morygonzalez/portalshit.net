#!/usr/bin/env ruby
#-*- coding: utf-8 -*-

require File.dirname(__FILE__) + "/log_loader"

es = EntryInsertion.new
es.insert_entries
