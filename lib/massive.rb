require_relative "massive/relational_query"
require_relative "massive/document_query"
require_relative "massive/runner"


module Massive
  
  
  def self.connect(url, pool_size: 10, timeout: 5, queries: nil)
    #raise "Expecting a map here" if queries &! queries.kind_of?(Hash)
    runner = Massive::Runner.new(url, pool_size, timeout)
    RelationalConnection.new(runner, queries)
  end
  
  def self.connect_as_docs(url, pool_size: 10, timeout: 5, searchable_fields: ['name','email','first','first_name','last','last_name','description','title','city','state','address','street', 'company'])
    runner = Massive::Runner.new(url, pool_size, timeout)
    DocumentConnection.new(runner, searchable_fields)
  end

  class DocumentConnection
    def initialize(runner, searchable_fields)
      @searchable_fields = searchable_fields
      @runner = runner
    end
    def method_missing(table_name)
      Massive::DocumentQuery.new(table_name, @runner, @searchable_fields)
    end    
    def run(sql, params=[])
      @runner.run(sql, params)
    end
  end

  class RelationalConnection
    attr_accessor :prepared
    def initialize(runner, queries)
      @runner = runner
      @prepared = []

      if(queries) then
        queries.each do |n,sql| 
          @runner.prepare(n, sql)
          @prepared << n
        end
      end
    end
    def method_missing(name, *args)
      if(@prepared.include?(name)) then
        @runner.exec_prepared(name, args)
      else
        Massive::RelationalQuery.new(name, @runner)
      end
    end
    def single(sql, params=[])
      @runner.single(sql,params)
    end
    def run(sql, params=[])
      @runner.run(sql, params)
    end
  end
end

