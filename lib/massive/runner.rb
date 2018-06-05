require "pg"
require_relative "connection_pool"
require "ostruct"

module Massive
  class Runner
    def initialize(url, pool_size, timeout)
      @pool = ConnectionPool.new(size: pool_size, timeout: timeout) do
        conn = PG::Connection.new(url)
        #nice types in results please
        conn.type_map_for_results = PG::BasicTypeMapForResults.new conn
        conn
      end
    end

    def run(sql, params)
      @pool.with do |conn|
        conn.exec_params(sql, params).to_a.map do |row|
          OpenStruct.new(row)
        end
      end
    end

    def single(sql, params)
      result = run(sql,params)
      result.empty? ? nil : result.fetch(0)
    end

    def prepare(name, sql)
      @pool.with do |conn|
        conn.prepare(name.to_s, sql)
      end
    end

    def exec_prepared(name, params)
      args = params.is_a?(Array) ? params : [params]
      @pool.with do |conn|
        conn.exec_prepared(name.to_s, args).to_a.map do |row|
          OpenStruct.new(row)
        end
      end
    end
  end
end