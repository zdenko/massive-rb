require 'json'
require 'ostruct'


module Massive
  class DocumentQuery
    def initialize(table_name, runner)
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
      all(sql, [term])
    end

    def find(field, val)
      sql = "select id, body from #{@table} where body -> '#{field.to_s}' ? $1"
      first(sql, [val] )
    end

    def find_by_id(id)
      sql = "select id, body from #{@table} where id=$1"
      first(sql, [id] )
    end
    
    def contains(criteria)
      raise "Expecting a hash" unless criteria.kind_of?(Hash)
      json = criteria.to_json
      sql = "select id, body from #{@table} where body @> $1"
      all(sql, [json] )
    end

    def where(statement, params)
      sql = "select id, body from #{@table} where #{statement}"
      params = params.kind_of?(Array) ? params : [params]
      all(sql, params)
    end

    #execution
    def save(doc)
      raise "Expecting a hash" unless doc.kind_of?(Hash) || doc.kind_of?(OpenStruct)
      json = doc.kind_of?(OpenStruct) ? doc.to_h.to_json : doc.to_json

      if(doc[:id])
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


    def all(sql, params)
      begin
        results = @runner.run(sql, params)
        set_id(results)
      rescue PG::UndefinedTable
        create_document_table
        all(sql, params)
      end
    end

    def first(sql, params)
      begin
        res = all(sql,params)
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

    def get_searchable_values(doc)

      #to do: open this up in a config
      searchables = ['name','email','first','first_name','last','last_name','description','title','city','state','address','street', 'company']
      doc.select {|k,v| searchables.include?(k.to_s)}.values.join(" ")
    end

    private 

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