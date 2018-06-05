require 'json'
require 'ostruct'

module Massive
  class DocumentQuery
    
    def initialize(table_name, runner, searchable_fields)
      @searchable_fields = searchable_fields
      @runner = runner
      @table = table_name
    end

    def create_document_table
      sql = %{
        create table #{@table}(
          id serial primary key not null,
          body jsonb not null,
          search tsvector,
          created_at timestamptz not null default now(),
          updated_at timestamptz
        );
      }
      @runner.run(sql,[])
      @runner.run("create index idx_#{@table}_docs on #{@table} using GIN(body jsonb_path_ops);", [])
      @runner.run("create index idx_search_#{@table}_docs on #{@table} using GIN(search);", [])
    end

    def delete(id)
      sql = "delete from #{@table} where id=$1"
      first(sql, [id] )
    end

    def delete_if(criteria)
      raise "Expecting a hash" unless criteria.kind_of?(Hash)
      json = criteria.to_json
      sql = "delete from #{@table} where body @> $1"
      first(sql, [json] )
    end

    def search(term)
      sql = "select id, body from #{@table} where to_tsquery($1) @@ search"
      execute(sql, [term])
    end
    def all
      sql = "select id, body from #{@table} order by id;"
      execute(sql, [] )
    end
    def filter(field, val)
      sql = "select id, body from #{@table} where body -> '#{field.to_s}' ? $1"
      first(sql, [val] )
    end

    def find(id)
      sql = "select id, body from #{@table} where id=$1"
      first(sql, [id] )
    end
    
    def contains(criteria)
      raise "Expecting a hash" unless criteria.kind_of?(Hash)
      json = criteria.to_json
      sql = "select id, body from #{@table} where body @> $1"
      execute(sql, [json] )
    end

    def where(statement, params)
      sql = "select id, body from #{@table} where #{statement}"
      params = params.kind_of?(Array) ? params : [params]
      execute(sql, params)
    end

    #execution
    def save(doc)
      #removing this check for now so classes, arrays, etc can be serialized
      raise "Expecting a Hash or OpenStruct. This method currently doesn't serialize class instances because I don't know how to do that reliably." unless doc.kind_of?(Hash) || doc.kind_of?(OpenStruct)
      json = doc.kind_of?(OpenStruct) ? doc.to_h.to_json : doc.to_json
      if(doc[:id]) #lame but... whatever
        sql = "update #{@table} set body = $1, search=to_tsvector($2), updated_at = now() where id=$3;" 
        first(sql, [json, get_searchable_values(doc.to_h), doc.id])
      else
        sql = "insert into #{@table}(body, search) values($1, $2) returning id;"
        new_record = first(sql, [json, get_searchable_values(doc)])
        doc[:id] = new_record.id
        #have to convert this...
        OpenStruct.new(doc)
      end
    end


    def execute(sql, params)
      begin
        results = @runner.run(sql, params)
        set_id(results)
      rescue PG::UndefinedTable
        create_document_table
        execute(sql, params)
      end
    end

    def first(sql, params)
      begin
        res = execute(sql,params)
        if(res == []) then
          nil
        else
          res.kind_of?(Array) ? res.fetch(0) : res
        end
      rescue PG::UndefinedTable
        create_document_table
        first(sql, params)
      end
    end

    private 
    def get_searchable_values(doc)
      doc.select {|k,v| @searchable_fields.include?(k.to_s)}.values.join(" ")
    end
    def instance_to_hash(doc)
      hash = {}
      doc.instance_variables.each {|var| hash[var.to_s.delete("@")] = instance_variable_get(var) }
      hash
    end
    def set_id(results)
      results.map do |res|
        if(res[:body]) then
          doc = OpenStruct.new(res.body)
          if(res.id) then
            doc.id = res.id
          end
          doc
        else
          res
        end
      end
    end
  end
end