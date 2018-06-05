module Massive

  class RelationalQuery

    def initialize(table_name, runner)
      @runner = runner
      @table = table_name
      @prepared = []
    end

    def insert(criteria)
      raise "Expecting a map here" unless criteria.kind_of?(Hash)
      vals = [], arg_list = [], col_list = []
      criteria.keys.each_with_index.map do |x,i| 
        arg_list << "$#{i+1}"
        col_list << x
      end
      sql = "insert into #{@table}(#{col_list.join(',')}) values (#{arg_list.join(',')}) returning *;"
      first(sql,criteria.values)
    end

    def update(id, criteria)
      raise "Expecting a map here" unless criteria.kind_of?(Hash)
      arg_list = []
      criteria.keys.each_with_index do |x,i| 
        arg_list << "#{x} = $#{i+1}"
      end
      sql = "update #{@table} set #{arg_list.join(',')} returning *;"
      first(sql,criteria.values)
    end

    def delete(id)
      sql = "delete from #{@table} where id=$1"
      first(sql, [id])
    end
    
    def delete_where(statement, args)
      sql = "delete from #{@table} where #{statement}"
      params = args.kind_of?(Array) ? args : [args]
      first(sql, params)
    end
    def all
      sql = "select * from #{@table} limit 500"
      execute(sql,[])
    end
    def find(id)
      sql = "select * from #{@table} where id=$1"
      first(sql, [id])
    end

    def filter(criteria)
      raise "Expecting a map here" unless criteria.kind_of?(Hash)
      placeholders = criteria.keys.each_with_index.map {|x,i| ["#{x}=$#{i+1}"]}
      sql = "select * from #{@table} where #{placeholders.join(' and ')}"
      execute(sql, criteria.values)
    end

    def where(criteria, args)
      sql = "select * from #{@table} where #{criteria}"
      params = args.kind_of?(Array) ? args : [args]
      execute(sql, params)
    end

    def count 
      sql = "select count(1) as count from #{@table}"
      first(sql, [])
    end
    
    def count_where(statement, args)
      sql = "select count(1) from #{@table} where #{statement}"
      params = args.kind_of?(Array) ? args : [args]
      first(sql, params)
    end

    #execution
    def execute(sql, params)
      @runner.run(sql, params)
    end

    def first(sql, params)
      res = execute(sql,params)
      if(res == []) then
        nil
      else
        res.kind_of?(Array) ? res.fetch(0) : res
      end
    end



  end

end