$:.push File.join(File.dirname(__FILE__), '..', 'lib')

require 'rubygems'
require 'dm-core'
require 'dm-aggregates'
require 'dm-types'
require 'dm-datastore-adapter/datastore-adapter'

DataMapper.setup(:datastore,
  :adapter => :datastore,
  :database => 'sample')
