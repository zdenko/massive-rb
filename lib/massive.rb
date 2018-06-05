require_relative "massive/relational_query"
require_relative "massive/document_query"
require_relative "massive/runner"


module Massive
  
  
  def self.connect(url, pool_size: 10, timeout: 5)
    runner = Massive::Runner.new(url, pool_size, timeout)
    RelationalConnection.new(runner)
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
    def initialize(runner)
      @runner = runner
    end
    def method_missing(table_name)
      Massive::RelationalQuery.new(table_name, @runner)
    end
    def single(sql, params=[])
      @runner.single(sql,params)
    end
    def run(sql, params=[])
      @runner.run(sql, params)
    end
  end
end

