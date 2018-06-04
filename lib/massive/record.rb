class Record
  def initialize(row)
    @row = row
  end
  def method_missing(col_name)
    @row.fetch(col_name.to_s)
  end
end