require File.dirname(__FILE__) + '/spec_helper'

describe "dm-datastore-adapter" do
  class ::Person
    include DataMapper::Resource
    def self.default_repository_name; :datastore end
    property :id, Serial
    property :name, String
    property :age, Integer
    property :weight, Float
    property :created_at, DateTime
    property :created_on, Date
    belongs_to :company
  end

  class ::Company
    include DataMapper::Resource
    def self.default_repository_name; :datastore end
    property :id, Serial
    property :name, String
    has n, :users
  end

  before do
    @person = Person.new(:name => 'Jon', :age => 40, :weight => 100)
  end

  it "should build person" do
    @person.should_not be_nil
  end

  it "should save person successfully" do
    pending "Needing mocks"
    @person.save.should be_true
  end
end
